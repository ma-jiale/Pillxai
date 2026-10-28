using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using EZDose.MainFlow;
using EZDose.CheckPillBox;
using EZDose.PillCounter;
using EZDose.Hardware;
using EZDose.Calibration;
using UnityEngine.EventSystems;
using EZDose;
using EZDose.Prescriptions;
using EZDose.PillBoxUnion;

namespace EZDose.UI
{
    /// <summary>
    /// Defines the available sub-pages on the right panel of the Home screen.
    /// Add new page types here when extending the UI.
    /// </summary>
    public enum HomeSubPage
    {
        PatientCard = 0,  // Default page showing patient card information
        CountPills = 1,   // Page for counting pills / dispensing overview
        Setting = 2       // Settings page for app configuration
    }

    /// <summary>
    /// Handles UI binding, scene transitions, and simple user prompts.
    /// Also manages Home page sub-page switching (stacked pages on the right panel).
    /// </summary>
    public class UIManager : MonoBehaviour
    {
        [Header("Scene Names")]
        [SerializeField] private string homeSceneName = "Home";
        [SerializeField] private string scanSceneName = "Scan";
        [SerializeField] private string dispenseSceneName = "Dispense";

        [Header("Home UI")]
        [SerializeField] private Transform patientListRoot;
        [SerializeField] private GameObject patientButtonPrefab;
        [SerializeField] private Button refreshButton;
        [SerializeField] private Text homeHintText;

        [Header("Device Management")]
        [Tooltip("Button to open device management dialog")]
        [SerializeField] private Button manageDevicesButton;
        [Tooltip("Button to clean pills from the turntable")]
        [SerializeField] private Button cleanTurntableButton;

        [Header("Device Button Visuals")]
        [SerializeField] private Image connectedIcon;
        [SerializeField] private Image disconnectedIcon;
        [SerializeField] private Text manageDevicesButtonText;
        
        [Tooltip("Reference to DeviceManagerUI component")]
        [SerializeField] private DeviceManagerUI deviceManagerUI;

        [Header("Dispenser Connection Check")]
        [Tooltip("Dialog shown when clicking patient card and dispenser is not connected")]
        [SerializeField] private GameObject connectDispenserDialog;
        [Tooltip("Confirm button in the connection required dialog")]
        [SerializeField] private Button connectDialogConfirmButton;

        [Header("Device Lost Dialog")]
        [Tooltip("Dialog shown when the dispenser becomes unreachable during scan or dispensing")]
        [SerializeField] private GameObject deviceLostDialog;
        [Tooltip("Confirm button in the device lost dialog")]
        [SerializeField] private Button deviceLostConfirmButton;
        [Tooltip("Optional message text in the device lost dialog")]
        [SerializeField] private Text deviceLostMessageText;

        [Header("Home Sub-Pages (Right Panel)")]
        [Tooltip("Reference to the PatientCard sub-page container. This page shows patient information.")]
        [SerializeField] private GameObject patientCardPage;

        [Tooltip("Reference to the CountPills sub-page container. This page handles pill counting display.")]
        [SerializeField] private GameObject countPillsPage;

        [Tooltip("Reference to the Setting sub-page container. This page provides app settings.")]
        [SerializeField] private GameObject settingPage;

        [Header("Home Sub-Page Navigation Buttons")]
        [Tooltip("Button that switches to the PatientCard page when clicked.")]
        [SerializeField] private Button patientCardButton;

        [Tooltip("Button that switches to the CountPills page when clicked.")]
        [SerializeField] private Button countPillsButton;

        [Tooltip("Button that switches to the Setting page when clicked.")]
        [SerializeField] private Button settingButton;

        [Header("Home Sub-Page Configuration")]
        [Tooltip("The sub-page to display when the Home scene first loads.")]
        [SerializeField] private HomeSubPage defaultSubPage = HomeSubPage.PatientCard;

        [Tooltip("Color applied to the active navigation button to indicate the current page.")]
        [SerializeField] private Color activeButtonColor = new Color(0.2f, 0.6f, 1f, 1f);

        [Tooltip("Color applied to inactive navigation buttons.")]
        [SerializeField] private Color inactiveButtonColor = Color.white;

        [Tooltip("Enable/disable visual highlighting on active navigation button.")]
        [SerializeField] private bool useButtonHighlight = true;

        [Header("Scan UI")]
        [SerializeField] private Button backToHomeButton;
        [SerializeField] private RectTransform lightBar;
        [SerializeField] private float lightBarSpeed = 200f;
        [SerializeField] private CheckPillBoxController scanner;
        [SerializeField] private GameObject correctBoxDialog;
        [SerializeField] private Button correctDialogConfirmButton;
        [Tooltip("扫码成功提示文本组件，留空则自动查找")]
        [SerializeField] private Text correctBoxDialogText;
        [SerializeField] private GameObject mismatchDialog;
        [SerializeField] private Button mismatchHomeButton;
        [SerializeField] private Button mismatchRetryButton;

        [Header("Home Scan Dialog")]
        [Tooltip("New dedicated dialog for scan verification and confirmation in the Home scene")]
        [SerializeField] private GameObject homeScanDialog;
        [SerializeField] private Text homeScanDialogTitleText;
        [SerializeField] private Text homeScanDialogMessageText;
        [SerializeField] private Button homeScanConfirmButton;
        [SerializeField] private Button homeScanCancelButton;
        [SerializeField] private Button homeScanSwitchCameraButton;
        [SerializeField] private Text homeScanSwitchCameraButtonText;
        [SerializeField] private GameObject homeScanInsertIcon;
        [SerializeField] private Text homeScanPrescriptionDetailsText;

        [Header("Home Auto Scan Button")]
        [Tooltip("Button to insert tray and start automatic patient recognition in the Home scene")]
        [SerializeField] private Button autoScanButton;

        [Tooltip("Button to switch camera")]
        [SerializeField] private Button switchCameraButton;
        [Tooltip("Text for camera switch button")]
        [SerializeField] private Text switchCameraButtonText;

        [Header("Dispense UI")]
        [SerializeField] private Text totalPillsText;
        [SerializeField] private Text medicineNameText;
        [SerializeField] private Text patientNameText;
        [SerializeField] private Text progressPercentText;
        [Tooltip("展示当前分发药品剂量规格的文本框")]
        [SerializeField] private Text dosageSpecText;
        [Tooltip("Progress fill image, should use Image Type Filled")]
        [SerializeField] private Image progressFillImage;
        [SerializeField] private RawImage pillPreview;
        [SerializeField] private Button captureBackgroundButton;
        [SerializeField] private GameObject plateSwitchDialog;
        [SerializeField] private Button plateSwitchConfirmButton;
        [Tooltip("换盘提示文本组件，留空则自动查找")]
        [SerializeField] private Text plateSwitchDialogText;
        [SerializeField] private GameObject completeDialog;
        [SerializeField] private Button completeDialogConfirmButton;
        [SerializeField] private Text completeDialogMessageText;
        [SerializeField] private PillCounterController pillCounterController;
        
        [Tooltip("Pill calibration dialog")]
        [SerializeField] private PillCalibrationDialog pillCalibrationDialog;
        
        [Header("Motor Stall Dialog")]
        [SerializeField] private GameObject stalledDialog;
        [SerializeField] private Button clearMotorStallButton;
        [SerializeField] private Text stalledMessageText;
        [SerializeField] private Text stalledTitleText;
        private bool isClearingMotorStall;

        [Header("Manual Servo Tuning")]
        [Tooltip("Slider for directly tuning the servo angle")]
        [SerializeField] private Slider servoAngleTuningSlider;
        [Tooltip("Text showing the current servo angle setting")]
        [SerializeField] private Text servoAngleTuningText;
        [Tooltip("Keyboard step for servo angle tuning with Left/Right arrows.")]
        [SerializeField] private float servoKeyboardStep = 0.02f;
        [Tooltip("Repeat interval while holding Left/Right arrows.")]
        [SerializeField] private float servoKeyboardRepeatInterval = 0.08f;
        
        [Header("Dispense UI (Drug & Controls)")]
        [Tooltip("Image for the current drug")]
        [SerializeField] private Image drugImage;
        
        [Tooltip("Button to skip the current medicine")]
        [SerializeField] private Button skipMedicineButton;
        
        [Tooltip("Pause/resume dispensing button")]
        [SerializeField] private Button pauseResumeButton;
        
        [Tooltip("Pause/resume button text")]
        [SerializeField] private Text pauseResumeButtonText;
        
        [Header("Skip Confirm Dialog")]
        [Tooltip("Skip confirmation dialog")]
        [SerializeField] private GameObject skipConfirmDialog;
        
        [Tooltip("Skip confirmation button")]
        [SerializeField] private Button skipConfirmButton;
        [Tooltip("Button to clean pills from the turntable while the skip confirm dialog is open")]
        [SerializeField] private Button skipCleanTurntableButton;
        
        [Tooltip("Toggle to mark the skipped medicine as dispensed")]
        [SerializeField] private Toggle skipMarkDispensedToggle;

        [Tooltip("Text showing the skipped medicine name")]
        [SerializeField] private Text skipMedicineNameText;
        
        [Header("Next Medicine Preview")]
        [Tooltip("Text showing next medicine information")]
        [SerializeField] private Text nextMedicineText;
        private readonly List<GameObject> spawnedPatientButtons = new List<GameObject>();
        private Coroutine lightBarRoutine;

        // Progress bar smooth animation
        private float targetProgressValue;
        private Coroutine progressAnimRoutine;

        // Currently active sub-page in Home scene
        private HomeSubPage currentSubPage;

        // Dictionary mapping sub-page enum to page GameObject for easy access
        private Dictionary<HomeSubPage, GameObject> subPageMap;

        private bool isStartingPatientFlow = false;
        private bool isStartingAutoFlow = false;
        private bool _scanLocked = false;
        private bool isConfirmingDispense = false;
        private bool isCancellingScan = false;
        private PillBoxUnionChecker pillBoxChecker;
        private bool identificationAutoMode;
        private bool completionRemovalMode;
        private TaskCompletionSource<bool> manualRemovalConfirmation;
        private PillBoxIdentificationResult lastIdentificationResult;

        private bool identificationInvalidatedDuringClose;
        private int completionMonitoringSession;
        private bool isShowingCompletion;
        private bool isReturningHomeAfterCompletion;
        [Header("Pill Box Removal Safety Settings")]
        [Tooltip("所有参与通道明确确认离位后的稳定等待时间（毫秒），最低 1500ms。")]
        [SerializeField] private int completionRfidClearStabilityMilliseconds = 1500;


        private int CompletionRfidClearStabilityMilliseconds => Math.Max(1500, completionRfidClearStabilityMilliseconds);
        private Color homeScanDialogTitleOriginalColor = Color.black;
        private bool isTitleOriginalColorCaptured = false;

        private void SetHomeScanDialogTitle(string text, bool isError = false)
        {
            if (homeScanDialogTitleText == null) return;

            if (!isTitleOriginalColorCaptured)
            {
                homeScanDialogTitleOriginalColor = homeScanDialogTitleText.color;
                isTitleOriginalColorCaptured = true;
            }

            homeScanDialogTitleText.text = text;
            homeScanDialogTitleText.color = isError ? Color.red : homeScanDialogTitleOriginalColor;
        }

        // Dictionary mapping sub-page enum to its corresponding button
        private Dictionary<HomeSubPage, Button> subPageButtonMap;
        private bool isServoKeyboardTuning;
        private bool servoKeyboardValueChanged;
        private float nextServoKeyboardStepTime;
        private bool deviceLostDialogVisible;

        /// <summary>
        /// Event fired when the active Home sub-page changes.
        /// Subscribers receive the newly activated page type.
        /// </summary>
        public event Action<HomeSubPage> OnSubPageChanged;

