using System;

namespace EZDose.Hardware
{
    /// <summary>
    /// Keeps the barcode currently reported by the dispenser camera for the open-tray session.
    /// </summary>
    public sealed class BarcodePresenceMonitor
    {
        public string CurrentBarcode { get; private set; }
        public bool IsPresent => !string.IsNullOrEmpty(CurrentBarcode);
        public bool HasSeenBarcode { get; private set; }

        public bool ReportAppeared(string barcode)
        {
            if (string.IsNullOrWhiteSpace(barcode))
            {
                return false;
            }

            barcode = barcode.Trim();
            if (string.Equals(CurrentBarcode, barcode, StringComparison.Ordinal))
            {
                return false;
            }

            CurrentBarcode = barcode;
            HasSeenBarcode = true;
            return true;
        }

        public bool ReportDisappeared(string barcode)
        {
            if (!IsPresent || !string.Equals(
                    CurrentBarcode,
                    (barcode ?? string.Empty).Trim(),
                    StringComparison.Ordinal))
            {
                return false;
            }

            CurrentBarcode = null;
            return true;
        }

        public void Reset()
        {
            CurrentBarcode = null;
            HasSeenBarcode = false;
        }
    }
}
