using UnityEngine;
using UnityEngine.Playables;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;

namespace YF_3DGameBase
{
    public interface ICutsceneCameraController
    {
        void SetControllerActive(bool active);
        bool IsControllerActive { get; }
    }

    /// <summary>
    /// Singleton manager that handles cutscene playback using Unity Timeline.
    /// Provides a decoupled interface for playing any cutscene without direct coupling to other systems.
    /// Automatically manages input locking and game state during cutscenes.
    /// Supports cutscene queuing - if a cutscene is requested while one is playing, it will be queued to play after.
    /// </summary>
    public class CutsceneManager : MonoBehaviour
    {
        public static CutsceneManager Instance { get; private set; }

        [Header("Configuration")]
        [Tooltip("The PlayableDirector component that will play cutscenes. If null, one will be created.")]
        [SerializeField] private PlayableDirector _playableDirector;

        [Tooltip("If true, automatically lock input when cutscenes start and unlock when they finish.")]
        [SerializeField] private bool _autoManageInput = true;

        [Header("Camera Management")]
        [Tooltip("The game camera controller to disable during cutscenes. This should be a script like CylinderCamera that controls camera movement. The Camera component itself stays enabled for Cinemachine.")]
        [SerializeField] private MonoBehaviour _gameCameraController;

        [Tooltip("If true, automatically disable camera controller scripts during cutscenes so they don't fight with Timeline/Cinemachine.")]
        [SerializeField] private bool _autoManageCamera = true;

        [Header("Pause Behaviour")]
        [Tooltip("When true, pausing a cutscene will freeze Time.timeScale. When false, physics simulation is paused instead so real-time VFX keep playing.")]
        [SerializeField] private bool _pauseWithTimeScale = false;
        [Tooltip("If not using Time.timeScale, pause 3D physics simulation to keep gameplay frozen while leaving time-based VFX untouched.")]
        [SerializeField] private bool _pausePhysicsSimulation = true;

        private bool _isPlayingCutscene = false;
        private string _currentCutsceneId = "";
        private SO_CutsceneData _currentCutsceneData;
        private Queue<SO_CutsceneData> _cutsceneQueue = new Queue<SO_CutsceneData>();

        private float _cachedTimeScale = 1f;
        private SimulationMode _cachedAutoSimulation = SimulationMode.FixedUpdate;
        private DirectorUpdateMode _cachedDirectorUpdateMode = DirectorUpdateMode.GameTime;
        private bool _didApplyTimeScalePause = false;
        private bool _didPausePhysics = false;
        
        private bool _wasGameCameraControllerEnabled = true;
        private ICutsceneCameraController _cutsceneCameraController;
        
        // Cinemachine virtual camera tracking for cutscenes
        private List<GameObject> _cutsceneVirtualCameras = new List<GameObject>();
        private Dictionary<GameObject, int> _originalVCamPriorities = new Dictionary<GameObject, int>();
        private Coroutine _monitorCoroutine;

        private System.Type _cinemachineBrainType;
        private UnityEngine.Behaviour _cinemachineBrain;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);

            // Ensure we have a PlayableDirector
            if (_playableDirector == null)
            {
                _playableDirector = gameObject.GetComponent<PlayableDirector>();
                if (_playableDirector == null)
                {
                    _playableDirector = gameObject.AddComponent<PlayableDirector>();
                }
            }

            // Auto-find game camera controller if not assigned
            if (_autoManageCamera && _gameCameraController == null)
            {
                FindGameCameraController();
            }
            if (_gameCameraController != null)
            {
                _cutsceneCameraController = _gameCameraController as ICutsceneCameraController;
            }
            
            // Subscribe to PlayableDirector stopped event
            if (_playableDirector != null)
            {
                _playableDirector.stopped += OnPlayableDirectorStopped;
            }

