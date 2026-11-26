using System.Reflection;
using System.Runtime.ExceptionServices;
using SimSharp;
using simSharpSimulation;

namespace Praxis.Visualisierung.Anbindung;

/// <summary>
/// Einziger Zugriff auf die internen Einstiegspunkte des unveränderten Kerns.
/// Keine Kopie von Patientenablauf, Ressourcenplanung oder Verteilungen.
/// Reflection ist nötig, weil PatientenProzess und KonfigurationJsonExport internal sind.
/// </summary>
public static class OriginalSimulation
{
    private static readonly Assembly Core = typeof(SimulationsDaten).Assembly;
    private static Type Typ(string name) => Core.GetType("simSharpSimulation." + name, throwOnError: true)!;

    // LadeAlle liest die Simulations-JSONs, unter anderem patienten-konfiguration.json
    // fuer Ankunftsabstaende und rezeption-konfiguration.json fuer die Rezeptionskapazitaet.
    // Die Godot-Dateien unter Konfiguration/ werden separat durch KonfigurationLader.gd gelesen.
    public static void KonfigurationLaden() => Aufrufen(
        Typ("KonfigurationJsonExport").GetMethod("LadeAlle", BindingFlags.Public | BindingFlags.Static)
        ?? throw new MissingMethodException("Der Originalkern enthält LadeAlle nicht."), null, null);

    public static void LayoutKonfigurationAnwenden(int aerzte, int schwestern, int rezeptionen,
        double arztFlaeche, double schwesterFlaeche, double wartezimmerFlaeche)
    {
        // personal-roll verwaltet Personen getrennt vom Grundriss. Der Baumodus setzt
        // deshalb nur Raumkapazitaeten und Flaechen, nie die Personalzahlen.
        _ = rezeptionen; // Im Kern existiert derzeit keine getrennte Rezeptionsraum-Ressource.
        object finanzen = Typ("KonfigurationJsonExport").GetProperty("Finanzen", BindingFlags.Public | BindingFlags.Static)!.GetValue(null)!;
        object fixkosten = finanzen.GetType().GetProperty("Fixkosten")!.GetValue(finanzen)!;
        void Setzen(string name, object wert) => fixkosten.GetType().GetProperty(name)!.SetValue(fixkosten, wert);
        Setzen("AnzahlBehandlungsraeumeArzt", Math.Max(1, aerzte));
        Setzen("AnzahlBehandlungsraeumeSchwester", Math.Max(1, schwestern));
        Setzen("FlaecheBehandlungsraumArztQuadratmeter", Math.Max(1.0, arztFlaeche / Math.Max(1, aerzte)));
        Setzen("FlaecheBehandlungsraumSchwesterQuadratmeter", Math.Max(1.0, schwesterFlaeche / Math.Max(1, schwestern)));
        Setzen("FlaecheWartezimmerQuadratmeter", Math.Max(1.0, wartezimmerFlaeche));
    }

    public static int Seed => (int)Wert("RANDOM_SEED");
    public static double Oeffnungsdauer => (double)Wert("SIMULATIONSDAUER");

    // Momentaufnahme der bereits vom Kern geladenen Werte. Keine zweite JSON-Auswertung in Godot.
    // Dies sind getrennte Personen je Rolle; gemeinsame Qualifikationen folgen in Schritt 2.
    public static IReadOnlyDictionary<string, int> PersonalzahlenLesen() => new Dictionary<string, int>
    {
        ["Rezeption"] = RezeptionKonfiguration.ANZAHL_REZEPTIONISTEN,
        ["Schwester"] = SchwesterKonfiguration.ANZAHL_SCHWESTERN,
        ["Arzt"] = ArztKonfiguration.ANZAHL_AERZTE
    };

