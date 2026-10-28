using System;
using EZDose.CheckPillBox;
using EZDose.Hardware;
using UnityEngine;

namespace EZDose.PillBoxUnion
{
    /// <summary>
    /// RFID reader on the dispenser. Presence is a real hardware state, identity is
    /// resolved through the roster mapping.
    /// </summary>
    public sealed class RfidPillBoxChannel : IPillBoxChannel, IPillBoxIdentitySource
    {
        private readonly DispenserController dispenser;
        private readonly Func<string, string> resolvePatientId;
        private readonly bool enabled;

        public PillBoxChannelKind Kind { get { return PillBoxChannelKind.Rfid; } }

        public event Action<PillBoxIdentity> IdentityObserved;
        public event Action<bool> PresenceObserved;
        public event Action<string> Faulted;

        public RfidPillBoxChannel(
            DispenserController dispenser,
            Func<string, string> resolvePatientId,
            bool enabled = true)
        {
            this.dispenser = dispenser;
            this.resolvePatientId = resolvePatientId;
            this.enabled = enabled;

            if (dispenser == null)
            {
                return;
            }

        }

        public bool IsAvailable
        {
            get { return enabled && dispenser != null && dispenser.IsConnected; }
        }

        public bool IsPresent
        {
            get { return dispenser != null && dispenser.IsRfidCardPresent; }
        }

        public void Arm()
        {
            Disarm();
            if (!enabled || dispenser == null) return;
            dispenser.OnRfidCardPlaced += HandlePlaced;
            dispenser.OnRfidCardRemoved += HandleRemoved;
            dispenser.OnRfidCardChanged += HandleChanged;
        }

        public void Disarm()
        {
            if (dispenser == null) return;
            dispenser.OnRfidCardPlaced -= HandlePlaced;
            dispenser.OnRfidCardRemoved -= HandleRemoved;
            dispenser.OnRfidCardChanged -= HandleChanged;
        }

        public void Poll()
        {
        }

        public PillBoxIdentity ReadCurrentIdentity()
        {
            string uid = dispenser != null ? dispenser.CurrentRfidUid : null;
            return new PillBoxIdentity(Kind, uid, Resolve(uid));
        }

        private string Resolve(string uid)
        {
            if (string.IsNullOrWhiteSpace(uid) || resolvePatientId == null)
            {
                return string.Empty;
            }

            return resolvePatientId(uid);
        }

        private void HandlePlaced(string uid)
        {
            RaisePresence(true);
            RaiseIdentity(new PillBoxIdentity(Kind, uid, Resolve(uid)));
        }

        private void HandleRemoved(string uid)
        {
            RaisePresence(false);
        }

        private void HandleChanged(string oldUid, string newUid)
        {
            // A direct UID change is a swap; never carry the old box's identity over.
            RaisePresence(false);
            HandlePlaced(newUid);
        }

        private void RaiseIdentity(PillBoxIdentity identity)
        {
            var handler = IdentityObserved;
            if (handler != null)
            {
                handler(identity);
            }
        }

        private void RaisePresence(bool present)
        {
            var handler = PresenceObserved;
            if (handler != null)
            {
                handler(present);
            }
        }
    }

    /// <summary>
    /// Barcode reader mounted on the dispenser. Edge-triggered: the firmware reports
    /// APPEARED once and DISAPPEARED once per box, with no heartbeat.
    /// </summary>
    public sealed class DispenserBarcodePillBoxChannel : IPillBoxChannel, IPillBoxIdentitySource
    {
        private readonly DispenserController dispenser;
        private readonly bool enabled;

        public PillBoxChannelKind Kind { get { return PillBoxChannelKind.DispenserCamera; } }

        public event Action<PillBoxIdentity> IdentityObserved;
        public event Action<bool> PresenceObserved;
        public event Action<string> Faulted;

        public DispenserBarcodePillBoxChannel(DispenserController dispenser, bool enabled = true)
        {
            this.dispenser = dispenser;
            this.enabled = enabled;

            if (dispenser == null)
            {
                return;
            }

        }

        public bool IsAvailable
        {
            get { return enabled && dispenser != null && dispenser.IsConnected; }
        }

        public bool IsPresent
        {
            get { return dispenser != null && dispenser.IsBarcodePresent; }
        }

        public void Arm()
        {
            Disarm();
            if (!enabled || dispenser == null) return;
            dispenser.OnBarcodeAppeared += HandleAppeared;
            dispenser.OnBarcodeDisappeared += HandleDisappeared;
        }

        public void Disarm()
        {
            if (dispenser == null) return;
            dispenser.OnBarcodeAppeared -= HandleAppeared;
            dispenser.OnBarcodeDisappeared -= HandleDisappeared;
        }

        public void Poll()
        {
        }

        public PillBoxIdentity ReadCurrentIdentity()
        {
            string barcode = dispenser != null ? dispenser.CurrentBarcode : null;
            return new PillBoxIdentity(Kind, barcode, ToPatientId(barcode));
        }

        private static string ToPatientId(string barcode)
        {
            return string.IsNullOrWhiteSpace(barcode)
                ? string.Empty
                : CheckPillBoxController.ParsePatientIdFromBarcode(barcode);
        }