            _cinemachineBrain = FindCinemachineBrain();
        }

        private void FindGameCameraController()
        {
            // Try to find CylinderCamera or other camera controller scripts
            // These are the scripts that control camera movement and should be disabled during cutscenes
            // The actual Camera component stays enabled for Cinemachine/Timeline to use
            
            var cylinderCamera = FindObjectOfType<ThousandFloors.CylinderCamera>();
            if (cylinderCamera != null)
            {
                _gameCameraController = cylinderCamera;
                _cutsceneCameraController = cylinderCamera as ICutsceneCameraController;
                Debug.Log($"[CutsceneManager] Found game camera controller: {_gameCameraController.name}");
                return;
            }

            // Could add other camera controller types here if needed
            // e.g., FreeLookCamera, FollowCamera, etc.

            Debug.LogWarning("[CutsceneManager] Could not find game camera controller. Camera controller management will be disabled.");
        }

        private void OnEnable()
        {
            // Subscribe to cutscene events to track state
            GlobalEvents.OnCutsceneStarted += HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished += HandleCutsceneFinished;
        }

        private void OnDisable()
        {
            GlobalEvents.OnCutsceneStarted -= HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished -= HandleCutsceneFinished;
        }
        
        private void OnDestroy()
        {
            // Unsubscribe from PlayableDirector
            if (_playableDirector != null)
            {
                _playableDirector.stopped -= OnPlayableDirectorStopped;
            }
        }
        
        /// <summary>
        /// Event handler for when PlayableDirector stops.
        /// This fires automatically when Timeline reaches the end (if extrapolation is "None")
        /// or when Stop() is called manually.
        /// NOTE: If Timeline has "Hold" extrapolation, it will NOT fire automatically at the end
        /// (that's why we also have the MonitorCutsceneCompletion coroutine as backup).
        /// </summary>
        private void OnPlayableDirectorStopped(PlayableDirector director)
        {
            Debug.Log($"[CutsceneManager] PlayableDirector stopped event fired. IsPlayingCutscene: {_isPlayingCutscene}");
            if (_isPlayingCutscene)
            {
                FinishCutscene();
            }
        }

        /// <summary>
        /// Plays a cutscene from a CutsceneData asset.
        /// </summary>
        /// <param name="cutsceneData">The cutscene data containing the Timeline asset to play.</param>
        /// <returns>True if the cutscene started playing, false if it couldn't play (e.g., already playing or invalid data).</returns>
        public bool PlayCutscene(SO_CutsceneData cutsceneData)
        {
            if (cutsceneData == null)
            {
                Debug.LogWarning("[CutsceneManager] Attempted to play null cutscene data.");
                return false;
            }

            if (cutsceneData.timelineAsset == null)
            {
                Debug.LogWarning($"[CutsceneManager] Cutscene '{cutsceneData.cutsceneId}' has no Timeline asset assigned.");
                return false;
            }

            if (_isPlayingCutscene)
            {
                Debug.LogWarning($"[CutsceneManager] Already playing cutscene '{_currentCutsceneId}'. Cannot play '{cutsceneData.cutsceneId}'.");
                return false;
            }

            // Stop any currently playing timeline
            if (_playableDirector.state == PlayState.Playing)
            {
                _playableDirector.Stop();
            }

            // Set up the cutscene
            _currentCutsceneData = cutsceneData;
            _currentCutsceneId = cutsceneData.cutsceneId;
            _isPlayingCutscene = true;

            // Lock input if auto-managing
            if (_autoManageInput)
            {
                GlobalEvents.ToggleInputLock(true);
            }

            // Disable game camera controller if auto-managing
            // Note: We only disable the CONTROLLER (e.g., CylinderCamera), NOT the Camera component
            // The Camera component must stay enabled for Cinemachine/Timeline to work
            if (_autoManageCamera)
            {
                // Try to find camera controller if not already found
                if (_gameCameraController == null)
                {
                    FindGameCameraController();
                }
                DisableGameCameraController();
            }

            // Ensure CinemachineBrain is enabled for the cutscene
            // (It might have been disabled by FinishCutscene if we have a custom camera controller)
            if (_cinemachineBrain != null)
            {
                _cinemachineBrain.enabled = true;
            }

            // Track Cinemachine virtual cameras bound to this Timeline
            TrackCutsceneVirtualCameras();

            ApplyCutscenePauseIfRequested(cutsceneData);

            // Play the timeline
            // Timeline duration is automatically calculated from the longest track in the Timeline asset
            _playableDirector.playableAsset = cutsceneData.timelineAsset;
            _playableDirector.time = 0f;
            
            // Log timeline info for debugging
            if (cutsceneData.timelineAsset != null)
            {
                Debug.Log($"[CutsceneManager] Playing cutscene '{cutsceneData.cutsceneId}' - Timeline duration: {_playableDirector.duration:F2}s");
            }
            
            _playableDirector.Play();

            // Fire start event
            GlobalEvents.CutsceneStarted(_currentCutsceneId);

            // Start coroutine as backup to monitor completion (in case stopped event doesn't fire)
            if (_monitorCoroutine != null)
            {
                StopCoroutine(_monitorCoroutine);
            }
            _monitorCoroutine = StartCoroutine(MonitorCutsceneCompletion());

            return true;
        }

        /// <summary>
        /// Stops the currently playing cutscene early.
        /// </summary>
        public void StopCutscene()
        {
            if (!_isPlayingCutscene) return;

            if (_playableDirector != null && _playableDirector.state == PlayState.Playing)
            {
                _playableDirector.Stop();
            }

            FinishCutscene();
        }

        /// <summary>
        /// Returns whether a cutscene is currently playing.
        /// </summary>
        public bool IsPlayingCutscene => _isPlayingCutscene;

        /// <summary>
        /// Returns the ID of the currently playing cutscene, or empty string if none.
        /// </summary>
        public string CurrentCutsceneId => _currentCutsceneId;

        private IEnumerator MonitorCutsceneCompletion()
        {
            // Wait a frame to let Timeline start
            yield return null;
            
            if (_playableDirector == null || _playableDirector.playableAsset == null)
            {
                Debug.LogError("[CutsceneManager] PlayableDirector or playableAsset is null!");
                _monitorCoroutine = null;
                yield break;
            }

            double timelineDuration = _playableDirector.duration;
            Debug.Log($"[CutsceneManager] Monitoring cutscene completion. Duration: {timelineDuration}s");
            
            // Wait for the timeline to finish
            // The stopped event should fire automatically when timeline ends (if extrapolation is None)
            // But we also check manually in case it's in Hold mode or the event doesn't fire
            while (_isPlayingCutscene && _playableDirector != null)
            {
                // Check if timeline has stopped (the stopped event should have handled this, but backup check)
                if (_playableDirector.state != PlayState.Playing)
                {
                    Debug.Log($"[CutsceneManager] Monitor detected timeline stopped. State: {_playableDirector.state}");
                    break;
                }
                
                // Check if we've reached the end of the timeline
                // Use a small tolerance for floating-point precision
                double currentTime = _playableDirector.time;
                if (currentTime >= timelineDuration - 0.02) // 20ms tolerance
                {
                    Debug.Log($"[CutsceneManager] Monitor detected timeline reached end. Time: {currentTime:F3}/{timelineDuration:F3}");
                    // Timeline has reached the end - stop it manually if it hasn't stopped already
                    // (This handles Hold mode where it won't stop automatically)
                    if (_playableDirector.state == PlayState.Playing)
                    {
                        _playableDirector.Stop();
                    }
                    break;
                }
                
                yield return null;
            }

            // Timeline finished - call FinishCutscene if not already finished
            // (Note: The stopped event should have already called FinishCutscene, but this is a backup)
            if (_isPlayingCutscene)
            {
                Debug.Log("[CutsceneManager] Monitor coroutine triggering FinishCutscene as backup");
                FinishCutscene();
            }
            
            _monitorCoroutine = null;
        }

        private void FinishCutscene()
        {
            if (!_isPlayingCutscene) return;

            Debug.Log($"[CutsceneManager] FinishCutscene called for '{_currentCutsceneId}'");
            
            // Stop monitor coroutine if running
            if (_monitorCoroutine != null)
            {
                StopCoroutine(_monitorCoroutine);
                _monitorCoroutine = null;
            }

            string finishedId = _currentCutsceneId;

            // Disable CinemachineBrain first so it doesn't interfere with camera restoration
            DisableCinemachineBrain();

            // Lower priority of cutscene virtual cameras so gameplay camera takes over
            RestoreGameplayCamera();

            // Re-enable game camera controller if auto-managing
            // This allows the camera controller to resume following the player
            if (_autoManageCamera)
            {
                EnableGameCameraController();
            }

            // Re-enable CinemachineBrain after a frame to allow camera to snap first
            // But only if we're not using CylinderCamera (which directly controls transform)
            if (_cutsceneCameraController == null)
            {
                StartCoroutine(ReEnableCinemachineBrainDelayed());
            }

            // Restore pause behaviour (time scale or physics)
            RestoreCutscenePause();

            // Unlock input if auto-managing
            if (_autoManageInput && _currentCutsceneData != null && _currentCutsceneData.autoRestoreInput)
            {
                GlobalEvents.ToggleInputLock(false);
            }

            // Reset state
            _isPlayingCutscene = false;
            _currentCutsceneId = "";
            _currentCutsceneData = null;

            // Fire finish event
            GlobalEvents.CutsceneFinished(finishedId);
        }

        private void HandleCutsceneStarted(string cutsceneId)
        {
            // Optional: Handle cutscene start (e.g., UI, audio)
            Debug.Log($"[CutsceneManager] Cutscene '{cutsceneId}' started.");
        }

        /// <summary>
        /// Queues a cutscene to play after the current cutscene finishes.
        /// If no cutscene is currently playing, it will play immediately.
        /// </summary>
        /// <param name="cutsceneData">The cutscene data to queue.</param>
        public void QueueCutscene(SO_CutsceneData cutsceneData)
        {
            if (cutsceneData == null)
            {
                Debug.LogWarning("[CutsceneManager] Attempted to queue null cutscene data.");
                return;
            }

            if (cutsceneData.timelineAsset == null)
            {
                Debug.LogWarning($"[CutsceneManager] Cutscene '{cutsceneData.cutsceneId}' has no Timeline asset assigned. Cannot queue.");
                return;
            }

            // If not playing, play immediately
            if (!_isPlayingCutscene)
            {
                PlayCutscene(cutsceneData);
                return;
            }

            // Otherwise, add to queue
            _cutsceneQueue.Enqueue(cutsceneData);
            Debug.Log($"[CutsceneManager] Queued cutscene '{cutsceneData.cutsceneId}'. Queue size: {_cutsceneQueue.Count}");
        }

        /// <summary>
        /// Returns the number of cutscenes currently queued.
        /// </summary>
        public int QueuedCutsceneCount => _cutsceneQueue.Count;

        /// <summary>
        /// Clears all queued cutscenes.
        /// </summary>
        public void ClearQueue()
        {
            _cutsceneQueue.Clear();
            Debug.Log("[CutsceneManager] Cleared cutscene queue.");
        }

        private void HandleCutsceneFinished(string cutsceneId)
        {
            // Optional: Handle cutscene finish (e.g., cleanup, effects)
            Debug.Log($"[CutsceneManager] Cutscene '{cutsceneId}' finished.");

            // Process next cutscene in queue
            if (_cutsceneQueue.Count > 0)
            {
                SO_CutsceneData nextCutscene = _cutsceneQueue.Dequeue();
                Debug.Log($"[CutsceneManager] Playing next queued cutscene: '{nextCutscene.cutsceneId}'");
                PlayCutscene(nextCutscene);
            }
        }

        private void ApplyCutscenePauseIfRequested(SO_CutsceneData cutsceneData)
        {
            _didApplyTimeScalePause = false;
            _didPausePhysics = false;

            if (cutsceneData == null || !cutsceneData.pauseGameTime) return;

            if (_pauseWithTimeScale)
            {
                _cachedTimeScale = Time.timeScale;
                _cachedDirectorUpdateMode = _playableDirector != null ? _playableDirector.timeUpdateMode : DirectorUpdateMode.GameTime;

                Time.timeScale = 0f;
                if (_playableDirector != null)
                {
                    // Ensure the Timeline keeps advancing even though scaled time is frozen
                    _playableDirector.timeUpdateMode = DirectorUpdateMode.UnscaledGameTime;
                }

                _didApplyTimeScalePause = true;
            }
            else if (_pausePhysicsSimulation)
            {
                _cachedAutoSimulation = Physics.simulationMode;
                Physics.simulationMode = SimulationMode.Script;
                _didPausePhysics = true;
            }
        }

        private void RestoreCutscenePause()
        {
            if (_didApplyTimeScalePause)
            {
                Time.timeScale = _cachedTimeScale;

                if (_playableDirector != null)
                {
                    _playableDirector.timeUpdateMode = _cachedDirectorUpdateMode;
                }
            }

            if (_didPausePhysics)
            {
                Physics.simulationMode = _cachedAutoSimulation;
            }

            _didApplyTimeScalePause = false;
            _didPausePhysics = false;
        }

        private void DisableGameCameraController()
        {
            if (_gameCameraController == null) return;

            if (_cutsceneCameraController != null)
            {
                _cutsceneCameraController.SetControllerActive(false);
                return;
            }

            _wasGameCameraControllerEnabled = _gameCameraController.enabled;
            _gameCameraController.enabled = false;

            Debug.Log($"[CutsceneManager] Disabled game camera controller: {_gameCameraController.name} (Camera stays enabled for Cinemachine)");
        }

        private void EnableGameCameraController()
        {
            if (_gameCameraController == null) return;

            if (_cutsceneCameraController != null)
            {
                _cutsceneCameraController.SetControllerActive(true);
                return;
            }

            // Re-enable camera controller (only if it was enabled before)
            if (_wasGameCameraControllerEnabled)
            {
                _gameCameraController.enabled = true;
                Debug.Log($"[CutsceneManager] Re-enabled game camera controller: {_gameCameraController.name}");
            }
            else
            {
                Debug.Log($"[CutsceneManager] Game camera controller was disabled before cutscene, keeping it disabled: {_gameCameraController.name}");
            }
        }

        #region Cinemachine Virtual Camera Management
        
        /// <summary>
        /// Finds and tracks all Cinemachine virtual cameras bound to the current Timeline.
        /// Stores their original priorities so we can restore gameplay camera after cutscene.
        /// Uses reflection to work with both Cinemachine 2.x and 3.x.
        /// </summary>
        private void TrackCutsceneVirtualCameras()
        {
            _cutsceneVirtualCameras.Clear();
            _originalVCamPriorities.Clear();

            if (_playableDirector == null || _playableDirector.playableAsset == null) return;

            // Try to get Cinemachine types using reflection (works regardless of version)
            System.Type vcamBaseType = System.Type.GetType("Cinemachine.CinemachineVirtualCameraBase, Cinemachine");
            System.Type vcam3Type = System.Type.GetType("Unity.Cinemachine.CinemachineCamera, Unity.Cinemachine");
            
            if (vcamBaseType == null && vcam3Type == null)
            {
                Debug.LogWarning("[CutsceneManager] Cinemachine not found. Virtual camera priority management disabled.");
                return;
            }

            var bindings = _playableDirector.playableAsset.outputs;
            foreach (var binding in bindings)
            {
                var boundObject = _playableDirector.GetGenericBinding(binding.sourceObject);
                if (boundObject == null) continue;

                GameObject vcamObj = null;
                int priority = -1;

                // Check for Cinemachine 2.x (CinemachineVirtualCameraBase)
                if (vcamBaseType != null && vcamBaseType.IsInstanceOfType(boundObject))
                {
                    var boundMono = boundObject as MonoBehaviour;
                    EnsureComponentEnabled(boundMono);
                    vcamObj = boundMono?.gameObject;
                    PropertyInfo priorityProp = vcamBaseType.GetProperty("Priority");
                    if (priorityProp != null && vcamObj != null)
                    {
                        priority = (int)priorityProp.GetValue(boundObject);
                        _originalVCamPriorities[vcamObj] = priority;
                        Debug.Log($"[CutsceneManager] Tracked cutscene VCam (Cinemachine 2.x): {vcamObj.name}, Priority: {priority}");
                    }
                }
                // Check for Cinemachine 3.x (CinemachineCamera)
                else if (vcam3Type != null && vcam3Type.IsInstanceOfType(boundObject))
                {
                    var boundMono = boundObject as MonoBehaviour;
                    EnsureComponentEnabled(boundMono);
                    vcamObj = boundMono?.gameObject;
                    PropertyInfo priorityProp = vcam3Type.GetProperty("Priority");
                    if (priorityProp != null && vcamObj != null)
                    {
                        object priorityValue = priorityProp.GetValue(boundObject);
                        // Priority is a struct in Cinemachine 3.x, get its Value property
                        PropertyInfo valueProp = priorityValue?.GetType().GetProperty("Value");
                        if (valueProp != null)
                        {
                            priority = (int)valueProp.GetValue(priorityValue);
                            _originalVCamPriorities[vcamObj] = priority;
                            Debug.Log($"[CutsceneManager] Tracked cutscene VCam (Cinemachine 3.x): {vcamObj.name}, Priority: {priority}");
                        }
                    }
                }

                if (vcamObj != null)
                {
                    _cutsceneVirtualCameras.Add(vcamObj);
                }
            }

            // Also search for virtual cameras in children of bound GameObjects (common Timeline setup)
            foreach (var binding in bindings)
            {
                var boundObject = _playableDirector.GetGenericBinding(binding.sourceObject);
                if (boundObject is GameObject go)
                {
                    // Check children for Cinemachine 2.x
                    if (vcamBaseType != null)
                    {
                        var components = go.GetComponentsInChildren(vcamBaseType, true);
                        foreach (var component in components)
                        {
                            var mono = component as MonoBehaviour;
                            EnsureComponentEnabled(mono);
                            GameObject vcamGo = mono?.gameObject;
                            if (vcamGo != null && !_cutsceneVirtualCameras.Contains(vcamGo))
                            {
                                _cutsceneVirtualCameras.Add(vcamGo);
                                PropertyInfo priorityProp = vcamBaseType.GetProperty("Priority");
                                if (priorityProp != null)
                                {
                                    int childPriority = (int)priorityProp.GetValue(component);
                                    _originalVCamPriorities[vcamGo] = childPriority;
                                    Debug.Log($"[CutsceneManager] Tracked cutscene VCam (child, Cinemachine 2.x): {vcamGo.name}, Priority: {childPriority}");
                                }
                            }
                        }
                    }
                    // Check children for Cinemachine 3.x
                    if (vcam3Type != null)
                    {
                        var components = go.GetComponentsInChildren(vcam3Type, true);
                        foreach (var component in components)
                        {
                            var mono = component as MonoBehaviour;
                            EnsureComponentEnabled(mono);
                            GameObject vcamGo = mono?.gameObject;
                            if (vcamGo != null && !_cutsceneVirtualCameras.Contains(vcamGo))
                            {
                                _cutsceneVirtualCameras.Add(vcamGo);
                                PropertyInfo priorityProp = vcam3Type.GetProperty("Priority");
                                if (priorityProp != null)
                                {
                                    object priorityValue = priorityProp.GetValue(component);
                                    PropertyInfo valueProp = priorityValue?.GetType().GetProperty("Value");
                                    if (valueProp != null)
                                    {
                                        int childPriority = (int)valueProp.GetValue(priorityValue);
                                        _originalVCamPriorities[vcamGo] = childPriority;
                                        Debug.Log($"[CutsceneManager] Tracked cutscene VCam (child, Cinemachine 3.x): {vcamGo.name}, Priority: {childPriority}");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Lowers priority of cutscene virtual cameras and disables them so gameplay camera takes over.
        /// Uses reflection to work with both Cinemachine 2.x and 3.x.
        /// </summary>
        private void RestoreGameplayCamera()
        {
            if (_cutsceneVirtualCameras.Count == 0) return;

            Debug.Log($"[CutsceneManager] Restoring gameplay camera. Disabling/lowering priority of {_cutsceneVirtualCameras.Count} cutscene VCams.");

            System.Type vcamBaseType = System.Type.GetType("Cinemachine.CinemachineVirtualCameraBase, Cinemachine");
            System.Type vcam3Type = System.Type.GetType("Unity.Cinemachine.CinemachineCamera, Unity.Cinemachine");

            foreach (var vcamObj in _cutsceneVirtualCameras)
            {
                if (vcamObj == null) continue;

                int originalPriority = _originalVCamPriorities.GetValueOrDefault(vcamObj, -1);

                // Handle Cinemachine 2.x
                if (vcamBaseType != null)
                {
                    var component = vcamObj.GetComponent(vcamBaseType);
                    if (component != null)
                    {
                        // Option 1: Disable the virtual camera entirely (most reliable)
                        MonoBehaviour vcamMono = component as MonoBehaviour;
                        if (vcamMono != null)
                        {
                            vcamMono.enabled = false;
                            Debug.Log($"[CutsceneManager] Disabled cutscene VCam {vcamObj.name} (Cinemachine 2.x) (was priority {originalPriority})");
                        }
                        
                        // Option 2: Also lower priority as backup (in case disabling doesn't work)
                        PropertyInfo priorityProp = vcamBaseType.GetProperty("Priority");
                        if (priorityProp != null)
                        {
                            priorityProp.SetValue(component, 0);
                            Debug.Log($"[CutsceneManager] Also lowered priority of {vcamObj.name} (Cinemachine 2.x) to 0");
                        }
                    }
                }
                // Handle Cinemachine 3.x
                if (vcam3Type != null)
                {
                    var component = vcamObj.GetComponent(vcam3Type);
                    if (component != null)
                    {
                        // Option 1: Disable the virtual camera entirely (most reliable)
                        MonoBehaviour vcamMono = component as MonoBehaviour;
                        if (vcamMono != null)
                        {
                            vcamMono.enabled = false;
                            Debug.Log($"[CutsceneManager] Disabled cutscene VCam {vcamObj.name} (Cinemachine 3.x) (was priority {originalPriority})");
                        }
                        
                        // Option 2: Also lower priority as backup
                        PropertyInfo priorityProp = vcam3Type.GetProperty("Priority");
                        if (priorityProp != null)
                        {
                            object priorityValue = priorityProp.GetValue(component);
                            PropertyInfo valueProp = priorityValue?.GetType().GetProperty("Value");
                            if (valueProp != null)
                            {
                                valueProp.SetValue(priorityValue, 0);
                                priorityProp.SetValue(component, priorityValue);
                                Debug.Log($"[CutsceneManager] Also lowered priority of {vcamObj.name} (Cinemachine 3.x) to 0");
                            }
                        }
                    }
                }
            }

            // Clear tracking for next cutscene
            _cutsceneVirtualCameras.Clear();
            _originalVCamPriorities.Clear();
        }

        /// <summary>
        /// Ensures a tracked Cinemachine component is enabled so the Timeline can take control again.
        /// </summary>
        private void EnsureComponentEnabled(MonoBehaviour component)
        {
            if (component == null) return;
            if (!component.enabled)
            {
                component.enabled = true;
                Debug.Log($"[CutsceneManager] Re-enabled cutscene virtual camera component: {component.name}");
            }
        }

        /// <summary>
        /// Finds the CinemachineBrain in the scene so we can reset it after cutscenes.
        /// </summary>
        private UnityEngine.Behaviour FindCinemachineBrain()
        {
            _cinemachineBrainType = System.Type.GetType("Cinemachine.CinemachineBrain, Cinemachine")
                                     ?? System.Type.GetType("Unity.Cinemachine.CinemachineBrain, Unity.Cinemachine");

            if (_cinemachineBrainType == null)
            {
                Debug.LogWarning("[CutsceneManager] CinemachineBrain type could not be resolved. Cinemachine reset disabled.");
                return null;
            }

            var brain = UnityEngine.Object.FindObjectOfType(_cinemachineBrainType) as UnityEngine.Behaviour;
            if (brain != null)
            {
                Debug.Log($"[CutsceneManager] Found Cinemachine brain: {brain.name}");
            }
            else
            {
                Debug.LogWarning("[CutsceneManager] No CinemachineBrain instance found in scene.");
            }

            return brain;
        }

        /// <summary>
        /// Toggles the Cinemachine brain off/on to force a re-evaluation of the active camera.
        /// </summary>
        private void DisableCinemachineBrain()
        {
            if (_cinemachineBrain == null) return;

            _cinemachineBrain.enabled = false;
            Debug.Log("[CutsceneManager] Disabled Cinemachine brain to allow gameplay camera to take control.");
        }

        private IEnumerator ReEnableCinemachineBrainDelayed()
        {
            // Wait a frame to allow CylinderCamera to snap position
            yield return null;
            
            if (_cinemachineBrain != null && _cutsceneCameraController == null)
            {
                _cinemachineBrain.enabled = true;
                Debug.Log("[CutsceneManager] Re-enabled Cinemachine brain after camera restoration.");
            }
        }

        private void ResetCinemachineBrain()
        {
            if (_cinemachineBrain == null) return;

            _cinemachineBrain.enabled = false;
            _cinemachineBrain.enabled = true;
            Debug.Log("[CutsceneManager] Reset Cinemachine brain to refresh camera blending.");
        }
        
        #endregion
    }
}