    // Wie im WPF-Fenster: Werte nur im laufenden Prozess setzen, keine Quelldateien schreiben.
    // Vorher alles pruefen, damit ein Fehler keine teilweise geaenderte Konfiguration hinterlaesst.
    public static void PersonalzahlenSetzen(IReadOnlyDictionary<string, int> zahlen)
    {
        string[] rollen = ["Rezeption", "Schwester", "Arzt"];
        if (zahlen.Count != rollen.Length || rollen.Any(rolle => !zahlen.TryGetValue(rolle, out int anzahl) || anzahl < 1))
            throw new ArgumentException("Bitte fuer Rezeption, Schwester und Arzt jeweils mindestens eine Person angeben.");
        RezeptionKonfiguration.ANZAHL_REZEPTIONISTEN = zahlen["Rezeption"];
        SchwesterKonfiguration.ANZAHL_SCHWESTERN = zahlen["Schwester"];
        ArztKonfiguration.ANZAHL_AERZTE = zahlen["Arzt"];
    }

    private static object Wert(string name) => Typ("SimulationKonfiguration")
        .GetProperty(name, BindingFlags.Public | BindingFlags.Static)?.GetValue(null)
        ?? throw new MissingMemberException("Originalkonfiguration: " + name);

    public static SimulationsDaten VollstaendigAusfuehren(Action<SimulationLiveEvent>? veroeffentlichen = null)
    {
        var daten = new SimulationsDaten();
        if (veroeffentlichen is not null) daten.LiveEventOccurred += veroeffentlichen;
        object prozess = Prozess(daten);
        Aufrufen(prozess.GetType().GetMethod("FuehreAus", new[] { typeof(int) })
            ?? throw new MissingMethodException("Originalkern: FuehreAus(int)"), prozess, new object[] { 1 });
        return daten;
    }

    public static OriginalLauf Vorbereiten(Action<SimulationLiveEvent> veroeffentlichen)
    {
        var daten = new SimulationsDaten();
        // LogEvent im Kern veroeffentlicht LiveEventOccurred, z.B. "betritt_klinik".
        // Im Offline-Lauf empfaengt OfflineSimulationBridge.EreignisEmpfangen diese Meldungen.
        daten.LiveEventOccurred += veroeffentlichen;
        object prozess = Prozess(daten);
        OriginalLauf? lauf = null;
        // Der Originalkern richtet selbst Generator, Prozesse, Räume und Personal ein.
        // Nur das Fortschalten seiner SimSharp-Uhr übernimmt die Darstellung.
        Func<Simulation, TimeSpan, Task> initialisieren = (env, dauer) =>
        {
            lauf = new OriginalLauf(env, dauer, daten);
            return Task.CompletedTask;
        };
        var methode = prozess.GetType().GetMethod("FuehreAusAsync", BindingFlags.NonPublic | BindingFlags.Instance)
            ?? throw new MissingMethodException("Originalkern: FuehreAusAsync");
        ((Task)Aufrufen(methode, prozess, new object[] { 1, initialisieren })!).GetAwaiter().GetResult();
        return lauf ?? throw new InvalidOperationException("Der Originalkern hat keine SimSharp-Umgebung bereitgestellt.");
    }

    private static object Prozess(SimulationsDaten daten) =>
        Activator.CreateInstance(Typ("PatientenProzess"), Seed, daten)
        ?? throw new InvalidOperationException("Der Originalprozess konnte nicht erzeugt werden.");

    private static object? Aufrufen(MethodInfo methode, object? ziel, object[]? argumente)
    {
        try { return methode.Invoke(ziel, argumente); }
        catch (TargetInvocationException ex) when (ex.InnerException is not null)
        {
            ExceptionDispatchInfo.Capture(ex.InnerException).Throw();
            throw;
        }
    }
}

public sealed class OriginalLauf(Simulation umgebung, TimeSpan dauer, SimulationsDaten daten)
{
    public Simulation Umgebung { get; } = umgebung;
    public TimeSpan MaximaleDauer { get; } = dauer;
    public SimulationsDaten Daten { get; } = daten;

    public void BisMinute(double minute)
    {
        var ziel = Umgebung.StartDate + TimeSpan.FromMinutes(minute);
        var ende = Umgebung.StartDate + MaximaleDauer;
        // Exakt die Originalereignisse; am Tageslimit dieselbe exklusive Grenze wie Run(dauer).
        while (Umgebung.Peek() <= ziel && Umgebung.Peek() < ende) Umgebung.Step();
    }
}
