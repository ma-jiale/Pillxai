using System;

namespace EZDose.PillBoxUnion
{
    /// <summary>
    /// Internal sensor identity. This value must never be rendered to the operator;
    /// it is only used for logging, diagnostics and the developer overlay.
    /// </summary>
    public enum PillBoxChannelKind
    {
        Rfid = 0,
        DispenserCamera = 1,
        TabletCamera = 2,

        /// <summary>Checker-level message that belongs to no single channel.</summary>
        Internal = 3
    }

    /// <summary>Machine state of the union checker. Not shown to the operator.</summary>
    public enum PillBoxPhase
    {
        Idle = 0,
        AwaitingBox = 1,
        Ready = 2,
        Rejected = 3,
        AwaitingRemoval = 4,
        Cleared = 5,
        Blocked = 6
    }

    /// <summary>
    /// Operator-facing state. Every value has exactly one neutral sentence in
    /// <see cref="PillBoxFeedbackText"/>; no channel name may leak into the UI.
    /// </summary>
    public enum PillBoxFeedback
    {
        None = 0,
        PlaceBox = 1,
        Ready = 2,
        WrongBox = 3,
        IdentityConflict = 4,
        Unrecognized = 5,
        RemoveBox = 6,
        BoxRemoved = 7,
        ConfirmRemovalManually = 8,
        EquipmentNotReady = 9,
        DeviceDisconnected = 10
    }

    /// <summary>One channel's opinion about the box currently in the tray.</summary>
    public struct PillBoxIdentity
    {
        public PillBoxChannelKind Kind;
        public string Raw;
        public string PatientId;

        public bool IsResolved
        {
            get { return !string.IsNullOrEmpty(PatientId); }
        }

        public PillBoxIdentity(PillBoxChannelKind kind, string raw, string patientId)
        {
            Kind = kind;
            Raw = raw ?? string.Empty;
            PatientId = (patientId ?? string.Empty).Trim();
        }
    }

    /// <summary>
    /// A single way of observing a pill box. Implementations own their hardware
    /// wiring; the checker never knows which hardware exists.
    /// </summary>
    public interface IPillBoxChannel
    {
        PillBoxChannelKind Kind { get; }

        /// <summary>True when this channel can contribute on this machine right now.</summary>
        bool IsAvailable { get; }

        /// <summary>Best-effort presence. False means "not seen", never "proven absent".</summary>
        bool IsPresent { get; }

        /// <summary>Start watching for a new tray session. Must be idempotent.</summary>
        void Arm();

        /// <summary>Stop watching. Must be idempotent and release any camera the channel opened.</summary>
        void Disarm();

        /// <summary>Called once per frame by the checker; polling channels no-op.</summary>
        void Poll();

        event Action<PillBoxIdentity> IdentityObserved;
        /// <summary>
        /// False requires an explicit removal observation. Decode timeouts, state
        /// resets and connection failures must never emit false.
        /// </summary>
        event Action<bool> PresenceObserved;
        event Action<string> Faulted;
    }

    /// <summary>Monotonic clock shared by the checker and its channels.</summary>
    public static class PillBoxClock
    {
        private static readonly double TicksToSeconds = 1.0 / System.Diagnostics.Stopwatch.Frequency;

        public static double Now
        {
            get { return System.Diagnostics.Stopwatch.GetTimestamp() * TicksToSeconds; }
        }
    }

    /// <summary>Identifier comparison shared by every channel, so the three paths agree.</summary>
    public static class PillBoxId
    {
        public static string Normalize(string id)
        {
            return (id ?? string.Empty).Trim().ToUpperInvariant();
        }

        /// <summary>
        /// Ordinal comparison that also treats "000010" and "10" as the same patient,
        /// because the dispenser reports zero-padded barcodes while the roster may not.
        /// </summary>
        public static bool SameId(string a, string b)
        {
            string left = Normalize(a);
            string right = Normalize(b);
            if (left.Length == 0 || right.Length == 0)
            {
                return false;
            }

            if (string.Equals(left, right, StringComparison.Ordinal))
            {
                return true;
            }

            if (!IsAllDigits(left) || !IsAllDigits(right))
            {
                return false;
            }

            return string.Equals(TrimLeadingZeros(left), TrimLeadingZeros(right), StringComparison.Ordinal);
        }

        private static bool IsAllDigits(string value)
        {
            for (int i = 0; i < value.Length; i++)
            {
                if (value[i] < '0' || value[i] > '9')
                {
                    return false;
                }
            }

            return true;
        }

        private static string TrimLeadingZeros(string value)
        {
            string trimmed = value.TrimStart('0');
            return trimmed.Length == 0 ? "0" : trimmed;
        }
    }
}
