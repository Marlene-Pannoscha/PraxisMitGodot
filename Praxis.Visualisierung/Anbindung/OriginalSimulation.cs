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

    public static void KonfigurationLaden() => Aufrufen(
        Typ("KonfigurationJsonExport").GetMethod("LadeAlle", BindingFlags.Public | BindingFlags.Static)
        ?? throw new MissingMethodException("Der Originalkern enthält LadeAlle nicht."), null, null);

    public static int Seed => (int)Wert("RANDOM_SEED");
    public static double Oeffnungsdauer => (double)Wert("SIMULATIONSDAUER");
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
