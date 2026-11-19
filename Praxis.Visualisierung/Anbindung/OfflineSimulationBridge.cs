using Godot;
using Praxis.Visualisierung.Anbindung;
using simSharpSimulation;
using GArray = Godot.Collections.Array<Godot.Collections.Dictionary>;
using GDictionary = Godot.Collections.Dictionary;

// Führt die Originalsimulation im Godot-Prozess aus. Keine Netzwerk- oder Dateischnittstelle.
public partial class OfflineSimulationBridge : Node
{
    [Signal] public delegate void ZustandGeaendertEventHandler(GDictionary zustand);
    [Signal] public delegate void EreignisAufgetretenEventHandler(GDictionary ereignis);

    private const double MinutenProSekunde = 8.0;
    private readonly GArray ereignisse = new();
    private readonly OfflineSimulationsuhr uhr = new(MinutenProSekunde);
    private SimulationLiveEvent[] plan = [];
    private OriginalLauf? modell;
    private double dauer = 480;
    private double oeffnungsdauer = 480;
    private int lauf;
    private bool abgeschlossen;
    private string status = "Offline: nicht geladen";

    public string Laden()
    {
        try
        {
            OriginalSimulation.KonfigurationLaden();
            oeffnungsdauer = OriginalSimulation.Oeffnungsdauer;
            var vorschauEreignisse = new List<SimulationLiveEvent>();
            var vorschau = OriginalSimulation.Vorbereiten(vorschauEreignisse.Add);
            vorschau.Umgebung.Run(vorschau.MaximaleDauer);
            plan = vorschauEreignisse.ToArray();
            NeuesModell();
            return "";
        }
        catch (Exception ex)
        {
            GD.PushError(ex.ToString());
            return ex.Message;
        }
    }

    private void NeuesModell()
    {
        modell = OriginalSimulation.Vorbereiten(EreignisEmpfangen);
        dauer = modell.MaximaleDauer.TotalMinutes;
        ereignisse.Clear();
        uhr.Zuruecksetzen();
        abgeschlossen = false;
        lauf++;
        status = "Offline: SimSharp bereit";
    }

    private void EreignisEmpfangen(SimulationLiveEvent ev)
    {
        int index = ereignisse.Count;
        if (index >= plan.Length || plan[index] != ev)
            throw new InvalidOperationException($"SimSharp-Lauf weicht bei Ereignis {index + 1} vom Vorlauf ab.");
        var daten = new GDictionary
        {
            ["zeit"] = ev.Zeit,
            ["eventTyp"] = ev.EventTyp,
            ["vonZustand"] = ev.VonZustand,
            ["zuZustand"] = ev.ZuZustand,
            ["patientId"] = ev.PatientId,
            ["arztId"] = ev.ArztId ?? 0,
            ["schwesterId"] = ev.SchwesterId ?? 0,
            ["bewegungsdauerMinuten"] = Bewegungsdauer(index, ev)
        };
        ereignisse.Add(daten);
        EmitSignal(SignalName.EreignisAufgetreten, daten);
    }

    private double Bewegungsdauer(int index, SimulationLiveEvent ev)
    {
        string? ankunft = ev.EventTyp switch
        {
            "geht_zur_rezeption" or "geht_nach_arzt_zur_rezeption" => "betritt_rezeption_warteschlange",
            "geht_ins_wartezimmer_schwester" => "betritt_wartezimmer_schwester",
            "geht_zur_schwester" => "betritt_schwesterzimmer",
            "geht_ins_wartezimmer_fuer_arzt" => "betritt_wartezimmer_fuer_arzt",
            "geht_zum_arzt" => "betritt_arztzimmer",
            "geht_zum_ausgang" or "verlaesst_nach_arzt_ohne_rezeption" => "verlaesst_klinik",
            _ => null
        };
        if (ankunft is null) return 0;
        for (int i = index + 1; i < plan.Length; i++)
        {
            var naechstes = plan[i];
            if (naechstes.PatientId != ev.PatientId) continue;
            if (naechstes.EventTyp == ankunft)
                return Math.Max(0, naechstes.Zeit - ev.Zeit);
            if (naechstes.EventTyp.StartsWith("geht_") || naechstes.EventTyp.StartsWith("verlaesst_"))
                break;
        }
        return 0;
    }

