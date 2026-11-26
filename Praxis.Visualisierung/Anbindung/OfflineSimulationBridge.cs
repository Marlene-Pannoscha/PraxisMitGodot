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
    private readonly GDictionary personalzahlen = new();
    private readonly GDictionary standardPersonalzahlen = new();
    private readonly OfflineSimulationsuhr uhr = new(MinutenProSekunde);
    private SimulationLiveEvent[] plan = [];
    private OriginalLauf? modell;
    private double dauer = 480;
    private double oeffnungsdauer = 480;
    private int lauf;
    private bool abgeschlossen;
    private string status = "Offline: nicht geladen";
    private int[]? layoutAnzahlen;
    private double[]? layoutFlaechen;

    public void LayoutKonfigurationSetzen(int aerzte, int schwestern, int rezeptionen,
        double arztFlaeche, double schwesterFlaeche, double wartezimmerFlaeche)
    {
        layoutAnzahlen = [aerzte, schwestern, rezeptionen];
        layoutFlaechen = [arztFlaeche, schwesterFlaeche, wartezimmerFlaeche];
    }

    public string Laden()
    {
        try
        {
            // Simulationswerte beim Laden einlesen. Nach Aenderungen an den Quell-JSONs
            // neu bauen (JSONs werden ins Ausgabeverzeichnis kopiert) und die Anwendung neu starten.
            OriginalSimulation.KonfigurationLaden();
            if (layoutAnzahlen is not null && layoutFlaechen is not null)
                OriginalSimulation.LayoutKonfigurationAnwenden(layoutAnzahlen[0], layoutAnzahlen[1], layoutAnzahlen[2],
                    layoutFlaechen[0], layoutFlaechen[1], layoutFlaechen[2]);
            personalzahlen.Clear();
            standardPersonalzahlen.Clear();
            foreach (var (rolle, anzahl) in OriginalSimulation.PersonalzahlenLesen())
            {
                personalzahlen[rolle] = anzahl;
                standardPersonalzahlen[rolle] = anzahl;
            }
            oeffnungsdauer = OriginalSimulation.Oeffnungsdauer;
            DarstellungsplanVorbereiten();
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
        // Auch Reset verwendet die bereits geladenen Konfigurationswerte; kein erneutes JSON-Laden.
        ModellUebernehmen(OriginalSimulation.Vorbereiten(EreignisEmpfangen));
    }

    private void DarstellungsplanVorbereiten()
    {
        // Erst beide Laeufe erfolgreich vorbereiten, dann den bisherigen Lauf ersetzen.
        var vorschauEreignisse = new List<SimulationLiveEvent>();
        var vorschau = OriginalSimulation.Vorbereiten(vorschauEreignisse.Add);
        vorschau.Umgebung.Run(vorschau.MaximaleDauer);
        var neuesModell = OriginalSimulation.Vorbereiten(EreignisEmpfangen);
        plan = vorschauEreignisse.ToArray();
        ModellUebernehmen(neuesModell);
    }

    private void ModellUebernehmen(OriginalLauf neuesModell)
    {
        modell = neuesModell;
        dauer = modell.MaximaleDauer.TotalMinutes;
        ereignisse.Clear();
        uhr.Zuruecksetzen();
        abgeschlossen = false;
        lauf++;
        status = "Offline: SimSharp bereit";
    }

    private void EreignisEmpfangen(SimulationLiveEvent ev)
    {
        // Der Kern bestimmt Patient-ID, Zeitpunkt und Ereignistyp. Godot erfindet keine Ankuenfte.
        int index = ereignisse.Count;
        if (index >= plan.Length || plan[index] != ev)
            throw new InvalidOperationException($"SimSharp-Lauf weicht bei Ereignis {index + 1} vom Vorlauf ab.");
        var (arztId, schwesterId) = Personalziel(index, ev);
        var daten = new GDictionary
        {
            ["zeit"] = ev.Zeit,
            ["eventTyp"] = ev.EventTyp,
            ["vonZustand"] = ev.VonZustand,
            ["zuZustand"] = ev.ZuZustand,
            ["patientId"] = ev.PatientId,
            ["arztId"] = arztId,
            ["schwesterId"] = schwesterId,
            ["bewegungsdauerMinuten"] = Bewegungsdauer(index, ev)
        };
        ereignisse.Add(daten);
        // Main.gd empfaengt dieses Signal in _simulation_ereignis und aktualisiert die Figuren.
        // Personalzahlen und Raumgrundrisse werden mit diesem Patientensignal nicht uebertragen.
        EmitSignal(SignalName.EreignisAufgetreten, daten);
    }

    private (int ArztId, int SchwesterId) Personalziel(int index, SimulationLiveEvent ev)
    {
        // Der unveraenderte Kern nennt die bereits reservierte Person erst beim
        // Behandlungsbeginn. Der deterministische Vorlauf liefert dieselbe ID schon
        // fuer Hinweg und Ankunft, damit die Figur direkt den richtigen Raum erreicht.
        bool arzt = ev.EventTyp is "geht_zum_arzt" or "betritt_arztzimmer" or "verlaesst_wartezimmer_fuer_arzt";
        bool schwester = ev.EventTyp is "geht_zur_schwester" or "betritt_schwesterzimmer";
        int arztId = ev.ArztId ?? 0;
        int schwesterId = ev.SchwesterId ?? 0;
        if ((!arzt || arztId > 0) && (!schwester || schwesterId > 0))
            return (arztId, schwesterId);
        for (int i = index + 1; i < plan.Length; i++)
        {
            var naechstes = plan[i];
            if (naechstes.PatientId != ev.PatientId) continue;
            if (arzt && naechstes.EventTyp == "startet_arzt_behandlung")
                return (naechstes.ArztId ?? arztId, schwesterId);
            if (schwester && naechstes.EventTyp == "startet_schwester_prozess")
                return (arztId, naechstes.SchwesterId ?? schwesterId);
            // Nur die unmittelbar folgende Behandlung dieses Patienten verwenden.
            if (naechstes.EventTyp.StartsWith("geht_") && !(arzt && naechstes.EventTyp == "geht_zum_arzt")
                || naechstes.EventTyp == "verlaesst_klinik")
                break;
        }
        return (arztId, schwesterId);
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

    // Dieselbe Momentaufnahme fuer Figurenaufbau und Reset; Aufrufer erhalten eine Kopie.
    public GDictionary PersonalzahlenLesen() => personalzahlen.Duplicate();

    public GDictionary PersonalStandardwerteLesen() => standardPersonalzahlen.Duplicate();

    // Der Aufrufer prueft vorher die Godot-Arbeitsplaetze. Diese Methode prueft die Kernwerte
    // erneut und baut einen neuen Vorlauf auf. Sie schreibt keine JSON-Datei.
    public string PersonalzahlenAnwenden(GDictionary eingabe)
    {
        if (modell is null) return "Die Offline-Simulation ist nicht geladen.";
        var zahlen = new Dictionary<string, int>();
        string[] rollen = ["Rezeption", "Schwester", "Arzt"];
        if (eingabe.Count != rollen.Length) return "Bitte genau die drei Personalrollen angeben.";
        foreach (string rolle in rollen)
        {
            if (!eingabe.TryGetValue(rolle, out var wert) || wert.VariantType != Variant.Type.Int
                || wert.AsInt64() < 1 || wert.AsInt64() > int.MaxValue)
                return "Bitte fuer " + rolle + " eine ganze Anzahl von mindestens 1 angeben.";
            zahlen[rolle] = (int)wert.AsInt64();
        }
        var bisher = OriginalSimulation.PersonalzahlenLesen();
        try
        {
            OriginalSimulation.PersonalzahlenSetzen(zahlen);
            DarstellungsplanVorbereiten();
            foreach (var (rolle, anzahl) in zahlen) personalzahlen[rolle] = anzahl;
            return "";
        }
        catch (Exception ex)
        {
            OriginalSimulation.PersonalzahlenSetzen(bisher);
            return "Personal konnte nicht uebernommen werden: " + ex.Message;
        }
    }

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
