using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace EZDose.PillBoxUnion
{
    /// <summary>Per-channel state for the developer overlay and log dumps.</summary>
    public sealed class PillBoxChannelSnapshot
    {
        public PillBoxChannelKind Kind { get; private set; }
        public bool IsAvailable { get; private set; }
        public bool IsPresent { get; private set; }
        public string ResolvedPatientId { get; private set; }

        public PillBoxChannelSnapshot(
            PillBoxChannelKind kind,
            bool isAvailable,
            bool isPresent,
            string resolvedPatientId)
        {
            Kind = kind;
            IsAvailable = isAvailable;
            IsPresent = isPresent;
            ResolvedPatientId = resolvedPatientId ?? string.Empty;
        }
    }

    /// <summary>
    /// One pill-box checker for the whole machine.
    ///
    /// Contract:
    ///  - any single working channel is enough to run the flow;
    ///  - a missing channel is invisible to the operator (no prompt, no error);
    ///  - identity disagreement revokes trust instead of picking a winner;
    ///  - removal is only declared when every channel that actually saw the box
    ///    reports absence for a stable window, so a box is never clamped.
    ///
    /// The checker is pure C#: no UnityEngine types, injectable clock.
    /// </summary>
    public sealed class PillBoxUnionChecker
    {
        public const double DefaultRemovalHoldSeconds = 1.5;
        public const double DefaultRemovalTimeoutSeconds = 120.0;

        private readonly List<IPillBoxChannel> channels = new List<IPillBoxChannel>();
        private readonly Dictionary<PillBoxChannelKind, string> resolvedByChannel =
            new Dictionary<PillBoxChannelKind, string>();
        private readonly HashSet<PillBoxChannelKind> confirmedPresence =
            new HashSet<PillBoxChannelKind>();
        private readonly Func<double> now;
        private readonly HashSet<PillBoxChannelKind> confirmedAbsence =
            new HashSet<PillBoxChannelKind>();

        private string expectedPatientId = string.Empty;
        private bool autoMode;
        private bool awaitingRemoval;
        private double? clearSince;
        private double removalDeadline;
        private TaskCompletionSource<bool> removalTcs;
        private PillBoxFeedback feedback = PillBoxFeedback.None;

        public PillBoxPhase Phase { get; private set; }
        public string VerifiedPatientId { get; private set; }
        public PillBoxFeedback Feedback { get { return feedback; } }
        public double RemovalHoldSeconds { get; private set; }

        /// <summary>
        /// Explicit cancellation before any box was observed needs no removal event.
        /// This is not proof of removal and must not be used for dispensing completion.
        /// Presence history survives removal and identity rejection until EndSession.
        /// </summary>
        public bool CanCancelWithoutRemoval
        {
            get
            {
                if (Phase != PillBoxPhase.AwaitingBox || !IsUsable || confirmedPresence.Count != 0)
                    return false;
                foreach (IPillBoxChannel channel in channels)
                {
                    if (channel.IsPresent) return false;
                }
                return true;
            }
        }

        /// <summary>Raised once per box, with the canonical patient id.</summary>
        public event Action<string> Verified;
        /// <summary>Raised when the operator-facing state changes.</summary>
        public event Action<PillBoxFeedback> FeedbackChanged;
        /// <summary>Channel-level detail. Logs and dev overlay only.</summary>
        public event Action<PillBoxChannelKind, string> Diagnostic;

        public PillBoxUnionChecker(
            Func<double> monotonicSeconds = null,
            double removalHoldSeconds = DefaultRemovalHoldSeconds)
        {
            now = monotonicSeconds ?? (() => PillBoxClock.Now);
            RemovalHoldSeconds = Math.Max(0.0, removalHoldSeconds);
            Phase = PillBoxPhase.Idle;
        }

        /// <summary>Number of channels that can contribute right now.</summary>
        public int AvailableChannelCount
        {
            get
            {
                int count = 0;
                for (int i = 0; i < channels.Count; i++)
                {
                    if (channels[i].IsAvailable)
                    {
                        count++;
                    }
                }

                return count;
            }
        }

        /// <summary>True when at least one channel is usable. Zero channels is the only blocker.</summary>
        public bool IsUsable
        {
            get { return AvailableChannelCount > 0; }
        }

        public void Register(IPillBoxChannel channel)
        {
            if (channel == null || channels.Contains(channel))
            {
                return;
            }

            channels.Add(channel);

            // Bind the channel's own identity into the handler: PresenceObserved is a
            // bare Action<bool>, so the kind has to be captured here.
            IPillBoxChannel captured = channel;
            captured.IdentityObserved += identity => HandleIdentity(identity);
            captured.PresenceObserved += present => HandlePresence(captured.Kind, present);
            captured.Faulted += reason => HandleFault(captured.Kind, reason);
        }

        public void StartSession(string expectedPatientId, bool autoMode)
        {
            EndSession();

            this.expectedPatientId = PillBoxId.Normalize(expectedPatientId);
            this.autoMode = autoMode;
            VerifiedPatientId = null;
            resolvedByChannel.Clear();
            confirmedPresence.Clear();
            confirmedAbsence.Clear();
            clearSince = null;
            Phase = PillBoxPhase.AwaitingBox;

            for (int i = 0; i < channels.Count; i++)
            {
                // Arm even while unavailable so a later connection can be observed.
                // Each adapter decides whether it can start its hardware now.
                channels[i].Arm();
            }

            if (!IsUsable)
            {
                Phase = PillBoxPhase.Blocked;
                SetFeedback(PillBoxFeedback.EquipmentNotReady);
                return;
            }

            SetFeedback(PillBoxFeedback.PlaceBox);
            RescanAlreadyPresentBoxes();
        }

        public void EndSession()
        {
            awaitingRemoval = false;
            clearSince = null;
            var pending = removalTcs;
            removalTcs = null;
            if (pending != null)
            {
                pending.TrySetResult(false);
            }

            for (int i = 0; i < channels.Count; i++)
            {
                channels[i].Disarm();
            }

            resolvedByChannel.Clear();
            confirmedPresence.Clear();
            confirmedAbsence.Clear();
            VerifiedPatientId = null;
            Phase = PillBoxPhase.Idle;
            SetFeedback(PillBoxFeedback.None);
        }

        /// <summary>
        /// Wait for the tray to be free. Returns false on timeout, and the caller then
        /// asks the operator to confirm by hand; the checker never closes on a guess.
        /// </summary>
        public Task<bool> WaitForRemovalAsync(double timeoutSeconds)
        {
            if (!IsUsable)
            {
                SetFeedback(PillBoxFeedback.EquipmentNotReady);
                return Task.FromResult(false);
            }

            if (removalTcs != null)
            {
                return removalTcs.Task;
            }

            awaitingRemoval = true;
            clearSince = null;
            Phase = PillBoxPhase.AwaitingRemoval;
            removalDeadline = now() + (timeoutSeconds <= 0 ? DefaultRemovalTimeoutSeconds : timeoutSeconds);
            removalTcs = new TaskCompletionSource<bool>();
            Task<bool> pendingTask = removalTcs.Task;
            SetFeedback(PillBoxFeedback.RemoveBox);
            EvaluateClear();
            return pendingTask;
        }

        /// <summary>Called once per frame by the host UI.</summary>
        public void Tick()
        {
            for (int i = 0; i < channels.Count; i++)
            {
                channels[i].Poll();
            }

            if (Phase == PillBoxPhase.Idle)
            {
                return;
            }

            RefreshAvailability();

            if (Phase == PillBoxPhase.Idle || Phase == PillBoxPhase.Cleared)
            {
                return;
            }

            if (!awaitingRemoval)
            {
                return;
            }

            if (!IsUsable)
            {
                // No channel can confirm removal; fall through to the timeout so the
                // operator gets a manual confirmation instead of a silent hang.
                if (now() >= removalDeadline)
                {
                    FailRemovalWait("no usable channel");
                }

                return;
            }

            if (now() >= removalDeadline)
            {
                FailRemovalWait("removal wait timed out");
                return;
            }

            EvaluateClear();
        }

        private void FailRemovalWait(string reason)
        {
            awaitingRemoval = false;
            clearSince = null;
            var pending = removalTcs;
            removalTcs = null;
            Phase = PillBoxPhase.Rejected;
            SetFeedback(PillBoxFeedback.ConfirmRemovalManually);
            Diagnostic?.Invoke(PillBoxChannelKind.Internal, reason);
            if (pending != null)
            {
                pending.TrySetResult(false);
            }
        }

        public void NotifyDeviceLost()
        {
            if (Phase == PillBoxPhase.Idle)
            {
                return;
            }

            confirmedAbsence.Clear();
            clearSince = null;
            SetFeedback(PillBoxFeedback.DeviceDisconnected);
        }

        public PillBoxChannelSnapshot[] Snapshot()
        {
            var result = new List<PillBoxChannelSnapshot>(channels.Count);
            for (int i = 0; i < channels.Count; i++)
            {
                IPillBoxChannel channel = channels[i];
                string resolved;
                if (!resolvedByChannel.TryGetValue(channel.Kind, out resolved))
                {
                    resolved = string.Empty;
                }

                result.Add(new PillBoxChannelSnapshot(
                    channel.Kind, channel.IsAvailable, channel.IsPresent, resolved));
            }

            return result.ToArray();
        }

        private void RefreshAvailability()
        {
            foreach (IPillBoxChannel channel in channels)
            {
                if (!channel.IsAvailable && confirmedPresence.Contains(channel.Kind))
                {
                    confirmedAbsence.Remove(channel.Kind);
                    clearSince = null;
                }
            }
            bool usable = IsUsable;

            if (!usable)
            {
                if (Phase == PillBoxPhase.AwaitingBox ||
                    Phase == PillBoxPhase.Ready ||
                    Phase == PillBoxPhase.Rejected ||
                    Phase == PillBoxPhase.AwaitingRemoval)
                {
                    Phase = PillBoxPhase.Blocked;
                    SetFeedback(PillBoxFeedback.EquipmentNotReady);
                }

                return;
            }

            if (Phase == PillBoxPhase.Blocked)
            {
                if (awaitingRemoval)
                {
                    Phase = PillBoxPhase.AwaitingRemoval;
                    SetFeedback(PillBoxFeedback.RemoveBox);
                    return;
                }

                Phase = PillBoxPhase.AwaitingBox;
                SetFeedback(PillBoxFeedback.PlaceBox);
                RescanAlreadyPresentBoxes();
            }
        }

        /// <summary>
        /// A box may already sit in the tray when the session starts (open tray, delayed
        /// UI). Ask each channel for what it is holding instead of waiting for an edge.
        /// </summary>
        private void RescanAlreadyPresentBoxes()
        {
            for (int i = 0; i < channels.Count; i++)
            {
                IPillBoxChannel channel = channels[i];
                if (!channel.IsAvailable || !channel.IsPresent)
                {
                    continue;
                }

                confirmedPresence.Add(channel.Kind);
                confirmedAbsence.Remove(channel.Kind);
                PillBoxIdentity identity;
                if (channel is IPillBoxIdentitySource)
                {
                    identity = ((IPillBoxIdentitySource)channel).ReadCurrentIdentity();
                    if (identity.IsResolved || !string.IsNullOrEmpty(identity.Raw))
                    {
                        HandleIdentity(identity);
                    }
                }
            }
        }

        private void HandleIdentity(PillBoxIdentity identity)
        {
            if (Phase == PillBoxPhase.Idle || awaitingRemoval)
            {
                return;
            }

            IPillBoxChannel source = channels.Find(channel => channel.Kind == identity.Kind);
            if (source == null || !source.IsAvailable) return;

            Diagnostic?.Invoke(identity.Kind,
                "identity raw='" + identity.Raw + "' patient='" + identity.PatientId + "'");

            if (!identity.IsResolved)
            {
                // Unbound or unparsable box: mention it only while nothing is confirmed,
                // and never let one silent channel veto a box another channel resolved.
                if (VerifiedPatientId == null && Phase != PillBoxPhase.Rejected)
                {
                    SetFeedback(PillBoxFeedback.Unrecognized);
                }

                return;
            }

            string previous;
            if (resolvedByChannel.TryGetValue(identity.Kind, out previous) &&
                !PillBoxId.SameId(previous, identity.PatientId))
            {
                Diagnostic?.Invoke(identity.Kind,
                    "identity changed on same channel; revoking " + previous);
                RevokeVerification(false);
            }

            resolvedByChannel[identity.Kind] = identity.PatientId;

            string agreed = FindAgreedPatientId();
            if (agreed == null)
            {
                VerifiedPatientId = null;
                Phase = PillBoxPhase.Rejected;
                SetFeedback(PillBoxFeedback.IdentityConflict);
                return;
            }

            if (!autoMode && !PillBoxId.SameId(agreed, expectedPatientId))
            {
                VerifiedPatientId = null;
                Phase = PillBoxPhase.Rejected;
                SetFeedback(PillBoxFeedback.WrongBox);
                return;
            }

            if (VerifiedPatientId != null && PillBoxId.SameId(VerifiedPatientId, agreed))
            {
                return;
            }

            VerifiedPatientId = agreed;
            Phase = PillBoxPhase.Ready;
            SetFeedback(PillBoxFeedback.Ready);
            var handler = Verified;
            if (handler != null)
            {
                handler(agreed);
            }
        }

        private string FindAgreedPatientId()
        {
            var distinct = new List<string>();
            foreach (KeyValuePair<PillBoxChannelKind, string> pair in resolvedByChannel)
            {
                bool seen = false;
                for (int i = 0; i < distinct.Count; i++)
                {
                    if (PillBoxId.SameId(distinct[i], pair.Value))
                    {
                        seen = true;
                        break;
                    }
                }

                if (!seen)
                {
                    distinct.Add(pair.Value);
                }
            }

            return distinct.Count == 1 ? distinct[0] : null;
        }

        private void HandlePresence(PillBoxChannelKind kind, bool isPresent)
        {
            if (Phase == PillBoxPhase.Idle)
            {
                return;
            }

            IPillBoxChannel source = channels.Find(channel => channel.Kind == kind);
            if (source == null || !source.IsAvailable)
            {
                confirmedAbsence.Remove(kind);
                clearSince = null;
                return;
            }

            if (isPresent)
            {
                confirmedPresence.Add(kind);
                confirmedAbsence.Remove(kind);
                if (Phase == PillBoxPhase.Rejected)
                {
                    Phase = PillBoxPhase.AwaitingBox;
                }

                EvaluateClear();
                return;
            }

            Diagnostic?.Invoke(kind, "presence cleared");
            if (confirmedPresence.Contains(kind))
            {
                confirmedAbsence.Add(kind);
            }
            resolvedByChannel.Remove(kind);

            if (awaitingRemoval)
            {
                EvaluateClear();
                return;
            }

            // The box left before it was used: forget the identity, keep waiting.
            if (AllAvailableChannelsClear())
            {
                RevokeVerification();
            }
        }

        private void HandleFault(PillBoxChannelKind kind, string reason)
        {
            confirmedAbsence.Remove(kind);
            clearSince = null;
            Diagnostic?.Invoke(kind, "channel fault: " + reason);
            RefreshAvailability();
        }

        private bool AllAvailableChannelsClear()
        {
            bool anyAvailable = false;
            for (int i = 0; i < channels.Count; i++)
            {
                if (!channels[i].IsAvailable)
                {
                    continue;
                }

                anyAvailable = true;
                if (channels[i].IsPresent)
                {
                    return false;
                }
            }

            return anyAvailable;
        }

        private void EvaluateClear()
        {
            if (!awaitingRemoval)
            {
                return;
            }

            // Safety rule: a channel that never saw the box cannot vouch for its removal.
            // Without at least one positive observation we wait for the timeout instead
            // of closing the tray on silence.
            if (confirmedPresence.Count == 0)
            {
                clearSince = null;
                return;
            }

            for (int i = 0; i < channels.Count; i++)
            {
                IPillBoxChannel channel = channels[i];
                if (!confirmedPresence.Contains(channel.Kind))
                {
                    continue;
                }

                if (!channel.IsAvailable || channel.IsPresent ||
                    !confirmedAbsence.Contains(channel.Kind))
                {
                    clearSince = null;
                    return;
                }
            }

            if (!clearSince.HasValue)
            {
                clearSince = now();
            }

            if (now() - clearSince.Value < RemovalHoldSeconds)
            {
                return;
            }

            awaitingRemoval = false;
            clearSince = null;
            Phase = PillBoxPhase.Cleared;
            SetFeedback(PillBoxFeedback.BoxRemoved);

            var pending = removalTcs;
            removalTcs = null;
            if (pending != null)
            {
                pending.TrySetResult(true);
            }
        }

        private void RevokeVerification(bool clearIdentities = true)
        {
            bool changed = VerifiedPatientId != null;
            VerifiedPatientId = null;
            if (clearIdentities)
            {
                resolvedByChannel.Clear();
            }
            clearSince = null;

            if (Phase != PillBoxPhase.AwaitingRemoval)
            {
                Phase = PillBoxPhase.AwaitingBox;
            }

            if (changed)
            {
                Diagnostic?.Invoke(PillBoxChannelKind.Internal, "verification revoked");
            }

            SetFeedback(PillBoxFeedback.PlaceBox);
        }

        private void SetFeedback(PillBoxFeedback next)
        {
            if (feedback == next)
            {
                return;
            }

            feedback = next;
            var handler = FeedbackChanged;
            if (handler != null)
            {
                handler(next);
            }
        }
    }

    /// <summary>
    /// Optional capability: a channel that can be asked what it holds right now.
    /// Used when a box is already inside the tray when the session starts.
    /// </summary>
    public interface IPillBoxIdentitySource
    {
        PillBoxIdentity ReadCurrentIdentity();
    }
}
