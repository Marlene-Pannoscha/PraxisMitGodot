using simSharpSimulation;

namespace Praxis.Visualisierung.Anbindung;

/// <summary>Steuert ausschließlich die Uhr des unveränderten Modells und prüft den Darstellungsplan.</summary>
public sealed class VisualisierungsController
{
    public const double MinutenProSekunde = 8.0;
    private readonly SimulationLiveEvent[] plan;
    private OriginalLauf modell = null!;
    private int ereigniszahl;
    private int lauf = 1;
    private double zeit;
    private double geschwindigkeit = 1;
    private bool laeuft;
    private bool abgeschlossen;

    public IReadOnlyList<SimulationLiveEvent> Ablaufplan { get; }
    public double Oeffnungsdauer { get; }
    public double Dauer { get; }
    public VisualisierungsStatus Status => new(zeit, geschwindigkeit, laeuft, abgeschlossen, ereigniszahl, lauf, Dauer);
    public event Action<SimulationLiveEvent>? EreignisAufgetreten;
    public event Action<VisualisierungsStatus>? ZustandGeaendert;

    public VisualisierungsController()
    {
        OriginalSimulation.KonfigurationLaden();
        Oeffnungsdauer = OriginalSimulation.Oeffnungsdauer;
        var vorlauf = new List<SimulationLiveEvent>();
        var vorschau = OriginalSimulation.Vorbereiten(vorlauf.Add);
        vorschau.Umgebung.Run(vorschau.MaximaleDauer);
        plan = vorlauf.ToArray(); // Ungekürzte Zeitstempel und Originalreihenfolge.
        Ablaufplan = Array.AsReadOnly(plan);
        Dauer = vorschau.MaximaleDauer.TotalMinutes;
        NeuesModell();
    }

    private void NeuesModell()
    {
        modell = OriginalSimulation.Vorbereiten(ev =>
        {
            if (ereigniszahl >= plan.Length || plan[ereigniszahl] != ev)
                throw new InvalidOperationException($"Originalsimulation weicht bei Ereignis {ereigniszahl + 1} vom Vorlauf ab.");
            ereigniszahl++;
            EreignisAufgetreten?.Invoke(ev);
        });
    }

    public void Starten()
    {
        if (abgeschlossen) Zuruecksetzen();
        laeuft = true;
        Melden();
    }
    public void Pausieren() { laeuft = false; Melden(); }
    public void Zuruecksetzen()
    {
        laeuft = abgeschlossen = false;
        zeit = 0;
        ereigniszahl = 0;
        lauf++;
        NeuesModell();
        Melden();
    }
    public void GeschwindigkeitSetzen(double faktor)
    {
        if (!double.IsFinite(faktor) || faktor is < 0.25 or > 5)
            throw new ArgumentOutOfRangeException(nameof(faktor));
        geschwindigkeit = faktor;
        Melden();
    }
    public void Fortschalten(double sekunden)
    {
        if (!double.IsFinite(sekunden) || sekunden < 0)
            throw new ArgumentOutOfRangeException(nameof(sekunden));
        if (!laeuft) return;
        double ziel = Math.Min(Dauer, zeit + sekunden * MinutenProSekunde * geschwindigkeit);
        modell.BisMinute(ziel);
        zeit = ziel;
        if (zeit >= Dauer)
        {
            if (ereigniszahl != plan.Length) throw new InvalidOperationException("Ereignisse des Originalmodells fehlen.");
            abgeschlossen = true;
            laeuft = false;
        }
        Melden();
    }
    private void Melden() => ZustandGeaendert?.Invoke(Status);
}

public sealed record VisualisierungsStatus(double Zeit, double Geschwindigkeit, bool Laeuft,
    bool Abgeschlossen, int Ereigniszahl, int Lauf, double Dauer);
