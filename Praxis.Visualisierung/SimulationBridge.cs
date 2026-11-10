using System.Collections.Concurrent;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using Godot;
using GArray = Godot.Collections.Array<Godot.Collections.Dictionary>;
using GDictionary = Godot.Collections.Dictionary;

// Reiner WebSocket-Client. Simulationslogik und Patientengenerierung laufen nur im Serverprozess.
public partial class SimulationBridge : Node
{
    [Signal] public delegate void ZustandGeaendertEventHandler(GDictionary zustand);
    [Signal] public delegate void EreignisAufgetretenEventHandler(GDictionary ereignis);
    private const double Basisgeschwindigkeit = 60.0;
    private readonly ClientWebSocket socket = new();
    private readonly ConcurrentQueue<string> nachrichten = new();
    private readonly SemaphoreSlim senden = new(1, 1);
    private readonly GArray ereignisse = new();
    private CancellationTokenSource? empfangAbbrechen;
    private bool verbunden;
    private bool laeuft;
    private bool abgeschlossen;
    private double zeit;
    private double geschwindigkeit = 1;
    private int lauf;
    private string status = "Nicht verbunden";

    public string Laden()
    {
        try
        {
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            socket.ConnectAsync(new Uri("ws://localhost:5080/ws/simulation"), timeout.Token).GetAwaiter().GetResult();
            verbunden = true;
            status = "Mit SimSharp-Server verbunden";
            empfangAbbrechen = new CancellationTokenSource();
            _ = Task.Run(() => EmpfangenAsync(empfangAbbrechen.Token));
            return "";
        }
        catch (Exception ex)
        {
            GD.PushError(ex.ToString());
            return "WebSocket ws://localhost:5080/ws/simulation nicht erreichbar: " + ex.Message;
        }
    }

    public override void _Process(double delta)
    {
        while (nachrichten.TryDequeue(out var json)) NachrichtVerarbeiten(json);
    }