        private void HandleAppeared(string barcode)
        {
            RaisePresence(true);
            var handler = IdentityObserved;
            if (handler != null)
            {
                handler(new PillBoxIdentity(Kind, barcode, ToPatientId(barcode)));
            }
        }

        private void HandleDisappeared(string barcode)
        {
            RaisePresence(false);
        }

        private void RaisePresence(bool present)
        {
            var handler = PresenceObserved;
            if (handler != null)
            {
                handler(present);
            }
        }
    }

    /// <summary>
    /// Tablet camera. This channel is a one-shot decoder: the controller stops the
    /// camera after every successful decode, so presence is "decoded recently" and the
    /// channel re-arms itself while a session is open. Decode silence cannot prove
    /// removal, so this channel never emits PresenceObserved(false); sessions that
    /// observed a box through this channel require manual removal confirmation.
    /// </summary>
    public sealed class TabletCameraPillBoxChannel : IPillBoxChannel
    {
        private const double CameraProbeIntervalSeconds = 5.0;
        private const double RearmIntervalSeconds = 1.0;

        private readonly CheckPillBoxController scanner;
        private readonly Func<double> now;
        private readonly double presenceHoldSeconds;
        private readonly bool enabled;

        private bool armed;
        private bool hasCamera;
        private double nextCameraProbe;
        private double nextStartAttempt;
        private double? lastSeenAt;

        public PillBoxChannelKind Kind { get { return PillBoxChannelKind.TabletCamera; } }

        public event Action<PillBoxIdentity> IdentityObserved;
        public event Action<bool> PresenceObserved;
        public event Action<string> Faulted;

        public TabletCameraPillBoxChannel(
            CheckPillBoxController scanner,
            Func<double> monotonicSeconds = null,
            double presenceHoldSeconds = 3.0,
            bool enabled = true)
        {
            this.scanner = scanner;
            this.now = monotonicSeconds ?? (() => PillBoxClock.Now);
            this.presenceHoldSeconds = Math.Max(0.5, presenceHoldSeconds);
            this.enabled = enabled;
        }

        public bool IsAvailable
        {
            get
            {
                if (!enabled || scanner == null)
                {
                    return false;
                }

                double current = now();
                if (current >= nextCameraProbe)
                {
                    nextCameraProbe = current + CameraProbeIntervalSeconds;
                    hasCamera = ProbeCamera();
                }

                return hasCamera;
            }
        }

        public bool IsPresent
        {
            get
            {
                return lastSeenAt.HasValue && now() - lastSeenAt.Value <= presenceHoldSeconds;
            }
        }

        public void Arm()
        {
            armed = true;
            lastSeenAt = null;
            nextStartAttempt = 0.0;
            Attach();
            StartScan();
        }

        public void Disarm()
        {
            armed = false;
            lastSeenAt = null;
            Detach();

            if (scanner != null)
            {
                scanner.StopScanner();
            }
        }

        public void Poll()
        {
            if (!armed || IsPresent || !IsAvailable)
            {
                return;
            }

            double current = now();
            if (current < nextStartAttempt)
            {
                return;
            }

            nextStartAttempt = current + RearmIntervalSeconds;
            StartScan();
        }

        private static bool ProbeCamera()
        {
            try
            {
                WebCamDevice[] devices = WebCamTexture.devices;
                return devices != null && devices.Length > 0;
            }
            catch (Exception)
            {
                return false;
            }
        }

        private void Attach()
        {
            if (scanner == null)
            {
                return;
            }

            scanner.OnBoxVerified -= HandleDecoded;
            scanner.OnBoxVerified += HandleDecoded;
            scanner.OnScanError -= HandleScanError;
            scanner.OnScanError += HandleScanError;
        }

        private void Detach()
        {
            if (scanner == null)
            {
                return;
            }

            scanner.OnBoxVerified -= HandleDecoded;
            scanner.OnScanError -= HandleScanError;
        }

        private void StartScan()
        {
            if (scanner == null || !IsAvailable)
            {
                return;
            }

            try
            {
                // An empty expectation makes every decode surface here; the union
                // checker owns the patient match, not this channel.
                scanner.StartScanner(string.Empty, string.Empty);
            }
            catch (Exception e)
            {
                var handler = Faulted;
                if (handler != null)
                {
                    handler(e.Message);
                }
            }
        }

        private void HandleDecoded(string code)
        {
            if (!armed)
            {
                return;
            }

            lastSeenAt = now();
            RaisePresence(true);

            var handler = IdentityObserved;
            if (handler != null)
            {
                handler(new PillBoxIdentity(
                    Kind,
                    code,
                    CheckPillBoxController.ParsePatientIdFromBarcode(code)));
            }
        }

        private void HandleScanError(string error)
        {
            if (!armed)
            {
                return;
            }

            var handler = Faulted;
            if (handler != null)
            {
                handler(error);
            }
        }

        private void RaisePresence(bool present)
        {
            var handler = PresenceObserved;
            if (handler != null)
            {
                handler(present);
            }
        }
    }
}