        /// <summary>
        /// Gets the currently displayed Home sub-page.
        /// </summary>
        public HomeSubPage CurrentSubPage => currentSubPage;

        private void Start()
        {
            SetupDeviceLostDialog();
            var main = MainController.Instance;
            if (main != null)
            {
                main.DeviceLost += OnDeviceLost;
            }

            var scene = SceneManager.GetActiveScene().name;
            if (scene == homeSceneName)
            {
                InitHome();
            }
            else if (scene == scanSceneName)
            {
                InitScan();
            }
            else if (scene == dispenseSceneName)
            {
                InitDispense();
            }
        }

        private void OnDestroy()
        {
            UnsubscribeEvents();
        }

        private void Update()
        {
            pillBoxChecker?.Tick();
#if UNITY_STANDALONE_WIN || UNITY_EDITOR_WIN
            if (ShortcutInput.IsTextInputFocused())
            {
                return;
            }

            var scene = SceneManager.GetActiveScene().name;
            if (HandleGlobalDialogShortcuts())
            {
                return;
            }

            if (scene == homeSceneName)
            {
                HandleHomeShortcuts();
            }
            else if (scene == scanSceneName)
            {
                HandleScanShortcuts();
            }
            else if (scene == dispenseSceneName)
            {
                HandleDispenseShortcuts();
            }
#endif
        }

        #region Home

        private void InitHome()
        {
            var main = MainController.Instance;
            if (main != null)
            {
                main.PatientsUpdated += RenderPatientButtons;
                RenderPatientButtons(main.GetPatients());
            }

            if (refreshButton != null)
            {
                refreshButton.onClick.AddListener(() => FireAndForget(RefreshPatientsAsync()));
            }

            if (autoScanButton != null)
            {
                autoScanButton.onClick.AddListener(() => FireAndForget(StartAutoRecognitionFlowAsync()));
            }

            // Adjust scroll sensitivity for the patient list to support comfortable mouse wheel scrolling
            if (patientListRoot != null)
            {
                var scrollRect = patientListRoot.GetComponentInParent<ScrollRect>();
                if (scrollRect != null)
                {
                    scrollRect.scrollSensitivity = 50f;
                }
            }

            // Setup device management button
            if (manageDevicesButton != null)
            {
                manageDevicesButton.onClick.AddListener(OpenDeviceManagementDialog);
            }

            if (cleanTurntableButton != null)
            {
                cleanTurntableButton.onClick.AddListener(() => FireAndForget(CleanTurntableAsync(cleanTurntableButton)));
            }

            // Setup connection required dialog confirm button
            if (connectDialogConfirmButton != null)
            {
                connectDialogConfirmButton.onClick.AddListener(() =>
                {
                    if (connectDispenserDialog != null) connectDispenserDialog.SetActive(false);
                    OpenDeviceManagementDialog();
                });
            }

            // Initialize device manager UI if present
            if (deviceManagerUI == null)
            {
                deviceManagerUI = FindObjectOfType<DeviceManagerUI>();
            }

            // [NEW] Subscribe to connection events
            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser != null)
            {
                dispenser.OnConnectionStateChanged += OnDispenserConnectionChanged;
                UpdateDeviceButtonState(dispenser.IsConnected);
            }

            // Initialize sub-page switching system
            InitializeSubPages();
        }

        #region Home Sub-Page Management

        /// <summary>
        /// Initializes the sub-page system: creates mappings and sets up button listeners.
        /// Called during Home scene initialization.
        /// </summary>
        private void InitializeSubPages()
        {
            // Create page mapping: enum -> GameObject
            subPageMap = new Dictionary<HomeSubPage, GameObject>
            {
                { HomeSubPage.PatientCard, patientCardPage },
                { HomeSubPage.CountPills, countPillsPage },
                { HomeSubPage.Setting, settingPage }
            };

            // Create button mapping: enum -> Button
            subPageButtonMap = new Dictionary<HomeSubPage, Button>
            {
                { HomeSubPage.PatientCard, patientCardButton },
                { HomeSubPage.CountPills, countPillsButton },
                { HomeSubPage.Setting, settingButton }
            };

            // Setup button click listeners
            SetupSubPageButtonListeners();

            // Show the default page on startup
            ShowSubPage(defaultSubPage);
        }

        /// <summary>
        /// Attaches click listeners to all sub-page navigation buttons.
        /// Each button is configured to switch to its corresponding page when clicked.
        /// </summary>
        private void SetupSubPageButtonListeners()
        {
            // Assign click handler for PatientCard button
            if (patientCardButton != null)
            {
                patientCardButton.onClick.AddListener(() => ShowSubPage(HomeSubPage.PatientCard));
            }

            // Assign click handler for CountPills button
            if (countPillsButton != null)
            {
                countPillsButton.onClick.AddListener(() => ShowSubPage(HomeSubPage.CountPills));
            }

            // Assign click handler for Setting button
            if (settingButton != null)
            {
                settingButton.onClick.AddListener(() => ShowSubPage(HomeSubPage.Setting));
            }
        }

        /// <summary>
        /// Switches to the specified sub-page, hiding all other pages.
        /// This is the main method for sub-page navigation within the Home scene.
        /// </summary>
        /// <param name="targetPage">The sub-page to display.</param>
        public void ShowSubPage(HomeSubPage targetPage)
        {
            // Skip if already on the target page and it's visible
            if (currentSubPage == targetPage && IsSubPageActive(targetPage))
            {
                return;
            }

            // Hide all sub-pages first
            HideAllSubPages();

            // Show the target sub-page
            if (subPageMap != null && subPageMap.TryGetValue(targetPage, out var pageObject) && pageObject != null)
            {
                pageObject.SetActive(true);
                currentSubPage = targetPage;

                // Update button visual states to reflect active page
                UpdateSubPageButtonStates(targetPage);

                // Notify subscribers about the page change
                OnSubPageChanged?.Invoke(targetPage);

                EZLog.D(EZLog.Module.UI, $"Switched to sub-page: {targetPage}");
            }
            else
            {
                EZLog.W(EZLog.Module.UI, $"Sub-page not found or not assigned: {targetPage}");
            }
        }

        /// <summary>
        /// Hides all sub-pages by setting their GameObjects inactive.
        /// Called before showing a new page to ensure only one page is visible at a time.
        /// </summary>
        private void HideAllSubPages()
        {
            if (subPageMap == null)
            {
                return;
            }

            foreach (var kvp in subPageMap)
            {
                if (kvp.Value != null)
                {
                    kvp.Value.SetActive(false);
                }
            }
        }

        /// <summary>
        /// Checks if a specific sub-page is currently active (visible).
        /// </summary>
        /// <param name="page">The sub-page to check.</param>
        /// <returns>True if the sub-page is active, false otherwise.</returns>
        private bool IsSubPageActive(HomeSubPage page)
        {
            if (subPageMap != null && subPageMap.TryGetValue(page, out var pageObject) && pageObject != null)
            {
                return pageObject.activeSelf;
            }
            return false;
        }

        /// <summary>
        /// Updates the visual appearance of navigation buttons to indicate the active sub-page.
        /// The active button gets a highlighted color while others return to default.
        /// </summary>
        /// <param name="activePage">The currently active sub-page.</param>
        private void UpdateSubPageButtonStates(HomeSubPage activePage)
        {
            if (!useButtonHighlight || subPageButtonMap == null)
            {
                return;
            }

            foreach (var kvp in subPageButtonMap)
            {
                var button = kvp.Value;
                if (button == null)
                {
                    continue;
                }

                // Get the button's Image component for color modification
                var buttonImage = button.GetComponent<Image>();
                if (buttonImage == null)
                {
                    continue;
                }

                // Apply active or inactive color based on whether this button's page is active
                bool isActive = kvp.Key == activePage;
                buttonImage.color = isActive ? activeButtonColor : inactiveButtonColor;
            }
        }

        /// <summary>
        /// Programmatically switches to the PatientCard sub-page.
        /// Convenience method for external scripts.
        /// </summary>
        public void GoToPatientCardPage()
        {
            ShowSubPage(HomeSubPage.PatientCard);
        }

        /// <summary>
        /// Programmatically switches to the CountPills sub-page.
        /// Convenience method for external scripts.
        /// </summary>
        public void GoToCountPillsPage()
        {
            ShowSubPage(HomeSubPage.CountPills);
        }

        /// <summary>
        /// Programmatically switches to the Setting sub-page.
        /// Convenience method for external scripts.
        /// </summary>
        public void GoToSettingPage()
        {
            ShowSubPage(HomeSubPage.Setting);
        }

        /// <summary>
        /// Navigates to the next sub-page in the sequence (wraps around).
        /// Useful for implementing swipe gestures or keyboard navigation.
        /// </summary>
        public void GoToNextSubPage()
        {
            int totalPages = Enum.GetValues(typeof(HomeSubPage)).Length;
            int nextIndex = ((int)currentSubPage + 1) % totalPages;
            ShowSubPage((HomeSubPage)nextIndex);
        }

        /// <summary>
        /// Navigates to the previous sub-page in the sequence (wraps around).
        /// Useful for implementing swipe gestures or keyboard navigation.
        /// </summary>
        public void GoToPreviousSubPage()
        {
            int totalPages = Enum.GetValues(typeof(HomeSubPage)).Length;
            int prevIndex = ((int)currentSubPage - 1 + totalPages) % totalPages;
            ShowSubPage((HomeSubPage)prevIndex);
        }

        /// <summary>
        /// Resets to the default sub-page configured in the Inspector.
        /// </summary>
        public void ResetToDefaultSubPage()
        {
            ShowSubPage(defaultSubPage);
        }

        /// <summary>
        /// Opens the device management dialog for Bluetooth connection management
        /// </summary>
        public void OpenDeviceManagementDialog()
        {
            if (deviceManagerUI != null)
            {
                deviceManagerUI.ShowDialog();
                EZLog.D(EZLog.Module.UI, "Device management dialog opened");
            }
            else
            {
                EZLog.W(EZLog.Module.UI, "DeviceManagerUI not assigned or found");
            }
        }

        /// <summary>
        /// Closes the device management dialog
        /// </summary>
        public void CloseDeviceManagementDialog()
        {
            if (deviceManagerUI != null)
            {
                deviceManagerUI.HideDialog();
                EZLog.D(EZLog.Module.UI, "Device management dialog closed");
            }
        }

        /// <summary>
        /// Gets the GameObject reference for a specific sub-page.
        /// Useful for external scripts that need to access page contents.
        /// </summary>
        /// <param name="page">The sub-page type to retrieve.</param>
        /// <returns>The GameObject for the specified sub-page, or null if not found.</returns>
        public GameObject GetSubPageObject(HomeSubPage page)
        {
            if (subPageMap != null && subPageMap.TryGetValue(page, out var pageObject))
            {
                return pageObject;
            }
            return null;
        }

        private void OnDispenserConnectionChanged(string state)
        {
            // state is "Connected", "Disconnected", "Connecting"
            bool isConnected = (state == "Connected");
            UpdateDeviceButtonState(isConnected);
        }

        private void UpdateDeviceButtonState(bool isConnected)
        {
            if (manageDevicesButtonText != null)
            {
                manageDevicesButtonText.text = isConnected ? "分药机已连接" : "分药机未连接";
            }

            if (connectedIcon != null)
            {
                connectedIcon.gameObject.SetActive(isConnected);
            }

            if (disconnectedIcon != null)
            {
                disconnectedIcon.gameObject.SetActive(!isConnected);
            }
        }

        #endregion

        private async Task RefreshPatientsAsync()
        {
            var main = MainController.Instance;
            if (main == null)
            {
                return;
            }

            await main.RefreshPatientsAsync();
        }

