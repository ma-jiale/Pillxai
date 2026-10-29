using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using EZDose.PillBoxUnion;

namespace UnityEngine.UI { public class Text { public string text; } }
namespace UnityEngine { public static class Debug { public static void LogError(object message) { throw new Exception(message.ToString()); } } }
public class TestObject { public bool active = true; public void SetActive(bool value) { active = value; } }
public class TestButton
{
    public TestObject gameObject = new TestObject();
    public bool interactable;
    public TestClick onClick = new TestClick();
    public T GetComponentInChildren<T>(bool includeInactive) where T : new() { return new T(); }
}
public class TestClick
{
    private Action action;
    public void RemoveAllListeners() { action = null; }
    public void AddListener(Action value) { action += value; }
    public void Invoke() { if (action != null) action(); }
}
public class MainController
{
    public static MainController Instance;
    public int CloseCalls;
    public bool CloseSucceeds = true;
    public Task<bool> CloseTrayAsync() { CloseCalls++; return Task.FromResult(CloseSucceeds); }
    public void ClearCurrentPatient() { }
}
public class CancelUiHarness
{
    public PillBoxUnionChecker pillBoxChecker;
    public bool deviceLostDialogVisible, isCancellingScan, _scanLocked;
    public TaskCompletionSource<bool> manualRemovalConfirmation;
    public TestButton homeScanConfirmButton = new TestButton(), correctDialogConfirmButton = new TestButton();
    public TestButton completeDialogConfirmButton = new TestButton(), homeScanCancelButton = new TestButton();
    public TestObject homeScanDialog = new TestObject(), correctBoxDialog = new TestObject();
    public UnityEngine.UI.Text homeScanDialogMessageText = new UnityEngine.UI.Text(), correctBoxDialogText = new UnityEngine.UI.Text();
    private string homeSceneName = "Home";
    public int ReturnsHome;
    private void SetHomeScanDialogTitle(string text, bool isError = false) { }
    private void SetCompletionDialogMessage(string text) { }
    private void EndIdentificationSession(bool stopScanner) { pillBoxChecker.EndSession(); pillBoxChecker = null; }
    private Task LoadSceneAsyncSafe(string name) { ReturnsHome++; return Task.CompletedTask; }
    public Task Cancel() { return CancelScanAndReturnHomeAsync(); }
    public Task<bool> Complete() { return WaitForPillBoxRemovalAsync(true); }
    /* PRODUCTION_UI_METHODS */
}
public class CancelTestChannel : IPillBoxChannel
{
    public PillBoxChannelKind Kind { get; set; }
    public bool IsAvailable { get; set; } = true;
    public bool IsPresent { get; set; }
    public event Action<PillBoxIdentity> IdentityObserved;
    public event Action<bool> PresenceObserved;
    public event Action<string> Faulted { add { } remove { } }
    public void Arm() { } public void Disarm() { } public void Poll() { }
    public void Report(bool value) { IsPresent = value; PresenceObserved?.Invoke(value); }
    public void Identify(string value) { IdentityObserved?.Invoke(new PillBoxIdentity(Kind, value, value)); }
}
public static class EmptyTrayCancelTests
{
    private sealed class Fixture
    {
        public double Time;
        public CancelTestChannel Channel = new CancelTestChannel();
        public PillBoxUnionChecker Checker;
        public CancelUiHarness Ui;
        public MainController Device = new MainController();
        public Fixture(bool auto = false)
        {
            MainController.Instance = Device;
            Checker = new PillBoxUnionChecker(() => Time);
            Checker.Register(Channel);
            Checker.StartSession("000010", auto);
            Ui = new CancelUiHarness { pillBoxChecker = Checker };
        }
        public void Tick(double time) { Time = time; Checker.Tick(); }
    }
    private static int passed;
    private static void Check(bool condition, string name)
    {
        if (!condition) throw new Exception("FAIL " + name);
        passed++; Console.WriteLine("PASS " + name);
    }
    public static void Run()
    {
        foreach (bool auto in new[] { false, true })
        {
            var f = new Fixture(auto); var task = f.Ui.Cancel();
            Check(task.IsCompleted && f.Device.CloseCalls == 1 && f.Ui.ReturnsHome == 1,
                "empty tray closes immediately, auto=" + auto);
        }
        foreach (PillBoxChannelKind kind in new[] { PillBoxChannelKind.Rfid, PillBoxChannelKind.DispenserCamera, PillBoxChannelKind.TabletCamera })
        {
            var f = new Fixture(); f.Channel.Kind = kind; f.Channel.Report(true);
            var task = f.Ui.Cancel(); f.Tick(2);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, kind + " present blocks close");
            f.Ui.Cancel().GetAwaiter().GetResult();
            Check(f.Device.CloseCalls == 0, kind + " repeated cancel cannot bypass wait");
            f.Channel.Report(false); f.Tick(3);
            Check(f.Device.CloseCalls == 0, kind + " removal requires stability");
            f.Tick(3.6);
            Check(task.IsCompleted && f.Device.CloseCalls == 1, kind + " stable removal closes once");
        }
        {
            var f = new Fixture(); f.Channel.Kind = PillBoxChannelKind.TabletCamera;
            f.Channel.Report(true); var task = f.Ui.Cancel();
            f.Channel.IsPresent = false; f.Tick(10);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "tablet decode silence is not removal");
        }
        {
            var f = new Fixture();
            var second = new CancelTestChannel { Kind = PillBoxChannelKind.DispenserCamera };
            f.Checker.Register(second); f.Channel.Report(true); second.Report(true);
            var task = f.Ui.Cancel(); f.Channel.Report(false); f.Tick(2);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "all observed channels must report removal");
            second.Report(false); f.Tick(4);
            Check(task.IsCompleted && f.Device.CloseCalls == 1, "both channels clear permits close");
        }
        {
            var f = new Fixture(); f.Channel.Report(true); var task = f.Ui.Cancel();
            f.Channel.Report(false); f.Tick(1); f.Channel.Report(true); f.Tick(2);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "reinsertion cancels removal stability");
            f.Channel.Report(false); f.Tick(4);
            Check(task.IsCompleted && f.Device.CloseCalls == 1, "fresh stable removal after reinsertion closes");
        }
        {
            var f = new Fixture(); f.Channel.Report(true); f.Channel.Identify("wrong");
            var task = f.Ui.Cancel(); f.Tick(2);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "wrong identity still counts as placed");
        }
        {
            var f = new Fixture(); f.Channel.Report(true); f.Channel.Report(false);
            var task = f.Ui.Cancel();
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "removed before cancel retains presence history");
            f.Tick(2); Check(task.IsCompleted && f.Device.CloseCalls == 1, "early removal passes original check");
        }
        {
            var f = new Fixture(); f.Channel.IsPresent = true;
            f.Checker.StartSession("000010", false);
            var task = f.Ui.Cancel(); f.Tick(2);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "already present at session start blocks close");
        }
        {
            var f = new Fixture(); var task = f.Ui.Complete(); f.Tick(119);
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "completion never uses empty cancellation bypass");
            f.Tick(120);
            Check(f.Ui.manualRemovalConfirmation != null && !task.IsCompleted, "completion timeout retains manual confirmation");
        }
        {
            var f = new Fixture(); f.Ui.deviceLostDialogVisible = true;
            var task = f.Ui.Cancel(); f.Tick(120);
            Check(task.IsCompleted && f.Device.CloseCalls == 0, "device loss cannot bypass removal");
        }
        {
            var f = new Fixture(); f.Channel.IsAvailable = false; var task = f.Ui.Cancel();
            Check(!task.IsCompleted && f.Device.CloseCalls == 0, "no usable sensor does not auto close");
        }
        {
            var f = new Fixture(); f.Device.CloseSucceeds = false;
            f.Ui.Cancel().GetAwaiter().GetResult();
            Check(f.Device.CloseCalls == 1 && f.Ui.ReturnsHome == 0 && f.Ui.homeScanCancelButton.gameObject.active,
                "failed empty close exposes retry without returning home");
            f.Device.CloseSucceeds = true; f.Ui.Cancel().GetAwaiter().GetResult();
            Check(f.Device.CloseCalls == 2 && f.Ui.ReturnsHome == 1, "explicit close retry succeeds");
        }
        {
            var f = new Fixture(); f.Channel.Report(true); f.Channel.Report(false);
            f.Checker.EndSession();
            Check(!f.Checker.CanCancelWithoutRemoval, "ended session is not an empty cancellation");
            f.Checker.StartSession("000010", false);
            Check(f.Checker.CanCancelWithoutRemoval, "new session resets placement history");
        }
        Console.WriteLine("Passed " + passed + " checks; no hardware commands sent.");
    }
}
