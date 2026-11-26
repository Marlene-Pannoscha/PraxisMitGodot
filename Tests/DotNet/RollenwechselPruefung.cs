using SimSharp;
using simSharpSimulation;
using Praxis.Visualisierung.Anbindung;

internal static class RollenwechselPruefung
{
    private static double Dauer
    {
        get => (double)DauerEigenschaft.GetValue(null)!;
        set => DauerEigenschaft.SetValue(null, value);
    }
    private static System.Reflection.PropertyInfo DauerEigenschaft => typeof(SimulationsDaten).Assembly
        .GetType("simSharpSimulation.SimulationKonfiguration", true)!.GetProperty("SIMULATIONSDAUER")!;
    private static void Pruefe(bool bedingung, string text)
    {
        if (!bedingung) throw new InvalidOperationException("ROLLENWECHSEL: " + text);
        Console.WriteLine("OK: " + text);
    }

    private static void Bis(Simulation env, double minute)
    {
        var ziel = env.StartDate.AddMinutes(minute);
        while (env.Peek() <= ziel) env.Step();
    }

    public static void Ausfuehren()
    {
        OriginalSimulation.KonfigurationLaden();
        var vorher = OriginalSimulation.PersonalzahlenLesen();
        var regelnVorher = SchwesterKonfiguration.Rollenwechsel;
        double dauerVorher = Dauer;
        try
        {
            Dauer = 480;
            SchwellenUndWegzeit();
            KeineUnterbrechung();
            Hysterese();
            LeerlaufUndSchichtende();
            Gesamtlauf();
        }
        finally
        {
            OriginalSimulation.PersonalzahlenSetzen(vorher);
            SchwesterKonfiguration.Rollenwechsel = regelnVorher;
            Dauer = dauerVorher;
        }
    }

    private static (Simulation Env, StationsPersonalPool Pool, List<SimulationLiveEvent> Events) Aufbau(int raeume = 1)
    {
        var env = new Simulation(new DateTime(2000, 1, 3));
        var daten = new SimulationsDaten();
        var events = new List<SimulationLiveEvent>();
        daten.LiveEventOccurred += events.Add;
        return (env, new StationsPersonalPool(env, 1, 2, raeume,
            new RollenwechselOptionen { Aktiv = true }, daten), events);
    }

    private static void SchwellenUndWegzeit()
    {
        var (env, pool, events) = Aufbau();
        using var festR = pool.Anfordern("Rezeption", 1);
        using var festS = pool.Anfordern("Schwester", 2);
        Bis(env, .001);
        using var wartendS = pool.Anfordern("Schwester", 3, 3);
        var wartendR = Enumerable.Range(10, 3).Select(id => pool.Anfordern("Rezeption", id)).ToList();
        Bis(env, .002);
        Pruefe(!events.Any(e => e.EventTyp == "personal_wechsel_start"), "Drei Rezeptionswartende bei Schwesterarbeit loesen noch keinen Wechsel aus");
        wartendR.Add(pool.Anfordern("Rezeption", 13));
        Bis(env, .003);
        var start = events.Single(e => e.EventTyp == "personal_wechsel_start");
        Pruefe(start.PersonalId == "schwester_2" && start.ZuRolle == "Rezeption", "Ab vier Wartenden wechselt genau Schwester 2 zur Rezeption");
        Bis(env, .1);
        Pruefe(wartendR.All(a => a.PersonalId is null), "Waehrend der Wegzeit wird keine Aufgabe zugeteilt");
        Bis(env, .3);
        Pruefe(wartendR[0].PersonalId == "schwester_2" && wartendR[0].ArbeitsplatzId == "rezeption_2", "Flexible Schwester nutzt den zweiten Rezeptionsplatz und FIFO");
        var ende = events.Single(e => e.EventTyp == "personal_wechsel_ende");
        Pruefe(Math.Abs(ende.Zeit - start.Zeit - 10.0 / 60) < 1e-8, "Rollenwechsel dauert exakt die konfigurierte Wegzeit");
        var weitereS = Enumerable.Range(20, 3).Select(id => pool.Anfordern("Schwester", id, 1)).ToArray();
        Bis(env, .31);
        Pruefe(events.Count(e => e.EventTyp == "personal_wechsel_start") == 1, "Vier Schwesterwartende unterbrechen keine laufende Rezeptionsaufgabe");
        wartendR[0].Dispose();
        Bis(env, .32);
        Pruefe(events.Last(e => e.EventTyp == "personal_wechsel_start").ZuRolle == "Schwester", "Nach Aufgabenende fuehren vier Schwesterwartende zur Rueckkehr");
        Bis(env, .6);
        Pruefe(wartendS.PersonalId is null && weitereS.All(a => a.PersonalId is null), "Belegter Schwesterraum bleibt bis zur Freigabe exklusiv reserviert");
        festS.Dispose();
        Bis(env, .61);
        Pruefe(weitereS[0].PersonalId is not null && wartendS.PersonalId is null, "Schwesterprioritaet bleibt vor FIFO bei gleicher Prioritaet erhalten");
        foreach (var a in wartendR.Concat(weitereS)) a.Dispose();
    }

