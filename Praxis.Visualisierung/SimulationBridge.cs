using Godot;
using Praxis.Visualisierung.Anbindung;
using simSharpSimulation;
using GArray = Godot.Collections.Array<Godot.Collections.Dictionary>;
using GDictionary = Godot.Collections.Dictionary;

// Gehört ausschließlich zur Visualisierung. Der Simulationskern kennt diese Klasse nicht.
public partial class SimulationBridge : Node
{
    [Signal] public delegate void ZustandGeaendertEventHandler(GDictionary zustand);
    [Signal] public delegate void EreignisAufgetretenEventHandler(GDictionary ereignis);
    private VisualisierungsController? controller;

    public string Laden()
    {
        try
        {
            controller = new VisualisierungsController();
            controller.ZustandGeaendert += s => EmitSignal(SignalName.ZustandGeaendert, StatusDaten(s));
            controller.EreignisAufgetreten += e => EmitSignal(SignalName.EreignisAufgetreten, EreignisDaten(e));
            return "";
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); return ex.Message; }
    }
    public void Initialisieren() => EmitSignal(SignalName.ZustandGeaendert, StatusDaten(Controller.Status));
    public void Starten() => Controller.Starten();
    public void Pausieren() => Controller.Pausieren();
    public void Zuruecksetzen() => Controller.Zuruecksetzen();
    public void GeschwindigkeitSetzen(double faktor) => Controller.GeschwindigkeitSetzen(faktor);
    public void Fortschalten(double delta) => Controller.Fortschalten(delta);
    public GDictionary ZustandLesen() => StatusDaten(Controller.Status);
    public GArray DarstellungsplanLesen()
    {
        var result = new GArray();
        foreach (var ev in Controller.Ablaufplan) result.Add(EreignisDaten(ev));
        return result;
    }
    private VisualisierungsController Controller => controller ?? throw new InvalidOperationException("Simulation zuerst laden.");
    private static GDictionary EreignisDaten(SimulationLiveEvent ev) => new()
    {
        ["zeit"] = ev.Zeit, ["eventTyp"] = ev.EventTyp, ["vonZustand"] = ev.VonZustand,
        ["zuZustand"] = ev.ZuZustand, ["patientId"] = ev.PatientId,
        ["arztId"] = ev.ArztId ?? 0, ["schwesterId"] = ev.SchwesterId ?? 0
    };
    private GDictionary StatusDaten(VisualisierungsStatus s) => new()
    {
        ["zeit"] = s.Zeit, ["geschwindigkeit"] = s.Geschwindigkeit, ["laeuft"] = s.Laeuft,
        ["abgeschlossen"] = s.Abgeschlossen, ["ereigniszahl"] = s.Ereigniszahl,
        ["lauf"] = s.Lauf, ["dauer"] = s.Dauer, ["oeffnungsdauer"] = Controller.Oeffnungsdauer
    };
}