    public override void _ExitTree()
    {
        empfangAbbrechen?.Cancel();
        if (socket.State is WebSocketState.Open or WebSocketState.CloseReceived)
        {
            try { socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Godot beendet", CancellationToken.None).Wait(1000); }
            catch { socket.Abort(); }
        }
        socket.Dispose();
        empfangAbbrechen?.Dispose();
        senden.Dispose();
    }

    public void Initialisieren() => ZustandMelden();
    public void Starten()
    {
        if (!verbunden || laeuft) return;
        Senden(new { type = "start", speed = geschwindigkeit * Basisgeschwindigkeit });
    }
    public void Pausieren()
    {
        if (verbunden && laeuft) Senden(new { type = "stop" });
    }
    public void Zuruecksetzen()
    {
        if (laeuft) Senden(new { type = "stop" });
        ereignisse.Clear();
        zeit = 0;
        laeuft = abgeschlossen = false;
        lauf++;
        status = "Bereit für neuen Live-Lauf";
        ZustandMelden();
    }
    public void GeschwindigkeitSetzen(double faktor)
    {
        if (!double.IsFinite(faktor) || faktor is < 0.25 or > 5)
            throw new ArgumentOutOfRangeException(nameof(faktor));
        geschwindigkeit = faktor;
        if (laeuft) Senden(new { type = "setSpeed", speed = faktor * Basisgeschwindigkeit });
        ZustandMelden();
    }
    public void Fortschalten(double delta) { }
    public GDictionary ZustandLesen() => StatusDaten();
    public GArray DarstellungsplanLesen() => ereignisse;

    private async Task EmpfangenAsync(CancellationToken cancellationToken)
    {
        var puffer = new byte[8192];
        try
        {
            while (!cancellationToken.IsCancellationRequested && socket.State == WebSocketState.Open)
            {
                using var text = new MemoryStream();
                WebSocketReceiveResult ergebnis;
                do
                {
                    ergebnis = await socket.ReceiveAsync(puffer, cancellationToken);
                    if (ergebnis.MessageType == WebSocketMessageType.Close) return;
                    text.Write(puffer, 0, ergebnis.Count);
                } while (!ergebnis.EndOfMessage);
                nachrichten.Enqueue(Encoding.UTF8.GetString(text.ToArray()));
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            nachrichten.Enqueue(JsonSerializer.Serialize(new { type = "clientError", message = ex.Message }));
        }
    }

    private void NachrichtVerarbeiten(string json)
    {
        using var dokument = JsonDocument.Parse(json);
        var wurzel = dokument.RootElement;
        var typ = Text(wurzel, "type");
        switch (typ)
        {
            case "ready":
                status = "SimSharp-Server bereit";
                ZustandMelden();
                break;
            case "started":
                ereignisse.Clear();
                zeit = 0;
                laeuft = true;
                abgeschlossen = false;
                lauf++;
                geschwindigkeit = Zahl(wurzel, "speed", Basisgeschwindigkeit) / Basisgeschwindigkeit;
                status = "Live-Simulation läuft";
                ZustandMelden();
                break;
            case "clock":
                zeit = Zahl(wurzel, "elapsedMinutes", zeit);
                geschwindigkeit = Zahl(wurzel, "speed", geschwindigkeit * Basisgeschwindigkeit) / Basisgeschwindigkeit;
                ZustandMelden();
                break;
            case "event":
                if (!wurzel.TryGetProperty("data", out var daten)) break;
                var ereignis = EreignisDaten(daten);
                ereignisse.Add(ereignis);
                EmitSignal(SignalName.EreignisAufgetreten, ereignis);
                ZustandMelden();
                break;
            case "completed":
                laeuft = false;
                abgeschlossen = true;
                status = "Live-Simulation abgeschlossen";
                ZustandMelden();
                break;
            case "stopped":
                laeuft = false;
                status = "Live-Simulation gestoppt";
                ZustandMelden();
                break;
            case "error":
                status = "Serverfehler: " + Text(wurzel, "code");
                GD.PushError(status);
                ZustandMelden();
                break;
            case "clientError":
                verbunden = laeuft = false;
                status = "WebSocket-Verbindung beendet: " + Text(wurzel, "message");
                GD.PushError(status);
                ZustandMelden();
                break;
        }
    }

    private void Senden(object nachricht)
    {
        try { SendenAsync(JsonSerializer.Serialize(nachricht)).GetAwaiter().GetResult(); }
        catch (Exception ex) { GD.PushError("WebSocket-Senden fehlgeschlagen: " + ex.Message); }
    }

    private async Task SendenAsync(string json)
    {
        var bytes = Encoding.UTF8.GetBytes(json);
        await senden.WaitAsync();
        try { await socket.SendAsync(bytes, WebSocketMessageType.Text, true, CancellationToken.None); }
        finally { senden.Release(); }
    }

    private static GDictionary EreignisDaten(JsonElement ev) => new()
    {
        ["zeit"] = Zahl(ev, "zeit"), ["eventTyp"] = Text(ev, "eventTyp"),
        ["vonZustand"] = Text(ev, "vonZustand"), ["zuZustand"] = Text(ev, "zuZustand"),
        ["patientId"] = Ganzzahl(ev, "patientId"), ["arztId"] = Ganzzahl(ev, "arztId"),
        ["schwesterId"] = Ganzzahl(ev, "schwesterId"),
        ["bewegungsdauerMinuten"] = Zahl(ev, "bewegungsdauerMinuten")
    };

    private GDictionary StatusDaten() => new()
    {
        ["zeit"] = zeit, ["geschwindigkeit"] = geschwindigkeit, ["laeuft"] = laeuft,
        ["abgeschlossen"] = abgeschlossen, ["ereigniszahl"] = ereignisse.Count,
        ["lauf"] = lauf, ["dauer"] = 480.0, ["oeffnungsdauer"] = 480.0,
        ["verbunden"] = verbunden, ["status"] = status
    };

    private void ZustandMelden() => EmitSignal(SignalName.ZustandGeaendert, StatusDaten());
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var wert) && wert.ValueKind == JsonValueKind.String ? wert.GetString() ?? "" : "";
    private static double Zahl(JsonElement element, string name, double standard = 0) =>
        element.TryGetProperty(name, out var wert) && wert.TryGetDouble(out var zahl) ? zahl : standard;
    private static int Ganzzahl(JsonElement element, string name) =>
        element.TryGetProperty(name, out var wert) && wert.ValueKind != JsonValueKind.Null && wert.TryGetInt32(out var zahl) ? zahl : 0;
}
