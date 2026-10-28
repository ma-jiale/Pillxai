using System;
using System.Collections.Generic;

namespace EZDose.PillBoxUnion
{
    /// <summary>
    /// The only place operator-facing pill-box copy lives.
    /// Rule: the operator sees one sentence about the box, never how it was sensed.
    /// </summary>
    public static class PillBoxFeedbackText
    {
        // Words that describe the implementation rather than the task. They must not
        // appear in any string returned by For(); the developer overlay and logs may
        // still use them.
        private static readonly string[] ForbiddenTechWords =
        {
            "摄像头", "扫描", "扫码", "条码", "二维码", "RFID", "串口", "蓝牙",
            "传感器", "机载", "硬件", "识别源", "相机"
        };

        private static readonly Dictionary<PillBoxFeedback, string> Text =
            new Dictionary<PillBoxFeedback, string>
            {
                { PillBoxFeedback.None, "" },
                { PillBoxFeedback.PlaceBox, "请将药盒放入舱内" },
                { PillBoxFeedback.Ready, "药盒已确认，请核对处方" },
                { PillBoxFeedback.WrongBox, "该药盒与当前长者不符，请取出" },
                { PillBoxFeedback.IdentityConflict, "药盒信息不一致，请取出后重新放入" },
                { PillBoxFeedback.Unrecognized, "无法确认该药盒，请取出后重新放入" },
                { PillBoxFeedback.RemoveBox, "请取出药盒" },
                { PillBoxFeedback.BoxRemoved, "药盒已取出" },
                { PillBoxFeedback.ConfirmRemovalManually, "请确认药盒是否已完全取出" },
                { PillBoxFeedback.EquipmentNotReady, "设备未就绪，请联系维护人员" },
                { PillBoxFeedback.DeviceDisconnected, "连接中断，正在等待恢复" }
            };

        /// <summary>Short title for the dialog header.</summary>
        public static string Title(PillBoxFeedback feedback)
        {
            switch (feedback)
            {
                case PillBoxFeedback.PlaceBox:
                    return "放入药盒";
                case PillBoxFeedback.Ready:
                    return "核验成功";
                case PillBoxFeedback.RemoveBox:
                    return "取出药盒";
                case PillBoxFeedback.BoxRemoved:
                    return "已取出";
                case PillBoxFeedback.EquipmentNotReady:
                case PillBoxFeedback.DeviceDisconnected:
                    return "设备提示";
                case PillBoxFeedback.WrongBox:
                case PillBoxFeedback.IdentityConflict:
                case PillBoxFeedback.Unrecognized:
                case PillBoxFeedback.ConfirmRemovalManually:
                    return "请注意";
                default:
                    return string.Empty;
            }
        }

        /// <summary>Body sentence for the operator.</summary>
        public static string For(PillBoxFeedback feedback)
        {
            string value;
            return Text.TryGetValue(feedback, out value) ? value : string.Empty;
        }

        /// <summary>True when the phrase is free of implementation vocabulary.</summary>
        public static bool IsNeutral(string phrase)
        {
            if (string.IsNullOrEmpty(phrase))
            {
                return true;
            }

            for (int i = 0; i < ForbiddenTechWords.Length; i++)
            {
                if (phrase.IndexOf(ForbiddenTechWords[i], StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return false;
                }
            }

            return true;
        }

        /// <summary>Editor-time guard so a new sentence cannot leak a sensor name.</summary>
        public static void AssertAllNeutral()
        {
            foreach (KeyValuePair<PillBoxFeedback, string> pair in Text)
            {
                string title = Title(pair.Key);
                if (!IsNeutral(pair.Value) || !IsNeutral(title))
                {
                    UnityEngine.Debug.LogError(
                        "Pill-box copy leaks implementation detail for " + pair.Key);
                }
            }
        }
    }
}