    private static void KeineUnterbrechung()
    {
        var (env, pool, events) = Aufbau(2);
        using var festR = pool.Anfordern("Rezeption", 1);
        using var festS = pool.Anfordern("Schwester", 2);
        using var flexibel = pool.Anfordern("Schwester", 3);
        Bis(env, .01);
        Pruefe(flexibel.PersonalId == "schwester_2", "Zweite Schwester ist eine konkrete gemeinsam verwaltete Person");
        using var wartendS = pool.Anfordern("Schwester", 4);
        var r = Enumerable.Range(10, 4).Select(id => pool.Anfordern("Rezeption", id)).ToArray();
        Bis(env, .02);
        Pruefe(!events.Any(e => e.EventTyp == "personal_wechsel_start"), "Laufende Schwesterbehandlung wird nicht fuer die Rezeption unterbrochen");
        flexibel.Dispose();
        Bis(env, .03);
        Pruefe(events.Any(e => e.EventTyp == "personal_wechsel_start"), "Erst nach Freigabe der Schwesteraufgabe beginnt der Wechsel");
        foreach (var a in r) a.Dispose();
    }

    private static void Hysterese()
    {
        var (env, pool, events) = Aufbau();
        using var festR = pool.Anfordern("Rezeption", 1);
        using var festS = pool.Anfordern("Schwester", 2);
        Bis(env, .001);
        using var s = pool.Anfordern("Schwester", 3);
        var r = Enumerable.Range(10, 5).Select(id => pool.Anfordern("Rezeption", id)).ToArray();
        Bis(env, .3);
        r[0].Dispose();
        Bis(env, .31);
        Pruefe(r[1].PersonalId == "schwester_2", "Flexible Schwester bleibt bei mehr als zwei Rezeptionswartenden dort");
        r[1].Dispose();
        Bis(env, .32);
        Pruefe(r[2].PersonalId == "schwester_2", "Kein Pendeln bei drei Rezeptionswartenden");
        r[2].Dispose();
        Bis(env, .33);
        Pruefe(events.Last(e => e.EventTyp == "personal_wechsel_start").ZuRolle == "Schwester", "Bei zwei Rezeptionswartenden und Schwesterbedarf beginnt die Rueckkehr");
        foreach (var a in r) a.Dispose();
    }

    private static void LeerlaufUndSchichtende()
    {
        var (env, pool, events) = Aufbau();
        using var r1 = pool.Anfordern("Rezeption", 1);
        Bis(env, .001);
        using var r2 = pool.Anfordern("Rezeption", 2);
        Bis(env, .3);
        Pruefe(r2.PersonalId == "schwester_2", "Ohne Schwesterwartende hilft die flexible Person auch unterhalb der Schwelle");
        r1.Dispose();
        r2.Dispose();
        Bis(env, .4);
        Pruefe(events.Count(e => e.EventTyp == "personal_wechsel_start") == 1, "Bei leeren Warteschlangen keine unnoetigen Rueckwege");
        using var s1 = pool.Anfordern("Schwester", 3);
        using var s2 = pool.Anfordern("Schwester", 4);
        Bis(env, .41);
        Dauer = .45;
        s2.Dispose();
        Bis(env, .8);
        Pruefe(!events.Any(e => e.EventTyp == "personal_aufgabe_start" && e.Zeit >= .45), "Nach Schichtende werden keine neuen Aufgaben begonnen");
        Pruefe(pool.SchwesterWartend == 0, "Stornierte wartende Anforderung hinterlaesst keinen Geisterpatienten");
        Dauer = 480;
    }

    private static void Gesamtlauf()
    {
        OriginalSimulation.PersonalzahlenSetzen(new Dictionary<string, int> { ["Rezeption"] = 1, ["Schwester"] = 2, ["Arzt"] = 2 });
        SchwesterKonfiguration.Rollenwechsel = new RollenwechselOptionen { Aktiv = true };
        var events = new List<SimulationLiveEvent>();
        OriginalSimulation.VollstaendigAusfuehren(events.Add);
        var wiederholung = new List<SimulationLiveEvent>();
        OriginalSimulation.VollstaendigAusfuehren(wiederholung.Add);
        Pruefe(events.SequenceEqual(wiederholung), "Rollenwechsel ist mit gleichem Seed exakt reproduzierbar");
        Pruefe(events.Any(e => e.EventTyp == "startet_rezeption" && e.PersonalId == "schwester_2"), "Im vollstaendigen Patientenlauf arbeitet Schwester 2 an der Rezeption");
        var belegt = new Dictionary<string, int>();
        var unterwegs = new Dictionary<string, double>();
        var plaetze = new HashSet<string>();
        foreach (var ev in events.Where(e => e.EventTyp.StartsWith("personal_")))
        {
            string id = ev.PersonalId ?? throw new InvalidOperationException("Personal-ID fehlt.");
            switch (ev.EventTyp)
            {
                case "personal_aufgabe_start":
                    if (belegt.ContainsKey(id) || unterwegs.ContainsKey(id) || !plaetze.Add(ev.ArbeitsplatzId!))
                        throw new InvalidOperationException("Doppelte Person- oder Arbeitsplatzbelegung.");
                    belegt[id] = ev.PatientId;
                    break;
                case "personal_aufgabe_ende":
                    if (!belegt.Remove(id, out int patientId) || patientId != ev.PatientId || !plaetze.Remove(ev.ArbeitsplatzId!))
                        throw new InvalidOperationException("Unpassende Freigabe.");
                    break;
                case "personal_wechsel_start":
                    if (belegt.ContainsKey(id) || !unterwegs.TryAdd(id, ev.Zeit))
                        throw new InvalidOperationException("Wechsel waehrend einer Aufgabe.");
                    break;
                case "personal_wechsel_ende":
                    if (!unterwegs.Remove(id, out double start) || Math.Abs(ev.Zeit - start - 10.0 / 60) > 1e-7)
                        throw new InvalidOperationException("Fehlerhafte Wechselzeit.");
                    break;
            }
        }
        Pruefe(belegt.Count == 0 && unterwegs.Count == 0 && plaetze.Count == 0, "Gesamtlauf hat keine Doppelbelegung und gibt alle Personen und Plaetze frei");
    }
}