        private async Task CleanTurntableAsync(Button sourceButton)
        {
            var main = MainController.Instance;
            if (main == null)
            {
                return;
            }

            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser == null || !dispenser.IsConnected)
            {
                EZLog.W(EZLog.Module.UI, "Dispenser not connected, showing prompt");
                if (connectDispenserDialog != null)
                {
                    connectDispenserDialog.SetActive(true);
                }
                return;
            }

            if (sourceButton != null)
            {
                sourceButton.interactable = false;
            }

            try
            {
                bool success = await main.CleanTurntableAsync();
                EZLog.I(EZLog.Module.UI, success ? "Turntable cleaned successfully" : "Turntable cleaning failed");
            }
            finally
            {
                if (sourceButton != null)
                {
                    sourceButton.interactable = true;
                }
            }
        }

        private void RenderPatientButtons(List<PatientStatus> patients)
        {
            ClearPatientButtons();

            if (patientListRoot == null || patientButtonPrefab == null || patients == null)
            {
                return;
            }

            foreach (var patient in patients)
            {
                var go = Instantiate(patientButtonPrefab, patientListRoot);
                spawnedPatientButtons.Add(go);

                var button = go.GetComponent<Button>();
                var texts = go.GetComponentsInChildren<Text>();
                
                // Find and set patient name text (usually the first or larger text)
                // Find and set medicine count text (the one showing "X种药品需要分配")
                foreach (var textComponent in texts)
                {
                    if (textComponent.name.Contains("Name") || textComponent == texts[0])
                    {
                        string displayName = patient.PatientName;
                        if (!string.IsNullOrEmpty(patient.BedNumber))
                        {
                            displayName += $" {patient.BedNumber}床";
                        }
                        textComponent.text = displayName;
                    }
                    else if (textComponent.name.Contains("Medicine") || textComponent.name.Contains("Count"))
                    {
                        textComponent.text = $"{patient.MedicineCount}种药品需要分配";
                    }
                }

                if (button != null)
                {
                    // All patients in the list need dispensing, so all buttons are enabled
                    button.interactable = true;
                    var id = patient.PatientId;
                    button.onClick.AddListener(() => OnPatientClicked(id));
                }
            }

            UpdateHomeHint(patients);
        }

        private void ClearPatientButtons()
        {
            foreach (var item in spawnedPatientButtons)
            {
                if (item != null)
                {
                    if (Application.isPlaying)
                    {
                        Destroy(item);
                    }
                    else
                    {
                        DestroyImmediate(item);
                    }
                }
            }
            spawnedPatientButtons.Clear();
        }

        private void UpdateHomeHint(List<PatientStatus> patients)
        {
            if (homeHintText == null || patients == null)
            {
                return;
            }

            var remaining = patients.Count;
            homeHintText.text = remaining > 0
                ? "请点击长者卡片，放入药盒并核对处方后开始摆药"
                : "辛苦了，所有患者的药品都已经分完了";
        }

        private async void OnPatientClicked(string patientId)
        {
            if (isStartingPatientFlow)
            {
                return;
            }

            var main = MainController.Instance;
            if (main == null)
            {
                return;
            }

            // Check if dispenser is connected before proceeding
            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser == null || !dispenser.IsConnected)
            {
                EZLog.W(EZLog.Module.UI, "Dispenser not connected, showing prompt");
                if (connectDispenserDialog != null)
                {
                    connectDispenserDialog.SetActive(true);
                }
                return;
            }

            isStartingPatientFlow = true;

            // Disable all patient buttons to prevent double-clicks
            ReEnablePatientButtons(false);

            try
            {
                if (!main.TrySelectPatient(patientId, out var patientStatus))
                {
                    EZLog.W(EZLog.Module.UI, "Failed to select patient");
                    ReEnablePatientButtons(true);
                    isStartingPatientFlow = false;
                    return;
                }

                EZLog.I(EZLog.Module.UI, "Opening tray before scanning...");
                if (homeHintText != null)
                {
                    homeHintText.text = "正在打开药仓，请稍候...";
                }

                var opened = await main.OpenTrayAsync();
                if (!opened)
                {
                    EZLog.E(EZLog.Module.UI, "Failed to open tray.");
                    main.ClearCurrentPatient();
                    if (homeHintText != null)
                    {
                        homeHintText.text = "开仓失败，请检查设备！";
                    }
                    ReEnablePatientButtons(true);
                    isStartingPatientFlow = false;
                    return;
                }

                // Tray opened successfully. Now start scanning in Home scene.
                if (scanner == null)
                {
                    scanner = FindObjectOfType<CheckPillBoxController>();
                    if (scanner == null)
                    {
                        scanner = gameObject.AddComponent<CheckPillBoxController>();
                        EZLog.I(EZLog.Module.UI, "CheckPillBoxController created dynamically on UIManager.");
                    }
                }

                _scanLocked = false;
                isConfirmingDispense = false;
                isCancellingScan = false;

                // Setup and show dedicated Home Scan Dialog
                if (homeScanDialog != null)
                {
                    SetHomeScanDialogTitle("放入药盘");
                    if (homeScanDialogMessageText != null)
                    {
                        homeScanDialogMessageText.text = $"请将【{patientStatus.PatientName}】的药盒放入舱内。";
                    }

                    if (homeScanInsertIcon != null) homeScanInsertIcon.SetActive(true);
                    if (homeScanPrescriptionDetailsText != null) homeScanPrescriptionDetailsText.gameObject.SetActive(false);

                    if (homeScanConfirmButton != null) homeScanConfirmButton.gameObject.SetActive(false);
                    if (homeScanCancelButton != null)
                    {
                        homeScanCancelButton.gameObject.SetActive(true);
                        homeScanCancelButton.interactable = true;
                        homeScanCancelButton.onClick.RemoveAllListeners();
                        homeScanCancelButton.onClick.AddListener(() => FireAndForget(CancelScanAndReturnHomeAsync()));
                    }

                    if (homeScanSwitchCameraButton != null)
                    {
                        homeScanSwitchCameraButton.gameObject.SetActive(true);
                        homeScanSwitchCameraButton.onClick.RemoveAllListeners();
                        homeScanSwitchCameraButton.onClick.AddListener(OnHomeScanSwitchCameraClicked);
                        UpdateHomeScanSwitchCameraButtonText();
                    }

                    homeScanDialog.SetActive(true);
                }

                // Start both channels after the dialog is initialized. Any UID that
                // arrived immediately after opening is retained by the dispenser and
                // consumed by BeginIdentificationSession.
                BeginIdentificationSession(
                    dispenser,
                    patientStatus.PatientId,
                    patientStatus.PatientName,
                    autoMode: false);

                if (homeHintText != null)
                {
                    homeHintText.text = "请放入药盘...";
                }
            }
            catch (Exception ex)
            {
                EZLog.E(EZLog.Module.UI, $"Error during patient clicked workflow: {ex.Message}");
                main.ClearCurrentPatient();
                ReEnablePatientButtons(true);
                isStartingPatientFlow = false;
            }
        }

        private void ReEnablePatientButtons(bool enable)
        {
            foreach (var btnObj in spawnedPatientButtons)
            {
                if (btnObj != null)
                {
                    var btn = btnObj.GetComponent<Button>();
                    if (btn != null) btn.interactable = enable;
                }
            }
            if (refreshButton != null) refreshButton.interactable = enable;
        }

        #endregion

        #region Scan

        private string ResolvePatientIdByRfid(string uid)
        {
            var main = MainController.Instance;
            return main != null && main.TryResolvePatientIdByRfidUid(uid, out var patientId)
                ? patientId
                : null;
        }

        private void BeginIdentificationSession(
            DispenserController dispenser, string expectedPatientId,
            string expectedPatientName, bool autoMode)
        {
            EndIdentificationSession(true);
            if (scanner == null) EnsurePillBoxScanner();
            identificationAutoMode = autoMode;
            pillBoxChecker = new PillBoxUnionChecker(
                removalHoldSeconds: CompletionRfidClearStabilityMilliseconds / 1000.0);
            pillBoxChecker.Register(new RfidPillBoxChannel(dispenser, ResolvePatientIdByRfid));
            pillBoxChecker.Register(new DispenserBarcodePillBoxChannel(dispenser));
            pillBoxChecker.Register(new TabletCameraPillBoxChannel(scanner));
            pillBoxChecker.Verified += OnUnionVerified;
            pillBoxChecker.FeedbackChanged += OnPillBoxFeedbackChanged;
            pillBoxChecker.Diagnostic += LogPillBoxDiagnostic;
            _scanLocked = false;
            pillBoxChecker.StartSession(expectedPatientId, autoMode);
        }

        private void EndIdentificationSession(bool stopScanner)
        {
            var checker = pillBoxChecker;
            pillBoxChecker = null;
            if (checker != null)
            {
                checker.Verified -= OnUnionVerified;
                checker.FeedbackChanged -= OnPillBoxFeedbackChanged;
                checker.Diagnostic -= LogPillBoxDiagnostic;
                checker.EndSession();
            }
            manualRemovalConfirmation?.TrySetResult(false);
            manualRemovalConfirmation = null;
            if (stopScanner) scanner?.StopScanner();
            lastIdentificationResult = null;
            identificationInvalidatedDuringClose = false;
        }

        private void LogPillBoxDiagnostic(PillBoxChannelKind kind, string message)
        {
            EZLog.D(EZLog.Module.Scanner, $"[{kind}] {message}");
        }

        private void OnUnionVerified(string patientId)
        {
            if (completionRemovalMode || isCancellingScan || _scanLocked) return;
            _scanLocked = true;
            var source = pillBoxChecker.Snapshot().Any(x =>
                x.Kind == PillBoxChannelKind.Rfid && x.IsAvailable && x.IsPresent &&
                PillBoxId.SameId(x.ResolvedPatientId, patientId))
                ? PillBoxIdentificationSource.Rfid : PillBoxIdentificationSource.Barcode;
            var result = new PillBoxIdentificationResult(source, patientId, patientId);
            lastIdentificationResult = result;
            FireAndForget(identificationAutoMode
                ? HandleAutoBoxVerifiedAsync(patientId, result)
                : HandleBoxVerifiedAsync(result));
        }

        private void OnPillBoxFeedbackChanged(PillBoxFeedback feedback)
        {
            if (manualRemovalConfirmation != null) return;
            if (feedback == PillBoxFeedback.None) return;
            if (completionRemovalMode)
            {
                SetCompletionDialogMessage(PillBoxFeedbackText.For(feedback));
                return;
            }
            if (feedback != PillBoxFeedback.Ready)
            {
                lastIdentificationResult = null;
                _scanLocked = false;
                if (isConfirmingDispense) identificationInvalidatedDuringClose = true;
                if (homeScanConfirmButton != null) homeScanConfirmButton.gameObject.SetActive(false);
                if (homeScanPrescriptionDetailsText != null) homeScanPrescriptionDetailsText.gameObject.SetActive(false);
                if (correctBoxDialog != null) correctBoxDialog.SetActive(false);
            }
            SetHomeScanDialogTitle(PillBoxFeedbackText.Title(feedback));
            if (homeScanDialogMessageText != null)
                homeScanDialogMessageText.text = PillBoxFeedbackText.For(feedback);
        }

        private async Task<bool> WaitForPillBoxRemovalAsync(bool completion)
        {
            var checker = pillBoxChecker;
            if (checker == null) return false;
            bool removed = await checker.WaitForRemovalAsync(120);
            if (this == null || checker != pillBoxChecker || deviceLostDialogVisible) return false;
            if (removed) return true;
            var button = completion ? completeDialogConfirmButton : (homeScanConfirmButton ?? correctDialogConfirmButton);
            if (button == null) return false;
            var pending = new TaskCompletionSource<bool>();
            manualRemovalConfirmation = pending;
            string message = PillBoxFeedbackText.For(PillBoxFeedback.ConfirmRemovalManually)
                + "。确认完全取出后，请点击“已取出”。";
            if (completion) SetCompletionDialogMessage(message);
            else if (homeScanDialogMessageText != null) homeScanDialogMessageText.text = message;
            if (!completion && homeScanDialog == null && correctBoxDialog != null)
            {
                correctBoxDialog.SetActive(true);
                if (correctBoxDialogText != null) correctBoxDialogText.text = message;
            }
            var textLabel = button.GetComponentInChildren<UnityEngine.UI.Text>(true);
            string oldTextLabel = textLabel != null ? textLabel.text : null;
            if (textLabel != null) textLabel.text = "已取出";
            button.onClick.RemoveAllListeners();
            button.onClick.AddListener(() => pending.TrySetResult(true));
            button.gameObject.SetActive(true);
            button.interactable = true;
            bool confirmed = await pending.Task;
            if (this == null) return false;
            if (manualRemovalConfirmation == pending) manualRemovalConfirmation = null;
            button.onClick.RemoveAllListeners();
            button.gameObject.SetActive(false);
            if (textLabel != null) textLabel.text = oldTextLabel;
            return confirmed && checker == pillBoxChecker && !deviceLostDialogVisible;
        }
        private void ResetIdentificationAfterRemoval()
        {
            lastIdentificationResult = null;
            _scanLocked = false;
            identificationInvalidatedDuringClose = false;
            OnPillBoxFeedbackChanged(PillBoxFeedback.PlaceBox);
        }

        private void InitScan()
        {
            var main = MainController.Instance;
            var patient = main?.GetCurrentPatient();

            if (backToHomeButton != null)
            {
                backToHomeButton.onClick.AddListener(() => FireAndForget(CancelScanAndReturnHomeAsync()));
            }

            BeginIdentificationSession(FindObjectOfType<DispenserController>(), patient?.PatientId ?? "", patient?.PatientName ?? "", false);

            // Setup camera switch button
            if (switchCameraButton != null)
            {
                switchCameraButton.onClick.AddListener(OnSwitchCameraClicked);
                UpdateSwitchCameraButtonText();
            }

            if (lightBar != null)
            {
                lightBarRoutine = StartCoroutine(AnimateLightBar());
            }
        }

        /// <summary>
        /// 点击切换摄像头按钮时调用，切换前置/后置摄像头
        /// </summary>
        private void OnSwitchCameraClicked()
        {
            if (scanner == null) return;

            scanner.SwitchCamera();
            UpdateSwitchCameraButtonText();
            EZLog.D(EZLog.Module.UI, $"Camera switched, isFrontFacing={scanner.IsFrontFacing}");
        }

        /// <summary>
        /// 更新切换摄像头按钮的显示文字
        /// </summary>
        private void UpdateSwitchCameraButtonText()
        {
            if (switchCameraButtonText == null || scanner == null) return;
            switchCameraButtonText.text = scanner.IsFrontFacing ? "切换后置" : "切换前置";
        }

        private IEnumerator AnimateLightBar()
        {
            // Simple loop that moves the bar from top to bottom.
            var rect = lightBar;
            var canvasHeight = rect.parent is RectTransform parent ? parent.rect.height : 400f;
            var halfHeight = rect.rect.height * 0.5f;
            var top = canvasHeight * 0.5f - halfHeight;
            var bottom = -top;

            while (true)
            {
                var pos = rect.anchoredPosition;
                pos.y -= lightBarSpeed * Time.deltaTime;
                if (pos.y < bottom)
                {
                    pos.y = top;
                }
                rect.anchoredPosition = pos;
                yield return null;
            }
        }

        private void OnHomeScanSwitchCameraClicked()
        {
            if (scanner == null) return;
            scanner.SwitchCamera();
            UpdateHomeScanSwitchCameraButtonText();
            EZLog.D(EZLog.Module.UI, $"Home camera switched, isFrontFacing={scanner.IsFrontFacing}");
        }

        private void UpdateHomeScanSwitchCameraButtonText()
        {
            if (homeScanSwitchCameraButtonText == null || scanner == null) return;
            homeScanSwitchCameraButtonText.text = scanner.IsFrontFacing ? "切换后置" : "切换前置";
        }

        private async Task HandleBoxVerifiedAsync(PillBoxIdentificationResult sessionResult = null)
        {
            var main = MainController.Instance;
            string patientName = "";
            string patientId = "";
            string bedNumber = "";
            string medicineInfoText = "无有效分药数据";

            if (main != null)
            {
                var patient = main.GetCurrentPatient();
                if (patient != null)
                {
                    patientName = patient.PatientName;
                    patientId = patient.PatientId;
                    bedNumber = patient.BedNumber;
                }

                // Prepare dispensing plan
                await main.PreparePlanAsync();
                var plan = main.CurrentPlan;
                if (plan != null)
                {
                    var lines = new List<string>();
                    
                    // Format patient header in one line: 患者：张三  病床：02  ID：P0032
                    string bedPart = !string.IsNullOrEmpty(bedNumber) ? $"  病床：{bedNumber}" : "";
                    lines.Add($"患者：{patientName}{bedPart}  ID：{patientId}");

                    // Collect all medicines to find maximum visual width for alignment
                    var allMeds = new List<DispensingMedicine>();
                    if (plan.MedicinesPlate1 != null) allMeds.AddRange(plan.MedicinesPlate1);
                    if (plan.MedicinesPlate2 != null) allMeds.AddRange(plan.MedicinesPlate2);

                    int maxFirstPartWidth = 0;
                    foreach (var m in allMeds)
                    {
                        string firstPart = $"- {m.MedicineName} ({m.DosageSpec})";
                        int w = GetVisualWidth(firstPart);
                        if (w > maxFirstPartWidth) maxFirstPartWidth = w;
                    }

                    // Add medicines list
                    if (plan.MedicinesPlate1 != null && plan.MedicinesPlate1.Count > 0)
                    {
                        lines.Add("\n【餐前/随餐药盘】");
                        foreach (var m in plan.MedicinesPlate1)
                        {
                            string firstPart = $"- {m.MedicineName} ({m.DosageSpec})";
                            string paddedFirstPart = PadRightVisual(firstPart, maxFirstPartWidth + 2);
                            string translatedTiming = TranslateMealTiming(m.MealTiming);
                            lines.Add($"{paddedFirstPart}| 服药时间: {translatedTiming} | 计划天数: {m.DispensingDays}天");
                        }
                    }

                    if (plan.MedicinesPlate2 != null && plan.MedicinesPlate2.Count > 0)
                    {
                        lines.Add("\n【餐后药盘 (药盘2)】");
                        foreach (var m in plan.MedicinesPlate2)
                        {
                            string firstPart = $"- {m.MedicineName} ({m.DosageSpec})";
                            string paddedFirstPart = PadRightVisual(firstPart, maxFirstPartWidth + 2);
                            string translatedTiming = TranslateMealTiming(m.MealTiming);
                            lines.Add($"{paddedFirstPart}| 服药时间: {translatedTiming} | 计划天数: {m.DispensingDays}天");
                        }
                    }

                    if (lines.Count > 0)
                    {
                        medicineInfoText = string.Join("\n", lines);
                    }
                }
            }

            if (!IsIdentificationResultCurrent(sessionResult))
            {
                EZLog.W(EZLog.Module.Scanner, "Identification changed while preparing the dispensing plan");
                return;
            }

            // Show confirmation dialog with patient's medicine details
            if (homeScanDialog != null)
            {
                SetHomeScanDialogTitle("核验成功");
                if (homeScanDialogMessageText != null)
                {
                    homeScanDialogMessageText.text = PillBoxFeedbackText.For(PillBoxFeedback.Ready);
                }

                if (homeScanInsertIcon != null) homeScanInsertIcon.SetActive(false);
                if (homeScanPrescriptionDetailsText != null)
                {
                    homeScanPrescriptionDetailsText.text = medicineInfoText;
                    homeScanPrescriptionDetailsText.gameObject.SetActive(true);
                }

                if (homeScanConfirmButton != null)
                {
                    homeScanConfirmButton.gameObject.SetActive(true);
                    homeScanConfirmButton.interactable = true;
                    homeScanConfirmButton.onClick.RemoveAllListeners();
                    homeScanConfirmButton.onClick.AddListener(() => FireAndForget(ProceedToDispenseAsync()));
                }

                if (homeScanCancelButton != null)
                {
                    homeScanCancelButton.gameObject.SetActive(true);
                    homeScanCancelButton.interactable = true;
                    homeScanCancelButton.onClick.RemoveAllListeners();
                    homeScanCancelButton.onClick.AddListener(() => FireAndForget(CancelScanAndReturnHomeAsync()));
                }
            }
            if (homeScanDialog == null && correctBoxDialog != null)
            {
                correctBoxDialog.SetActive(true);
                if (correctBoxDialogText != null)
                    correctBoxDialogText.text = PillBoxFeedbackText.For(PillBoxFeedback.Ready) + "\n" + medicineInfoText;
                if (correctDialogConfirmButton != null)
                {
                    correctDialogConfirmButton.gameObject.SetActive(true);
                    correctDialogConfirmButton.interactable = true;
                    correctDialogConfirmButton.onClick.RemoveAllListeners();
                    correctDialogConfirmButton.onClick.AddListener(() => FireAndForget(ProceedToDispenseAsync()));
                }
            }
        }

        private static int GetVisualWidth(string s)
        {
            if (string.IsNullOrEmpty(s)) return 0;
            int width = 0;
            foreach (char c in s)
            {
                // Chinese character ranges (Ideographs, symbols, fullwidth punctuation)
                if (c >= 0x4e00 && c <= 0x9fff || c >= 0x3000 && c <= 0x303f || c >= 0xff00 && c <= 0xffef)
                {
                    width += 2;
                }
                else
                {
                    width += 1;
                }
            }
            return width;
        }

        private static string PadRightVisual(string s, int targetWidth)
        {
            int currentWidth = GetVisualWidth(s);
            if (currentWidth >= targetWidth)
            {
                return s;
            }
            return s + new string(' ', targetWidth - currentWidth);
        }

        private static string TranslateMealTiming(string timing)
        {
            if (string.IsNullOrEmpty(timing)) return "";
            
            string t = timing.ToLower().Trim().Replace("_", " ");
            if (t == "before meal") return "餐前";
            if (t == "after meal") return "餐后";
            if (t == "with meal") return "随餐";
            
            if (timing.Contains("前")) return "餐前";
            if (timing.Contains("后")) return "餐后";
            if (timing.Contains("随")) return "随餐";
            
            return timing;
        }

        private async Task ProceedToDispenseAsync()
        {
            if (isConfirmingDispense) return;

            if (!IsIdentificationResultCurrent(lastIdentificationResult)) return;

            identificationInvalidatedDuringClose = false;
            isConfirmingDispense = true;

            var main = MainController.Instance;
            if (main != null)
            {
                // RFID and barcode identify different physical pill-box types.
                // Preserve the verified type across the scene transition so the
                // legacy consumers retain the identification type; removal uses the checker.
                bool usesRfid = lastIdentificationResult?.Source == PillBoxIdentificationSource.Rfid;
                main.SetCurrentPillBoxUsesRfid(usesRfid);
                EZLog.I(EZLog.Module.UI,
                    $"Saved pill-box identification type for dispensing: {(usesRfid ? "RFID" : "Barcode")}");
            }

            if (scanner != null)
            {
                scanner.StopScanner();
            }

            // Show "closing tray..." text on confirm popup and disable buttons
            if (homeScanDialogMessageText != null)
            {
                homeScanDialogMessageText.text = "正在关闭药仓，请稍候...";
            }
            if (homeScanConfirmButton != null) homeScanConfirmButton.interactable = false;
            if (homeScanCancelButton != null) homeScanCancelButton.interactable = false;

            if (main != null)
            {
                // Skip explicit CloseTrayAsync before loading dispense scene — SendPillMatrix will handle tray positioning directly
                EZLog.I(EZLog.Module.UI, "Skipping explicit CloseTray before loading dispense scene (testing direct SendPillMatrix)");

            }

            if (identificationInvalidatedDuringClose)
            {
                isConfirmingDispense = false;
                ResetIdentificationAfterRemoval();
                SetHomeScanDialogTitle("药盒已取出", isError: true);
                if (homeScanDialogMessageText != null)
                {
                    homeScanDialogMessageText.text = "识别信息已失效，请重新放入并识别药盒。";
                }
                return;
            }

            if (homeScanDialog != null)
            {
                homeScanDialog.SetActive(false);
            }

            isConfirmingDispense = false;
            _scanLocked = false;
            EndIdentificationSession(stopScanner: true);

            await LoadSceneAsyncSafe(dispenseSceneName);
        }

        private async Task CancelScanAndReturnHomeAsync()
        {
            if (isCancellingScan) return;
            isCancellingScan = true;

            SetHomeScanDialogTitle("正在退出");
            if (homeScanDialogMessageText != null)
            {
                homeScanDialogMessageText.text = "请取出药盒，系统检测到药盒离开后将自动关闭舱门并返回。";
            }
            if (homeScanConfirmButton != null) homeScanConfirmButton.gameObject.SetActive(false);
            if (homeScanCancelButton != null) homeScanCancelButton.gameObject.SetActive(false);

            if (!await WaitForPillBoxRemovalAsync(false))
            {
                isCancellingScan = false;
                return;
            }
            var main = MainController.Instance;
            if (main == null || !await main.CloseTrayAsync())
            {
                if (this == null) return;
                SetHomeScanDialogTitle("轨道收回失败", isError: true);
                if (homeScanDialogMessageText != null)
                    homeScanDialogMessageText.text = "请检查设备连接后重试。";
                if (homeScanCancelButton != null)
                {
                    homeScanCancelButton.gameObject.SetActive(true);
                    homeScanCancelButton.interactable = true;
                }
                isCancellingScan = false;
                return;
            }
            if (this == null || deviceLostDialogVisible) return;
            if (homeScanDialog != null) homeScanDialog.SetActive(false);
            _scanLocked = false;
            EndIdentificationSession(true);
            main.ClearCurrentPatient();
            isCancellingScan = false;
            await LoadSceneAsyncSafe(homeSceneName);
        }

        private async Task StartAutoRecognitionFlowAsync()
        {
            if (isStartingAutoFlow || isStartingPatientFlow)
            {
                return;
            }

            var main = MainController.Instance;
            if (main == null)
            {
                return;
            }

            // Check if dispenser is connected before proceeding
            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser == null || !dispenser.IsConnected)
            {
                EZLog.W(EZLog.Module.UI, "Dispenser not connected, showing prompt");
                if (connectDispenserDialog != null)
                {
                    connectDispenserDialog.SetActive(true);
                }
                return;
            }

            isStartingAutoFlow = true;

            // Disable card buttons and the auto button
            ReEnablePatientButtons(false);
            if (autoScanButton != null) autoScanButton.interactable = false;

            try
            {
                EZLog.I(EZLog.Module.UI, "Opening tray before auto scan...");
                if (homeHintText != null)
                {
                    homeHintText.text = "正在打开药仓，请稍候...";
                }

                var opened = await main.OpenTrayAsync();
                if (!opened)
                {
                    EZLog.E(EZLog.Module.UI, "Failed to open tray in auto recognition flow.");
                    if (homeHintText != null)
                    {
                        homeHintText.text = "开仓失败，请检查设备！";
                    }
                    ReEnablePatientButtons(true);
                    if (autoScanButton != null) autoScanButton.interactable = true;
                    isStartingAutoFlow = false;
                    return;
                }

                // Tray opened successfully. Setup scanner.
                if (scanner == null)
                {
                    scanner = FindObjectOfType<CheckPillBoxController>();
                    if (scanner == null)
                    {
                        scanner = gameObject.AddComponent<CheckPillBoxController>();
                        EZLog.I(EZLog.Module.UI, "CheckPillBoxController created dynamically on UIManager.");
                    }
                }

                _scanLocked = false;
                isConfirmingDispense = false;
                isCancellingScan = false;

                // Setup and show dedicated Home Scan Dialog
                if (homeScanDialog != null)
                {
                    SetHomeScanDialogTitle("放入药盘");
                    if (homeScanDialogMessageText != null)
                    {
                        homeScanDialogMessageText.text = "请将需要摆药的长者的药盒放入舱内。";
                    }

                    if (homeScanInsertIcon != null) homeScanInsertIcon.SetActive(true);
                    if (homeScanPrescriptionDetailsText != null) homeScanPrescriptionDetailsText.gameObject.SetActive(false);

                    if (homeScanConfirmButton != null) homeScanConfirmButton.gameObject.SetActive(false);
                    if (homeScanCancelButton != null)
                    {
                        homeScanCancelButton.gameObject.SetActive(true);
                        homeScanCancelButton.interactable = true;
                        homeScanCancelButton.onClick.RemoveAllListeners();
                        homeScanCancelButton.onClick.AddListener(() => FireAndForget(CancelScanAndReturnHomeAsync()));
                    }

                    if (homeScanSwitchCameraButton != null)
                    {
                        homeScanSwitchCameraButton.gameObject.SetActive(true);
                        homeScanSwitchCameraButton.onClick.RemoveAllListeners();
                        homeScanSwitchCameraButton.onClick.AddListener(OnHomeScanSwitchCameraClicked);
                        UpdateHomeScanSwitchCameraButtonText();
                    }

                    homeScanDialog.SetActive(true);
                }

                // Initialize the dual-channel session only after the dialog is ready
                // so an already-received UID cannot have its status text overwritten.
                BeginIdentificationSession(dispenser, "", "任意患者", autoMode: true);

                if (homeHintText != null)
                {
                    homeHintText.text = "请放入药盘...";
                }
            }
            catch (Exception ex)
            {
                EZLog.E(EZLog.Module.UI, $"Error during auto recognition workflow: {ex.Message}");
                ReEnablePatientButtons(true);
                if (autoScanButton != null) autoScanButton.interactable = true;
                isStartingAutoFlow = false;
            }
        }

        private async Task HandleAutoBoxVerifiedAsync(
            string code,
            PillBoxIdentificationResult sessionResult = null)
        {
            var main = MainController.Instance;
            if (main == null)
            {
                _scanLocked = false;
                return;
            }

            // 1. Parse patient ID from barcode
            string parsedPatientId = CheckPillBoxController.ParsePatientIdFromBarcode(code);
            EZLog.I(EZLog.Module.UI, $"Auto recognized patient ID: {parsedPatientId}");

            // 2. Lookup patient in local status database
            if (!main.TrySelectPatient(parsedPatientId, out var patientStatus))
            {
                EZLog.W(EZLog.Module.UI, $"Patient ID '{parsedPatientId}' not found in database.");
                SetHomeScanDialogTitle("请放入需要封药的患者的药盒", isError: true);
                if (homeScanDialogMessageText != null)
                {
                    homeScanDialogMessageText.text = "当前药盒无效或者所属患者今天无需分药，请重新放入药盒。";
                }
                
                await Task.Delay(2000);
                if (!IsIdentificationResultCurrent(sessionResult)) return;
                ResumeAutoIdentificationAfterError();
                return;
            }

            // 3. Check today's tasks
            if (patientStatus.MedicineCount == 0)
            {
                EZLog.W(EZLog.Module.UI, $"Patient '{patientStatus.PatientName}' has no dispensing task today.");
                SetHomeScanDialogTitle("请放入需要封药的患者的药盒", isError: true);
                if (homeScanDialogMessageText != null)
                {
                    homeScanDialogMessageText.text = "当前药盒无效或者所属患者今天无需分药，请重新放入药盒。";
                }
                main.ClearCurrentPatient(); // clear selection since we cannot dispense
                
                await Task.Delay(2000);
                if (!IsIdentificationResultCurrent(sessionResult)) return;
                ResumeAutoIdentificationAfterError();
                return;
            }

            if (patientStatus.IsCompleted)
            {
                EZLog.W(EZLog.Module.UI, $"Patient '{patientStatus.PatientName}' task today is already completed.");
                SetHomeScanDialogTitle("请放入需要封药的患者的药盒", isError: true);
                if (homeScanDialogMessageText != null)
                {
                    homeScanDialogMessageText.text = "当前药盒无效或者所属患者今天无需分药，请重新放入药盒。";
                }
                main.ClearCurrentPatient();
                
                await Task.Delay(2000);
                if (!IsIdentificationResultCurrent(sessionResult)) return;
                ResumeAutoIdentificationAfterError();
                return;
            }

            // 4. Valid patient and task today. Prepare plan.
            string patientName = patientStatus.PatientName;
            string patientId = patientStatus.PatientId;
            string bedNumber = patientStatus.BedNumber;
            string medicineInfoText = "无有效分药数据";

            await main.PreparePlanAsync();
            var plan = main.CurrentPlan;
            if (plan != null)
            {
                var lines = new List<string>();
                
                // Format patient header in one line: 患者：张三  病床：02  ID：P0032
                string bedPart = !string.IsNullOrEmpty(bedNumber) ? $"  病床：{bedNumber}" : "";
                lines.Add($"患者：{patientName}{bedPart}  ID：{patientId}");

                // Collect all medicines to find maximum visual width for alignment
                var allMeds = new List<DispensingMedicine>();
                if (plan.MedicinesPlate1 != null) allMeds.AddRange(plan.MedicinesPlate1);
                if (plan.MedicinesPlate2 != null) allMeds.AddRange(plan.MedicinesPlate2);

                int maxFirstPartWidth = 0;
                foreach (var m in allMeds)
                {
                    string firstPart = $"- {m.MedicineName} ({m.DosageSpec})";
                    int w = GetVisualWidth(firstPart);
                    if (w > maxFirstPartWidth) maxFirstPartWidth = w;
                }

                // Add medicines list
                if (plan.MedicinesPlate1 != null && plan.MedicinesPlate1.Count > 0)
                {
                    lines.Add("\n【餐前/随餐药盘】");
                    foreach (var m in plan.MedicinesPlate1)
                    {
                        string firstPart = $"- {m.MedicineName} ({m.DosageSpec})";
                        string paddedFirstPart = PadRightVisual(firstPart, maxFirstPartWidth + 2);
                        string translatedTiming = TranslateMealTiming(m.MealTiming);
                        lines.Add($"{paddedFirstPart}| 服药时间: {translatedTiming} | 计划天数: {m.DispensingDays}天");
                    }
                }

                if (plan.MedicinesPlate2 != null && plan.MedicinesPlate2.Count > 0)
                {
                    lines.Add("\n【餐后药盘 (药盘2)】");
                    foreach (var m in plan.MedicinesPlate2)
                    {
                        string firstPart = $"- {m.MedicineName} ({m.DosageSpec})";
                        string paddedFirstPart = PadRightVisual(firstPart, maxFirstPartWidth + 2);
                        string translatedTiming = TranslateMealTiming(m.MealTiming);
                        lines.Add($"{paddedFirstPart}| 服药时间: {translatedTiming} | 计划天数: {m.DispensingDays}天");
                    }
                }

                if (lines.Count > 0)
                {
                    medicineInfoText = string.Join("\n", lines);
                }
            }

            if (!IsIdentificationResultCurrent(sessionResult))
            {
                EZLog.W(EZLog.Module.Scanner, "Auto identification changed while preparing the dispensing plan");
                return;
            }

            // Show confirmation dialog with patient's medicine details
            if (homeScanDialog != null)
            {
                SetHomeScanDialogTitle("核验成功");
                if (homeScanDialogMessageText != null)
                {
                    homeScanDialogMessageText.text = PillBoxFeedbackText.For(PillBoxFeedback.Ready);
                }

                if (homeScanInsertIcon != null) homeScanInsertIcon.SetActive(false);
                if (homeScanPrescriptionDetailsText != null)
                {
                    homeScanPrescriptionDetailsText.text = medicineInfoText;
                    homeScanPrescriptionDetailsText.gameObject.SetActive(true);
                }

                if (homeScanConfirmButton != null)
                {
                    homeScanConfirmButton.gameObject.SetActive(true);
                    homeScanConfirmButton.interactable = true;
                    homeScanConfirmButton.onClick.RemoveAllListeners();
                    homeScanConfirmButton.onClick.AddListener(() => FireAndForget(ProceedToDispenseAsync()));
                }

                if (homeScanCancelButton != null)
                {
                    homeScanCancelButton.gameObject.SetActive(true);
                    homeScanCancelButton.interactable = true;
                    homeScanCancelButton.onClick.RemoveAllListeners();
                    homeScanCancelButton.onClick.AddListener(() => FireAndForget(CancelScanAndReturnHomeAsync()));
                }
            }
        }

        private bool IsIdentificationResultCurrent(PillBoxIdentificationResult sessionResult)
        {
            return sessionResult != null && lastIdentificationResult == sessionResult &&
                pillBoxChecker != null && pillBoxChecker.Phase == PillBoxPhase.Ready &&
                PillBoxId.SameId(pillBoxChecker.VerifiedPatientId, sessionResult.PatientId);
        }

        private void ResumeAutoIdentificationAfterError()
        {
            lastIdentificationResult = null;
            _scanLocked = false;
            SetHomeScanDialogTitle("请更换药盒");
            if (homeScanConfirmButton != null) homeScanConfirmButton.gameObject.SetActive(false);
            if (homeScanDialogMessageText != null)
                homeScanDialogMessageText.text = "请取出当前药盒，再放入需要摆药的长者的药盒。";
        }

        #endregion

        #region Dispense

        private void InitDispense()
        {
            var main = MainController.Instance;
            if (main != null)
            {
                main.DispensingProgressChanged += UpdateDispenseUI;
                main.DispensingError += ShowDispenseError;
                main.DispensingCompleted += OnDispenseCompleted;
                main.ServoAngleChanged += OnServoAngleChangedBySystem;
                main.PlateSwitchRequired += OnPlateSwitchRequired;
                main.MedicineSkipped += OnMedicineSkipped;
                main.MotorStallChanged += OnMotorStallChanged;
            }

            if (clearMotorStallButton != null)
                clearMotorStallButton.onClick.AddListener(OnClearMotorStallClicked);
            OnMotorStallChanged(main != null && main.IsMotorStalled);

            if (captureBackgroundButton != null && pillCounterController != null)
            {
                captureBackgroundButton.onClick.AddListener(() => pillCounterController.CaptureBackground());
            }
            
            // Setup skip button to skip current medicine when clicked
            if (skipMedicineButton != null)
            {
                skipMedicineButton.onClick.AddListener(OnSkipMedicineClicked);
            }

            // Setup pause/resume button
            if (pauseResumeButton != null)
            {
                pauseResumeButton.onClick.AddListener(OnPauseResumeClicked);
            }

            // Subscribe to pause state changes from dispenser
            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser != null)
            {
                dispenser.OnPauseStateChanged += UpdatePauseButtonUI;
                // Initialize button text to current state
                UpdatePauseButtonUI(dispenser.IsPaused);
            }

            // Setup next medicine text reminder in TopBar
            if (nextMedicineText == null)
            {
                var topBar = GameObject.Find("TopBar");
                if (topBar != null)
                {
                    var texts = topBar.GetComponentsInChildren<Text>(true);
                    nextMedicineText = texts.FirstOrDefault(t => t.gameObject.name == "NextMedicineText" || t.gameObject.name.Contains("TipsText"));
                }
            }

            if (nextMedicineText != null)
            {
                nextMedicineText.gameObject.SetActive(true);
            }

            if (main != null)
            {
                main.SkipConfirmRequired += OnSkipConfirmRequired;
                FireAndForget(main.StartDispensingAsync());
            }

            // Setup skip confirm dialog button
            if (skipConfirmButton != null)
            {
                skipConfirmButton.onClick.AddListener(OnSkipConfirmClicked);
            }

            if (skipCleanTurntableButton != null)
            {
                skipCleanTurntableButton.onClick.AddListener(() => FireAndForget(CleanTurntableAsync(skipCleanTurntableButton)));
            }

            // Hide skip dialog initially
            if (skipConfirmDialog != null)
            {
                skipConfirmDialog.SetActive(false);
            }

            // Setup manual servo angle tuning slider
            if (servoAngleTuningSlider != null)
            {
                servoAngleTuningSlider.minValue = 0.0f;
                servoAngleTuningSlider.maxValue = 1.0f;
                servoAngleTuningSlider.value = 0.5f;
                servoAngleTuningSlider.onValueChanged.AddListener(OnServoAngleTuningChanged);
                OnServoAngleTuningChanged(servoAngleTuningSlider.value);
                var sliderNavigation = servoAngleTuningSlider.navigation;
                sliderNavigation.mode = Navigation.Mode.None;
                servoAngleTuningSlider.navigation = sliderNavigation;

                var trigger = servoAngleTuningSlider.gameObject.GetComponent<EventTrigger>() ?? 
                              servoAngleTuningSlider.gameObject.AddComponent<EventTrigger>();
                
                var entry = new EventTrigger.Entry { eventID = EventTriggerType.PointerUp };
                entry.callback.AddListener((data) => { OnServoAngleTuningReleased(); });
                trigger.triggers.Add(entry);
            }
        }
        
        /// <summary>
        /// Called when the servo angle slider is dragged (updates UI text only)
        /// </summary>
        private void OnServoAngleTuningChanged(float servoAngle)
        {
            if (servoAngleTuningText != null)
            {
                servoAngleTuningText.text = $"舵机：{servoAngle:F2}";
            }
        }

        /// <summary>
        /// Called when the user releases the slider pointer, sending command to STM32.
        /// </summary>
        private void OnServoAngleTuningReleased()
        {
            if (servoAngleTuningSlider == null) return;

            float servoAngle = servoAngleTuningSlider.value;
            FireAndForget(ApplyServoAngleTuningAsync(servoAngle));
        }

        private void OnMotorStallChanged(bool stalled)
        {
            if (stalledDialog == null) return;
            stalledDialog.SetActive(stalled);
            if (!stalled) return;
            ResetServoKeyboardTuningState();
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
            stalledDialog.transform.SetAsLastSibling();
            int motorId = MainController.Instance.CurrentStalledMotor;
            if (stalledTitleText != null) stalledTitleText.text = $"{motorId} 号电机堵转";
            if (stalledMessageText != null)
                stalledMessageText.text = $"请清理 {motorId} 号电机卡住的异物，清理完成后点击解除堵转。";
            if (clearMotorStallButton != null)
                clearMotorStallButton.interactable = !isClearingMotorStall;
        }

        private void OnClearMotorStallClicked()
        {
            if (!isClearingMotorStall) FireAndForget(ClearMotorStallFromDialogAsync());
        }

        private async Task ClearMotorStallFromDialogAsync()
        {
            var main = MainController.Instance;
            if (main == null || !main.IsMotorStalled) return;
            isClearingMotorStall = true;
            if (clearMotorStallButton != null) clearMotorStallButton.interactable = false;
            if (stalledMessageText != null) stalledMessageText.text = $"正在发送 {main.CurrentStalledMotor} 号电机解除堵转指令…";
            try
            {
                bool acknowledged = await main.ClearMotorStallAsync();
                if (this != null && !acknowledged && main.IsMotorStalled && stalledMessageText != null)
                    stalledMessageText.text = $"未确认 {main.CurrentStalledMotor} 号电机解除指令或再次收到堵转，请检查设备状态后再操作。";
            }
            finally
            {
                isClearingMotorStall = false;
                if (this != null && clearMotorStallButton != null) clearMotorStallButton.interactable = true;
            }
        }

        private async Task ApplyServoAngleTuningAsync(float servoAngle)
        {
            var dispenser = FindObjectOfType<DispenserController>();
            
            if (dispenser != null && dispenser.IsConnected)
            {
                EZLog.I(EZLog.Module.UI, $"Manual servo tuning released: servo={servoAngle:F2}");

                var main = MainController.Instance;
                int servoSession = main != null ? main.ActiveServoTuningSession : -1;
                var servoTcs = new TaskCompletionSource<bool>();
                dispenser.SetServoAngle(servoAngle, success => 
                { 
                    if (success && main != null)
                    {
                        main.RecordManualServoAngle(servoAngle, servoSession);
                    }
                    servoTcs.TrySetResult(success); 
                });
                await servoTcs.Task;
            }
        }

        /// <summary>
        /// Called when skip button is clicked - skips current medicine
        /// </summary>
        private void OnSkipMedicineClicked()
        {
            var main = MainController.Instance;
            if (main != null)
            {
                EZLog.D(EZLog.Module.UI, "Skip button clicked");
                main.SkipCurrentMedicine();
            }
        }
        
        /// <summary>
        /// Called when a medicine is skipped - shows feedback to user
        /// </summary>
        private void OnMedicineSkipped(string medicineName)
        {
            EZLog.D(EZLog.Module.UI, $"Medicine skipped: {medicineName}");
        }

        /// <summary>
        /// Called when skip command sent — show confirmation dialog
        /// </summary>
        private void OnSkipConfirmRequired(string medicineName)
        {
            EZLog.D(EZLog.Module.UI, $"Showing skip confirm dialog for: {medicineName}");
            
            if (skipMedicineNameText != null)
            {
                skipMedicineNameText.text = $"已跳过药物：{medicineName}";
            }
            
            // Reset toggle to unchecked (default: don't mark as dispensed)
            if (skipMarkDispensedToggle != null)
            {
                skipMarkDispensedToggle.isOn = false;
            }
            
            if (skipConfirmDialog != null)
            {
                skipConfirmDialog.SetActive(true);
            }
        }

        /// <summary>
        /// Called when user clicks confirm in skip dialog
        /// </summary>
        private void OnSkipConfirmClicked()
        {
            bool markAsDispensed = skipMarkDispensedToggle != null && skipMarkDispensedToggle.isOn;
            
            EZLog.D(EZLog.Module.UI, $"Skip confirmed, markAsDispensed={markAsDispensed}");
            
            if (skipConfirmDialog != null)
            {
                skipConfirmDialog.SetActive(false);
            }
            
            var main = MainController.Instance;
            main?.ConfirmSkipReady(markAsDispensed);
        }

        /// <summary>
        /// Called when pause/resume button is clicked - toggles dispensing pause state
        /// </summary>
        private void OnPauseResumeClicked()
        {
            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser == null) return;

            if (dispenser.IsPaused)
            {
                EZLog.D(EZLog.Module.UI, "Resume button clicked");
                dispenser.ResumeDispensing();
            }
            else
            {
                EZLog.D(EZLog.Module.UI, "Pause button clicked");
                dispenser.PauseDispenser();
            }
        }

        /// <summary>
        /// Updates pause button UI based on current pause state
        /// </summary>
        private void UpdatePauseButtonUI(bool isPaused)
        {
            if (pauseResumeButtonText != null)
            {
                pauseResumeButtonText.text = isPaused ? "继续" : "暂停";
            }
        }

        private void UpdateDispenseUI(DispensingProgressInfo info)
        {
            if (info == null)
            {
                return;
            }

            if (totalPillsText != null)
            {
                int remainingPills = Mathf.Max(0, info.TotalPills - info.DispensedPills);
                totalPillsText.text = $"{remainingPills}";
            }

            if (medicineNameText != null)
            {
                medicineNameText.text = $"{info.MedicineName}  {info.TotalPills}粒";
            }

            if (patientNameText != null)
            {
                patientNameText.text = string.IsNullOrEmpty(info.PatientName)
                    ? string.Empty
                    : $"所属患者： {info.PatientName}";
            }

            if (dosageSpecText != null)
            {
                dosageSpecText.text = string.IsNullOrEmpty(info.DosageSpec)
                    ? string.Empty
                    : $"剂量规格： {info.DosageSpec}";
            }

            if (progressPercentText != null)
            {
                var clampedProgress = Mathf.Clamp01(info.Progress);
                var percent = Mathf.RoundToInt(clampedProgress * 100f);
                progressPercentText.text = $"{percent}%";
            }

            // Update progress bar with smooth animation
            if (progressFillImage != null)
            {
                targetProgressValue = info.Progress;
                if (progressAnimRoutine == null)
                {
                    progressAnimRoutine = StartCoroutine(AnimateProgressBar());
                }
            }
            
            // Load and display drug image if available and different from current
            EZLog.V(EZLog.Module.UI, $"UpdateDispenseUI - drugImage={drugImage != null}, ImageResourceId='{info.ImageResourceId}', currentId='{currentDrugImageId}'");
            if (drugImage != null && !string.IsNullOrEmpty(info.ImageResourceId))
            {
                if (currentDrugImageId != info.ImageResourceId)
                {
                    EZLog.D(EZLog.Module.UI, $"Loading new drug image: {info.ImageResourceId}");
                    currentDrugImageId = info.ImageResourceId;
                    LoadDrugImageAsync(info.ImageResourceId);
                }
            }
            else if (drugImage == null)
            {
                EZLog.W(EZLog.Module.UI, "drugImage field is not assigned in Inspector");
            }
            
            // Update next medicine preview info
            UpdateNextMedicinePreview(info);
            
        }
        
        /// <summary>
        /// Updates the next medicine preview text with info about the upcoming medicine
        /// </summary>
        private void UpdateNextMedicinePreview(DispensingProgressInfo info)
        {
            if (nextMedicineText == null) return;

            if (!nextMedicineText.gameObject.activeSelf)
            {
                nextMedicineText.gameObject.SetActive(true);
            }
            
            if (!string.IsNullOrEmpty(info.NextMedicineName))
            {
                nextMedicineText.text = $"下一药物：{info.NextMedicineName}，共 {info.NextMedicinePillCount} 粒";
            }
            else
            {
                nextMedicineText.text = "下一药物：无";
            }
        }
        
        // Currently loaded drug image ID to avoid reloading same image
        private string currentDrugImageId;
        
        /// <summary>
        /// Load and display drug image from server
        /// </summary>
        private async void LoadDrugImageAsync(string imageResourceId)
        {
            if (drugImage == null || string.IsNullOrEmpty(imageResourceId))
            {
                return;
            }
            
            var serverUrl = AppConfig.Instance?.ServerUrl;
            if (string.IsNullOrEmpty(serverUrl))
            {
                EZLog.W(EZLog.Module.UI, "Cannot load drug image - server URL not configured");
                return;
            }
            
            var texture = await EZDose.UI.PillImageLoader.LoadImageAsync(serverUrl, imageResourceId);
            if (texture != null)
            {
                // Check if this is still the image we want to display
                if (currentDrugImageId == imageResourceId)
                {
                    // Convert Texture2D to Sprite for Image component
                    var sprite = Sprite.Create(
                        texture, 
                        new UnityEngine.Rect(0, 0, texture.width, texture.height), 
                        new Vector2(0.5f, 0.5f));
                    drugImage.sprite = sprite;
                    EZLog.D(EZLog.Module.UI, $"Displayed drug image: {imageResourceId}");
                }
                else
                {
                    // Image changed while loading, destroy this texture
                    Destroy(texture);
                }
            }
        }

        /// <summary>
        /// Smoothly animates the progress bar towards the target value.
        /// </summary>
        private IEnumerator AnimateProgressBar()
        {
            const float smoothSpeed = 5f; // Adjust for faster/slower animation
            
            while (progressFillImage != null)
            {
                float current = progressFillImage.fillAmount;
                float target = targetProgressValue;
                
                // If close enough to target, snap to it
                if (Mathf.Abs(target - current) < 0.001f)
                {
                    progressFillImage.fillAmount = target;
                    yield return null;
                    continue;
                }
                
                // Smoothly interpolate towards target
                progressFillImage.fillAmount = Mathf.Lerp(current, target, Time.deltaTime * smoothSpeed);
                yield return null;
            }
            
            progressAnimRoutine = null;
        }

        private void OnPlateSwitchRequired(int plateNumber)
        {
            var main = MainController.Instance;
            string patientName = "";
            if (main != null && main.GetCurrentPatient() != null)
            {
                patientName = main.GetCurrentPatient().PatientName;
            }

            string plateName = plateNumber == 1 ? "饭前药盒" : "饭后/随餐药盒";

            var targetText = plateSwitchDialogText ?? FindDialogMessageText(plateSwitchDialog, "Message");
            if (targetText != null)
            {
                targetText.text = $"请放入【{patientName}】的【{plateName}】。";
            }

            if (plateSwitchDialog != null)
            {
                plateSwitchDialog.SetActive(true);
            }

            if (plateSwitchConfirmButton != null)
            {
                plateSwitchConfirmButton.onClick.RemoveAllListeners();
                plateSwitchConfirmButton.onClick.AddListener(() =>
                {
                    main?.ConfirmPlateReady();
                    if (plateSwitchDialog != null)
                    {
                        plateSwitchDialog.SetActive(false);
                    }
                });
            }
        }

        private void OnDispenseCompleted()
        {
            FireAndForget(ShowCompletionAsync());
        }

        private void OnServoAngleChangedBySystem(float angle)
        {
            if (servoAngleTuningSlider != null)
            {
                servoAngleTuningSlider.value = angle;
            }
        }

        private void SetCompletionDialogMessage(string message)
        {
            if (completeDialogMessageText == null && completeDialog != null)
            {
                completeDialogMessageText = completeDialog
                    .GetComponentsInChildren<Text>(true)
                    .FirstOrDefault(text => text != null &&
                                            !string.IsNullOrEmpty(text.text) &&
                                            text.text.Contains("取出药盒"));
            }

            if (completeDialogMessageText != null)
            {
                completeDialogMessageText.text = message;
            }
        }

        private void EndCompletionMonitoring()
        {
            EndIdentificationSession(true);
            completionMonitoringSession++;
        }

        private CheckPillBoxController EnsurePillBoxScanner()
        {
            if (scanner == null)
            {
                scanner = FindObjectOfType<CheckPillBoxController>();
            }

            if (scanner == null)
            {
                scanner = gameObject.AddComponent<CheckPillBoxController>();
                EZLog.I(EZLog.Module.UI, "Created barcode scanner for completion tray monitoring");
            }

            return scanner;
        }

        private void EnableCompletionRetryButton(bool reopenTray = false)
        {
            if (completeDialogConfirmButton == null)
            {
                return;
            }

            completeDialogConfirmButton.gameObject.SetActive(true);
            completeDialogConfirmButton.interactable = true;
            completeDialogConfirmButton.onClick.RemoveAllListeners();
            completeDialogConfirmButton.onClick.AddListener(() =>
                FireAndForget(reopenTray ? ShowCompletionAsync() : ReturnHomeAsync()));
        }

        private async Task ShowCompletionAsync()
        {
            // A duplicate completion notification must not replace the monitor that
            // ReturnHomeAsync is already awaiting, or both flows could stop waiting.
            if (isShowingCompletion || isReturningHomeAfterCompletion || deviceLostDialogVisible)
            {
                return;
            }

            isShowingCompletion = true;
            try
            {
                await ShowCompletionCoreAsync();
            }
            finally
            {
                isShowingCompletion = false;
            }
        }

        private async Task ShowCompletionCoreAsync()
        {
            var main = MainController.Instance;
            var dispenser = FindObjectOfType<DispenserController>();
            EndCompletionMonitoring();
            int session = completionMonitoringSession;
            completionRemovalMode = true;
            pillCounterController?.StopCamera();
            await Task.Delay(250);
            if (this == null || session != completionMonitoringSession || deviceLostDialogVisible) return;
            EnsurePillBoxScanner();
            BeginIdentificationSession(dispenser, "", "", true);
            if (main != null)
            {
                // StartDispensingAsync normally opens the tray before publishing the
                // completion event. Reopening here would erase early RFID removal
                // reports from that opening, so both sources reuse the open tray.
                bool trayAlreadyOpen = dispenser != null && dispenser.IsTrayOpened;
                if (!trayAlreadyOpen)
                {
                    var opened = await main.OpenTrayAsync();
                    if (session != completionMonitoringSession || deviceLostDialogVisible) return;
                    if (!opened)
                    {
                        EZLog.E(EZLog.Module.UI, "Unable to open tray for pill-box removal");
                        EndCompletionMonitoring();
                        SetCompletionDialogMessage("轨道打开失败，请检查设备连接后重试");
                        if (completeDialog != null) completeDialog.SetActive(true);
                        EnableCompletionRetryButton(reopenTray: true);
                        return;
                    }
                }
                else
                {
                    EZLog.I(EZLog.Module.UI, "Tray is already open; skipping duplicate OPEN_TRAY command");
                }
            }

            SetCompletionDialogMessage(PillBoxFeedbackText.For(PillBoxFeedback.RemoveBox));
            if (completeDialog != null)
            {
                completeDialog.SetActive(true);
            }

            if (completeDialogConfirmButton != null)
            {
                completeDialogConfirmButton.onClick.RemoveAllListeners();
                completeDialogConfirmButton.gameObject.SetActive(false);
                completeDialogConfirmButton.interactable = false;
            }

            // Both identification sources start removal detection automatically.
            await ReturnHomeAsync();
        }

        private async Task ReturnHomeAsync()
        {
            if (isReturningHomeAfterCompletion)
            {
                return;
            }

            isReturningHomeAfterCompletion = true;
            if (completeDialogConfirmButton != null)
            {
                completeDialogConfirmButton.interactable = false;
            }

            try
            {
                var main = MainController.Instance;
                int session = completionMonitoringSession;
                if (!await WaitForPillBoxRemovalAsync(true)) return;
                if (session != completionMonitoringSession || deviceLostDialogVisible) return;
                SetCompletionDialogMessage("正在收回轨道...");
                if (main != null)
                {
                    EZLog.I(EZLog.Module.UI, "Pill box removed; sending CLOSE_TRAY");
                    var closed = await main.CloseTrayAsync();
                    if (session != completionMonitoringSession || deviceLostDialogVisible) return;
                    if (!closed)
                    {
                        EZLog.E(EZLog.Module.UI, "CLOSE_TRAY failed after pill-box removal");
                        SetCompletionDialogMessage("轨道收回失败，请检查设备后重新确认");
                        EnableCompletionRetryButton();
                        return;
                    }
                    EZLog.I(EZLog.Module.UI, "CLOSE_TRAY succeeded after pill-box removal");
                }
                else
                {
                    EZLog.E(EZLog.Module.UI,
                        "MainController unavailable; cannot close tray after pill-box removal");
                    SetCompletionDialogMessage("无法连接主控制流程，轨道保持打开，请重启应用后检查设备");
                    EnableCompletionRetryButton();
                    return;
                }

                EndCompletionMonitoring();
                await LoadSceneAsyncSafe(homeSceneName);
            }
            finally
            {
                isReturningHomeAfterCompletion = false;
                if (!deviceLostDialogVisible && completeDialogConfirmButton != null)
                {
                    completeDialogConfirmButton.interactable = true;
                }
            }
        }

        private void ShowDispenseError(string message)
        {
            EZLog.W(EZLog.Module.UI, $"Dispense error: {message}");
            // For now, we show the same completion dialog style with the error message logged.
            if (completeDialog != null)
            {
                completeDialog.SetActive(true);
            }
        }

        #endregion

        #region Helpers

        private bool HandleGlobalDialogShortcuts()
        {
            if (IsActive(deviceLostDialog))
            {
                ShortcutInput.InvokeButtonIfKeyDown(deviceLostConfirmButton, KeyCode.Return, KeyCode.KeypadEnter);
                return true;
            }

            if (IsActive(stalledDialog)) return true;

            return false;
        }

        private void HandleHomeShortcuts()
        {
            if (deviceManagerUI != null && deviceManagerUI.IsDialogVisible())
            {
                return;
            }

            // Treat the pill-box identification dialog as modal. Enter should only
            // confirm after verification has made the existing confirm button usable,
            // and Home-page shortcuts must not fire behind the dialog.
            if (IsActive(homeScanDialog))
            {
                ShortcutInput.InvokeButtonIfKeyDown(
                    homeScanConfirmButton,
                    KeyCode.Return,
                    KeyCode.KeypadEnter);
                return;
            }

            if (ShortcutInput.GetAnyKeyDown(KeyCode.Space))
            {
                if (!isStartingPatientFlow && !isStartingAutoFlow)
                {
                    FireAndForget(StartAutoRecognitionFlowAsync());
                    return;
                }
            }

            if (ShortcutInput.InvokeButtonIfKeyDown(refreshButton, KeyCode.R))
            {
                return;
            }

            if (ShortcutInput.InvokeButtonIfKeyDown(manageDevicesButton, KeyCode.D))
            {
                return;
            }

            if (ShortcutInput.InvokeButtonIfKeyDown(cleanTurntableButton, KeyCode.C))
            {
                return;
            }

            if (ShortcutInput.GetAnyKeyDown(KeyCode.Alpha1, KeyCode.Keypad1))
            {
                ShowSubPage(HomeSubPage.PatientCard);
                return;
            }

            if (ShortcutInput.GetAnyKeyDown(KeyCode.Alpha2, KeyCode.Keypad2))
            {
                ShowSubPage(HomeSubPage.Setting);
            }
        }

        private void HandleScanShortcuts()
        {
            if (IsActive(correctBoxDialog))
            {
                ShortcutInput.InvokeButtonIfKeyDown(correctDialogConfirmButton, KeyCode.Return, KeyCode.KeypadEnter);
                return;
            }

            if (IsActive(mismatchDialog))
            {
                ShortcutInput.InvokeButtonIfKeyDown(mismatchRetryButton, KeyCode.Return, KeyCode.KeypadEnter);
                return;
            }

            if (ShortcutInput.InvokeButtonIfKeyDown(backToHomeButton, KeyCode.Escape))
            {
                return;
            }

            ShortcutInput.InvokeButtonIfKeyDown(switchCameraButton, KeyCode.LeftShift, KeyCode.RightShift);
        }

        private void HandleDispenseShortcuts()
        {
            if (IsActive(skipConfirmDialog))
            {
                if (ShortcutInput.InvokeButtonIfKeyDown(skipConfirmButton, KeyCode.Return, KeyCode.KeypadEnter))
                {
                    return;
                }

                ShortcutInput.InvokeButtonIfKeyDown(skipCleanTurntableButton, KeyCode.C);
                return;
            }

            if (IsActive(plateSwitchDialog))
            {
                ShortcutInput.InvokeButtonIfKeyDown(plateSwitchConfirmButton, KeyCode.Return, KeyCode.KeypadEnter);
                return;
            }

            if (IsActive(completeDialog))
            {
                ShortcutInput.InvokeButtonIfKeyDown(completeDialogConfirmButton, KeyCode.Return, KeyCode.KeypadEnter);
                return;
            }

            if (HandleServoKeyboardTuning())
            {
                return;
            }

            if (ShortcutInput.InvokeButtonIfKeyDown(pauseResumeButton, KeyCode.Space))
            {
                return;
            }

            ShortcutInput.InvokeButtonIfKeyDown(skipMedicineButton, KeyCode.P);
        }

        private bool HandleServoKeyboardTuning()
        {
            bool leftHeld = Input.GetKey(KeyCode.LeftArrow);
            bool rightHeld = Input.GetKey(KeyCode.RightArrow);
            bool leftPressed = Input.GetKeyDown(KeyCode.LeftArrow);
            bool rightPressed = Input.GetKeyDown(KeyCode.RightArrow);
            bool released = Input.GetKeyUp(KeyCode.LeftArrow) || Input.GetKeyUp(KeyCode.RightArrow);

            if (!leftHeld && !rightHeld)
            {
                if (released && isServoKeyboardTuning)
                {
                    CommitServoKeyboardTuning();
                    return true;
                }

                isServoKeyboardTuning = false;
                servoKeyboardValueChanged = false;
                return released;
            }

            if (!CanUseServoKeyboardTuning())
            {
                ResetServoKeyboardTuningState();
                return leftPressed || rightPressed || released;
            }

            if (!isServoKeyboardTuning)
            {
                isServoKeyboardTuning = true;
                servoKeyboardValueChanged = false;
                nextServoKeyboardStepTime = 0f;
            }

            bool shouldStep = leftPressed || rightPressed || Time.unscaledTime >= nextServoKeyboardStepTime;
            if (!shouldStep)
            {
                return true;
            }

            int direction = 0;
            if (rightHeld && !leftHeld)
            {
                direction = -1;
            }
            else if (leftHeld && !rightHeld)
            {
                direction = 1;
            }

            if (direction != 0 && ApplyServoKeyboardStep(direction))
            {
                servoKeyboardValueChanged = true;
            }

            nextServoKeyboardStepTime = Time.unscaledTime + Mathf.Max(0.01f, servoKeyboardRepeatInterval);
            return true;
        }

        private bool ApplyServoKeyboardStep(int direction)
        {
            if (!CanUseServoKeyboardTuning())
            {
                return false;
            }

            float currentValue = servoAngleTuningSlider.value;
            float nextValue = Mathf.Clamp(
                currentValue + direction * Mathf.Abs(servoKeyboardStep),
                servoAngleTuningSlider.minValue,
                servoAngleTuningSlider.maxValue);

            if (Mathf.Approximately(currentValue, nextValue))
            {
                return false;
            }

            servoAngleTuningSlider.value = nextValue;
            return true;
        }

        private void CommitServoKeyboardTuning()
        {
            if (servoKeyboardValueChanged)
            {
                OnServoAngleTuningReleased();
            }

            ResetServoKeyboardTuningState();
        }

        private void ResetServoKeyboardTuningState()
        {
            isServoKeyboardTuning = false;
            servoKeyboardValueChanged = false;
            nextServoKeyboardStepTime = 0f;
        }

        private bool CanUseServoKeyboardTuning()
        {
            return servoAngleTuningSlider != null &&
                   servoAngleTuningSlider.isActiveAndEnabled &&
                   servoAngleTuningSlider.gameObject.activeInHierarchy &&
                   servoAngleTuningSlider.interactable;
        }

        private static bool IsActive(GameObject target)
        {
            return target != null && target.activeInHierarchy;
        }

        private void SetupDeviceLostDialog()
        {
            if (deviceLostDialog != null)
            {
                deviceLostDialog.SetActive(false);
            }

            if (deviceLostConfirmButton != null)
            {
                deviceLostConfirmButton.onClick.RemoveAllListeners();
                deviceLostConfirmButton.onClick.AddListener(OnDeviceLostConfirmClicked);
            }
        }

        private void OnDeviceLost(string reason)
        {
            EZLog.W(EZLog.Module.UI, $"Device lost: {reason}");
            EndCompletionMonitoring();

            if (deviceLostDialogVisible)
            {
                return;
            }

            deviceLostDialogVisible = true;

            if (deviceLostMessageText != null)
            {
                deviceLostMessageText.text = "设备失联，请重启分药机。";
            }

            if (deviceLostDialog != null)
            {
                deviceLostDialog.SetActive(true);
            }
            else
            {
                FireAndForget(ResetAndReturnHomeAfterDeviceLostAsync());
            }
        }

        private void OnDeviceLostConfirmClicked()
        {
            FireAndForget(ResetAndReturnHomeAfterDeviceLostAsync());
        }

        private async Task ResetAndReturnHomeAfterDeviceLostAsync()
        {
            EndCompletionMonitoring();

            if (deviceLostDialog != null)
            {
                deviceLostDialog.SetActive(false);
            }
            deviceLostDialogVisible = false;

            var main = MainController.Instance;
            if (main != null)
            {
                await main.ResetAfterDeviceLostAsync();
            }

            if (SceneManager.GetActiveScene().name != homeSceneName)
            {
                await LoadSceneAsyncSafe(homeSceneName);
            }
        }

        private void UnsubscribeEvents()
        {
            EndIdentificationSession(stopScanner: true);
            EndCompletionMonitoring();

            var main = MainController.Instance;
            if (main != null)
            {
                main.PatientsUpdated -= RenderPatientButtons;
                main.DispensingProgressChanged -= UpdateDispenseUI;
                main.DispensingError -= ShowDispenseError;
                main.DispensingCompleted -= OnDispenseCompleted;
                main.ServoAngleChanged -= OnServoAngleChangedBySystem;
                main.PlateSwitchRequired -= OnPlateSwitchRequired;
                main.MedicineSkipped -= OnMedicineSkipped;
                main.MotorStallChanged -= OnMotorStallChanged;
                main.SkipConfirmRequired -= OnSkipConfirmRequired;
                main.DeviceLost -= OnDeviceLost;
            }


            var dispenser = FindObjectOfType<DispenserController>();
            if (dispenser != null)
            {
                dispenser.OnConnectionStateChanged -= OnDispenserConnectionChanged;
                dispenser.OnPauseStateChanged -= UpdatePauseButtonUI;
            }

            if (lightBarRoutine != null)
            {
                StopCoroutine(lightBarRoutine);
            }
        }

        private void FireAndForget(Task task)
        {
            async void Wrapper()
            {
                try
                {
                    await task;
                }
                catch (Exception e)
                {
                    EZLog.E(EZLog.Module.UI, $"Async error: {e.Message}");
                }
            }

            Wrapper();
        }

        /// <summary>
        /// Awaitable wrapper for Unity scene loading.
        /// </summary>
        private static async Task LoadSceneAsyncSafe(string sceneName)
        {
            var op = SceneManager.LoadSceneAsync(sceneName);
            if (op == null)
            {
                EZLog.E(EZLog.Module.UI, $"Failed to load scene: {sceneName}");
                return;
            }

            while (!op.isDone)
            {
                await Task.Yield();
            }
        }

        /// <summary>
        /// 判断药品时间是否属于饭后/随餐/任意时间
        /// </summary>
        private bool IsAfterMealTiming(string timing)
        {
            if (string.IsNullOrEmpty(timing)) return false;
            return string.Equals(timing, "after", StringComparison.OrdinalIgnoreCase)
                || string.Equals(timing, "after_meal", StringComparison.OrdinalIgnoreCase)
                || string.Equals(timing, "with_meal", StringComparison.OrdinalIgnoreCase)
                || string.Equals(timing, "anytime", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// 寻找弹窗内的 Message 文本组件的辅助方法
        /// </summary>
        private Text FindDialogMessageText(GameObject dialog, string defaultNamePattern)
        {
            if (dialog == null) return null;
            var texts = dialog.GetComponentsInChildren<Text>(true);
            
            // 1. 优先寻找命名中包含特定关键字的组件 (如 "Message", "Content", "Body")
            var matchingByName = texts.FirstOrDefault(t => t.name.IndexOf(defaultNamePattern, StringComparison.OrdinalIgnoreCase) >= 0);
            if (matchingByName != null) return matchingByName;
            
            // 2. 备选方案：寻找第一个不属于 Button 按钮子物体的 Text 组件
            return texts.FirstOrDefault(t => t.GetComponentInParent<Button>() == null);
        }

        #endregion
    }
}