    public void Initialisieren() => ZustandMelden();

    public void Starten()
    {
        if (modell is null) return;
        if (abgeschlossen) NeuesModell();
        uhr.Starten();
        status = "Offline: SimSharp läuft";
        ZustandMelden();
    }

    public void Pausieren()
    {
        uhr.Pausieren();
        status = "Offline: pausiert";
        ZustandMelden();
    }

    public void Zuruecksetzen()
    {
        if (modell is null) return;
        NeuesModell();
        ZustandMelden();
    }

    public void GeschwindigkeitSetzen(double faktor)
    {
        uhr.GeschwindigkeitSetzen(faktor);
        ZustandMelden();
    }

    public void Fortschalten(double delta)
    {
        if (!uhr.Laeuft || modell is null) return;
        try
        {
            // Erst die zentrale Uhr fortschalten, dann SimSharp exakt bis zu diesem Zeitpunkt
            // abarbeiten. BisMinute verarbeitet dabei jedes fällige Ereignis in Reihenfolge.
            double ziel = uhr.Fortschalten(delta, dauer);
            modell.BisMinute(ziel);
            if (uhr.Minute >= dauer)
            {
                if (ereignisse.Count != plan.Length)
                    throw new InvalidOperationException("SimSharp-Ereignisse fehlen am Tagesende.");
                abgeschlossen = true;
                uhr.Pausieren();
                status = "Offline: Simulation abgeschlossen";
            }
            ZustandMelden();
        }
        catch (Exception ex)
        {
            uhr.Pausieren();
            status = "Offline-Fehler: " + ex.Message;
            GD.PushError(ex.ToString());
            ZustandMelden();
        }
    }

    public GDictionary ZustandLesen() => new()
    {
        ["zeit"] = uhr.Minute, ["geschwindigkeit"] = uhr.Geschwindigkeit, ["laeuft"] = uhr.Laeuft,
        ["abgeschlossen"] = abgeschlossen, ["ereigniszahl"] = ereignisse.Count,
        ["lauf"] = lauf, ["dauer"] = dauer, ["oeffnungsdauer"] = oeffnungsdauer,
        ["verbunden"] = modell is not null, ["status"] = status,
        ["minutenProSekunde"] = MinutenProSekunde
    };

    public GArray DarstellungsplanLesen() => ereignisse;
    private void ZustandMelden() => EmitSignal(SignalName.ZustandGeaendert, ZustandLesen());
}

/// <summary>
/// Einzige Zeitquelle des Offline-Modus. Sie enthält keine fachliche Simulation,
/// sondern übersetzt ausschließlich Godot-Framezeit in monotone Simulationsminuten.
/// </summary>
internal sealed class OfflineSimulationsuhr(double minutenProSekunde)
{
    public double Minute { get; private set; }
    public double Geschwindigkeit { get; private set; } = 1;
    public bool Laeuft { get; private set; }

    public void Starten() => Laeuft = true;
    public void Pausieren() => Laeuft = false;
    public void Zuruecksetzen()
    {
        Minute = 0;
        Laeuft = false;
    }

    public void GeschwindigkeitSetzen(double faktor)
    {
        if (!double.IsFinite(faktor) || faktor is < 0.5 or > 5)
            throw new ArgumentOutOfRangeException(nameof(faktor));
        Geschwindigkeit = faktor;
    }

    public double Fortschalten(double realeSekunden, double endeMinute)
    {
        if (!double.IsFinite(realeSekunden) || realeSekunden < 0)
            throw new ArgumentOutOfRangeException(nameof(realeSekunden));
        if (!Laeuft) return Minute;
        Minute = Math.Min(endeMinute, Minute + realeSekunden * minutenProSekunde * Geschwindigkeit);
        return Minute;
    }
}
