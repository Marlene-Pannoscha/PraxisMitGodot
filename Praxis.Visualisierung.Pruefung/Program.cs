using System.Text.Json;
using Praxis.Visualisierung.Anbindung;
using simSharpSimulation;

static void Pruefe(bool bedingung, string text)
{
    if (!bedingung) throw new InvalidOperationException(text);
    Console.WriteLine("OK: " + text);
}
var controller = new VisualisierungsController();
var originalEvents = new List<SimulationLiveEvent>();
var original = OriginalSimulation.VollstaendigAusfuehren(originalEvents.Add);
Pruefe(originalEvents.SequenceEqual(controller.Ablaufplan), "Vorlauf = direkter Originallauf, einschließlich exakter Zeiten und Mitarbeiter-IDs");
Pruefe(originalEvents.Count > 0, "Originalereignisse vorhanden");
var live = new List<SimulationLiveEvent>();
controller.EreignisAufgetreten += live.Add;
controller.Starten();
controller.Fortschalten(0.5);
controller.Pausieren();
var pause = controller.Status;
controller.Fortschalten(20);
Pruefe(controller.Status == pause, "Pause hält Modelluhr und Ereignisse an");
controller.GeschwindigkeitSetzen(2);
controller.Starten();
var vorher = controller.Status.Zeit;
controller.Fortschalten(0.125);
Pruefe(Math.Abs(controller.Status.Zeit - vorher - 2) < 1e-10, "Geschwindigkeit verändert ausschließlich den Zeittakt");
while (!controller.Status.Abgeschlossen) controller.Fortschalten(0.137);
Pruefe(live.SequenceEqual(originalEvents), "Inkrementeller Godot-Lauf = vollständiger Originallauf");
Pruefe(controller.Status.Ereigniszahl == originalEvents.Count && !controller.Status.Laeuft, "Vollständiger Abschluss");
controller.Zuruecksetzen();
Pruefe(controller.Status.Zeit == 0 && controller.Status.Ereigniszahl == 0 && !controller.Status.Laeuft, "Reset setzt Uhr und Laufzustand zurück");
live.Clear();
controller.Starten();
controller.Fortschalten(10000);
Pruefe(live.SequenceEqual(originalEvents), "Reset reproduziert sämtliche Originalereignisse");
foreach (double ungueltig in new[] { 0, 6, double.NaN, double.PositiveInfinity })
{
    bool abgewiesen = false;
    try { controller.GeschwindigkeitSetzen(ungueltig); } catch (ArgumentOutOfRangeException) { abgewiesen = true; }
    Pruefe(abgewiesen, $"Ungültige Geschwindigkeit {ungueltig} abgefangen");
}
Console.WriteLine($"ERGEBNIS: {originalEvents.Count} Ereignisse, {originalEvents.Where(e => e.EventTyp == "betritt_klinik").Select(e => e.PatientId).Distinct().Count()} Patienten, {original.AnzahlBehandeltHit} Hit, {original.AnzahlAbgebrochenMiss} Miss.");
if (args.Length == 2 && args[0] == "--export")
{
    File.WriteAllText(args[1], JsonSerializer.Serialize(originalEvents, new JsonSerializerOptions
    { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true }));
}
