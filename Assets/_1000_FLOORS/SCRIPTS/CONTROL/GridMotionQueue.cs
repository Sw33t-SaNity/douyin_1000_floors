using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using YF_3DGameBase;
using MoreMountains.Feedbacks;
using Douyin.YF.Live;

namespace ThousandFloors
{
    /// <summary>
    /// Manages queued grid motion requests with stacking capabilities, cutscene-aware pausing, and complex effect lifecycle management.
    /// 
    /// Key Responsibilities:
    /// - <see cref="QueueMovement"/>: Adds new movement requests (level delta + effects) to a processing queue.
    /// - <see cref="ProcessMovementQueue"/>: Continuously processes the queue, combining stacked movements (e.g., 50 + 100 = 150) and handling cancellations (e.g., 50 down + 10 up = 40 down).
    /// - <see cref="HandlePlatformBroken"/>: Reacts to platform break events by triggering associated camera shakes and spawning gift-specific break effects.
    /// - Effect Lifecycle: Manages instantiation, parenting (for persistent effects), and cleanup of both persistent and one-time effects.
    /// </summary>
    public class GridMotionQueue : MonoBehaviour
    {
        #region Singleton
        
        public static GridMotionQueue Instance { get; private set; }

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
        }

        #endregion

        #region Inspector Settings

        [Header("Settings")]
        [Tooltip("If true, all grid movements are automatically paused when a global cutscene starts.")]
        [SerializeField] private bool _pauseDuringCutscenes = true;

        [Header("Feedbacks")]
        [Tooltip("MMF_Player feedback (e.g., camera shake) to play whenever a platform breaks during movement.")]
        [SerializeField] private MMF_Player _platformBreakCameraShake;

        #endregion

        #region Internal Data Structures

        /// <summary>
        /// Represents a single queued movement request from a gift.
        /// Stores the movement delta and all associated effect configurations.
        /// </summary>
        private struct GiftMovement
        {
            public int LevelDelta;
            public string GiftId;
            public List<EffectData> PersistentEffects;  // Effects active during the move
            public List<EffectData> OneTimeEffects;     // Effects triggered once on queue
            public List<EffectData> FloorBreakEffects;  // Effects triggered on platform break
        }

        /// <summary>
        /// Tracks an instantiated effect object to ensure proper cleanup.
        /// </summary>
        private struct ActiveEffect
        {
            public GameObject EffectInstance;
            public bool IsPersistent;
            public string GiftId;
        }

        #endregion

        #region State Variables

        // Queue of incoming movement requests.
        private readonly Queue<GiftMovement> _queuedMovements = new Queue<GiftMovement>();

        // Tracks instantiated persistent effects.
        private readonly List<ActiveEffect> _activeEffects = new List<ActiveEffect>();

        // Maps active GiftIDs to their specific floor break effects. 
        // This allows multiple concurrent gifts to trigger their own unique break effects.
        private readonly Dictionary<string, List<EffectData>> _activeGiftFloorBreakEffects = new Dictionary<string, List<EffectData>>();

        // Net movement delta currently being processed or waiting to be processed.
        private int _pendingLevelDelta = 0;

        // Processing Flags
        private bool _isProcessingQueue = false;
        private bool _isPaused = false;

        #endregion

        #region Unity Lifecycle

        private void OnEnable()
        {
            if (_pauseDuringCutscenes)
            {
                GlobalEvents.OnCutsceneStarted += HandleCutsceneStarted;
                GlobalEvents.OnCutsceneFinished += HandleCutsceneFinished;
            }
            
            // Subscribe to platform break events to trigger additional effects (visuals, camera shake)
            ThousandFloorsEvents.OnPlatformBroken += HandlePlatformBroken;
        }

        private void OnDisable()
        {
            GlobalEvents.OnCutsceneStarted -= HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished -= HandleCutsceneFinished;
            ThousandFloorsEvents.OnPlatformBroken -= HandlePlatformBroken;
        }

        #endregion

        #region Event Handlers

        private void HandleCutsceneStarted(string cutsceneId)
        {
            // Pause any active movement processing immediately.
            // The ExecuteMovement coroutine monitors this flag and will yield while true.
            _isPaused = true;
            Debug.Log($"[GridMotionQueue] Pausing grid motion for cutscene '{cutsceneId}'.");
        }

        private void HandleCutsceneFinished(string cutsceneId)
        {
            _isPaused = false;
            Debug.Log($"[GridMotionQueue] Resuming grid motion after cutscene '{cutsceneId}'. Pending Delta: {_pendingLevelDelta}, Queue Count: {_queuedMovements.Count}");
            
            // If movement requests piled up during the cutscene (or were pending), 
            // ensure the processing coroutine is running.
            if ((_pendingLevelDelta != 0 || _queuedMovements.Count > 0) && !_isProcessingQueue)
            {
                StartCoroutine(ProcessMovementQueue());
            }
        }

        /// <summary>
        /// Triggered when a platform breaks. Plays camera shake and spawns gift-specific break effects.
        /// </summary>
        private void HandlePlatformBroken(int levelIndex)
        {
            // 1. Play generic feedback (Camera Shake)
            if (_platformBreakCameraShake != null)
            {
                _platformBreakCameraShake.PlayFeedbacks();
            }

            // 2. Spawn gift-specific effects
            if (_activeGiftFloorBreakEffects.Count == 0) return;

            Vector3 platformPosition = GetPlatformPosition(levelIndex);

            // Iterate through all currently active gifts that have registered break effects
            foreach (var kvp in _activeGiftFloorBreakEffects)
            {
                string giftId = kvp.Key;
                List<EffectData> floorBreakEffects = kvp.Value;

                if (floorBreakEffects != null && floorBreakEffects.Count > 0)
                {
                    SpawnFloorBreakEffects(giftId, floorBreakEffects, platformPosition, levelIndex);
                }
            }
        }

        #endregion

        #region Public API

        /// <summary>
        /// Adds a movement request to the queue. Movements are "stacked", meaning concurrent requests are combined.
        /// For example, if moving down 50 levels and a request to move up 10 arrives, the net movement becomes 40 down,
        /// but effects for both gifts will play.
        /// </summary>
        /// <param name="levelDelta">Levels to move (positive = up, negative = down).</param>
        /// <param name="giftId">Unique identifier for the gift (used for effect tracking).</param>
        /// <param name="persistentEffects">Effects that persist for the duration of this specific movement.</param>
        /// <param name="oneTimeEffects">Effects that play immediately upon queuing.</param>
        /// <param name="floorBreakEffects">Effects to spawn if a platform breaks during this movement.</param>
        public void QueueMovement(int levelDelta, string giftId, List<EffectData> persistentEffects = null, List<EffectData> oneTimeEffects = null, List<EffectData> floorBreakEffects = null)
        {
            Debug.Log($"[GridMotionQueue] QueueMovement: Delta {levelDelta}, GiftID '{giftId}', Processing: {_isProcessingQueue}, Paused: {_isPaused}");

            // 1. Enqueue the request
            var movement = new GiftMovement
            {
                LevelDelta = levelDelta,
                GiftId = giftId,
                PersistentEffects = persistentEffects ?? new List<EffectData>(),
                OneTimeEffects = oneTimeEffects ?? new List<EffectData>(),
                FloorBreakEffects = floorBreakEffects ?? new List<EffectData>()
            };
            _queuedMovements.Enqueue(movement);

            // 2. Update global pending delta
            _pendingLevelDelta += levelDelta;

            // 3. Immediately handle "One-Shot" effects
            SpawnOneTimeEffects(movement.OneTimeEffects);

            // 4. Immediately start "Persistent" effects 
            // (We start them now so players get immediate visual feedback even if the queue is backed up or paused)
            SpawnPersistentEffects(movement.PersistentEffects, giftId);

            // 5. Register floor break effects immediately
            if (!string.IsNullOrEmpty(giftId) && movement.FloorBreakEffects.Count > 0)
            {
                _activeGiftFloorBreakEffects[giftId] = movement.FloorBreakEffects;
            }

            // 6. Ensure the processing loop is running
            if (!_isProcessingQueue)
            {
                StartCoroutine(ProcessMovementQueue());
            }
        }

        /// <summary>
        /// Registers a one-time effect instance for automatic cleanup and monitoring.
        /// This method assumes the object is already instantiated.
        /// </summary>
        /// <param name="effectInstance">The active effect GameObject to monitor.</param>
        /// <param name="lifetime">Optional lifetime override in seconds. If -1, uses particle/audio duration or default fallback.</param>
        public void PlayOneTimeEffect(GameObject effectInstance, float lifetime = -1f)
        {
            if (effectInstance == null) return;
            SetupAndMonitorOneTimeEffect(effectInstance, lifetime);
        }

        /// <summary>
        /// Gets the current net movement delta waiting to be executed.
        /// </summary>
        public int GetPendingMovement() => _pendingLevelDelta;

        /// <summary>
        /// Returns true if the system is currently moving the player or has pending moves.
        /// </summary>
        public bool IsActive() => _isProcessingQueue || _pendingLevelDelta != 0;

        /// <summary>
        /// Returns true if the system is currently paused (e.g. by a cutscene).
        /// </summary>
        public bool IsPaused() => _isPaused;

        #endregion

        #region Core Processing Logic

        /// <summary>
        /// The main loop that processes queued movements.
        /// Handles waiting for pauses (cutscenes) and combines stacked movements into a single execution batch.
        /// </summary>
        private IEnumerator ProcessMovementQueue()
        {
            _isProcessingQueue = true;

            while (_pendingLevelDelta != 0 || _queuedMovements.Count > 0)
            {
                // 1. Wait if paused
                while (_isPaused)
                {
                    yield return null;
                }

                // 2. Safety check: if pending delta was cleared externally or while paused
                if (_pendingLevelDelta == 0 && _queuedMovements.Count == 0)
                {
                    break;
                }

                // 3. Prepare Batch Execution
                if (_pendingLevelDelta != 0)
                {
                    // We consume the ENTIRE current queue into one "batch" of movement.
                    // This creates the "stacking" effect where multiple gifts combine into one long slide.
                    List<GiftMovement> batchMovements = new List<GiftMovement>();
                    int movementToExecute = _pendingLevelDelta;
                    
                    // Clear the pending counter (new incoming requests will add to it starting from 0)
                    _pendingLevelDelta = 0;

                    // Dequeue everything currently available to track their lifecycles
                    while (_queuedMovements.Count > 0)
                    {
                        var movement = _queuedMovements.Dequeue();
                        batchMovements.Add(movement);

                        // Re-register floor break effects for the current batch.
                        // This is critical because a previous batch's cleanup might have removed the entry
                        // for this GiftID while this movement was sitting in the queue.
                        if (!string.IsNullOrEmpty(movement.GiftId) && movement.FloorBreakEffects.Count > 0)
                        {
                            _activeGiftFloorBreakEffects[movement.GiftId] = movement.FloorBreakEffects;
                        }
                    }

                    Debug.Log($"[GridMotionQueue] Executing Batch: {movementToExecute} levels. Contributing Gifts: {batchMovements.Count}");

                    // 4. Execute the Physical Movement
                    // This coroutine will yield until the movement is fully complete
                    yield return StartCoroutine(ExecuteMovementInternal(movementToExecute));

                    // 5. Cleanup Batch
                    // Once movement stops, we clean up the persistent effects for all gifts in this batch.
                    foreach (var movement in batchMovements)
                    {
                        if (!string.IsNullOrEmpty(movement.GiftId))
                        {
                            CleanupPersistentEffectsForGift(movement.GiftId);
                            _activeGiftFloorBreakEffects.Remove(movement.GiftId);
                        }
                    }
                }
                else
                {
                    // Should rarely hit here unless queue has items but delta is 0 (net zero movement),
                    // in which case we just clear the queue tracking.
                    if (_queuedMovements.Count > 0)
                    {
                         _queuedMovements.Clear();
                    }
                    yield return null;
                }
            }

            // Final Cleanup
            CleanupAllPersistentEffects();
            _activeGiftFloorBreakEffects.Clear();
            _isProcessingQueue = false;
        }

        /// <summary>
        /// Interfaces with the GridMotionManager to physically move the player.
        /// Monitors the movement and respects the pause flag.
        /// </summary>
        private IEnumerator ExecuteMovementInternal(int levelDelta)
        {
            if (GridMotionManager.Instance == null || levelDelta == 0) yield break;

            // Sync pause state
            GridMotionManager.Instance.IsPaused = _isPaused;

            // Trigger the move
            GridMotionManager.Instance.MoveLevels(levelDelta);

            // Wait while moving
            while (GridMotionManager.Instance.IsMovingForced)
            {
                // Keep pause state synced in case it changes mid-move
                GridMotionManager.Instance.IsPaused = _isPaused;
                yield return null;
            }
        }

        #endregion

        #region Effect Spawning & Cleanup

        private void SpawnOneTimeEffects(List<EffectData> effects)
        {
            if (effects == null) return;

            Vector3 playerPos = GetPlayerPosition();

            foreach (var data in effects)
            {
                if (data.prefab == null) continue;

                Vector3 spawnPos = playerPos + data.offset;
                Quaternion spawnRot = Quaternion.Euler(data.rotation);
                
                GameObject instance = Instantiate(data.prefab, spawnPos, spawnRot);
                SetupAndMonitorOneTimeEffect(instance, data.lifetime);
            }
        }

        private void SpawnPersistentEffects(List<EffectData> effects, string giftId)
        {
            if (effects == null) return;

            Transform playerTransform = GetPlayerTransform();
            Vector3 playerPos = playerTransform != null ? playerTransform.position : Vector3.zero;

            foreach (var data in effects)
            {
                if (data.prefab == null) continue;

                Vector3 spawnPos = playerPos + data.offset;
                Quaternion spawnRot = Quaternion.Euler(data.rotation);

                GameObject instance = Instantiate(data.prefab, spawnPos, spawnRot);

                // Parent to player so the effect follows them down/up the floors
                if (playerTransform != null)
                {
                    instance.transform.SetParent(playerTransform, true);
                    instance.transform.localPosition = data.offset; // Maintain relative offset
                    instance.transform.localRotation = spawnRot;
                }

                StartPersistentEffectLifecycle(instance, giftId);
            }
        }

        private void SpawnFloorBreakEffects(string giftId, List<EffectData> effects, Vector3 platformPosition, int levelIndex)
        {
            foreach (var data in effects)
            {
                if (data.prefab == null) continue;

                Vector3 spawnPos = platformPosition + data.offset;
                Quaternion spawnRot = Quaternion.Euler(data.rotation);

                GameObject instance = Instantiate(data.prefab, spawnPos, spawnRot);
                SetupAndMonitorOneTimeEffect(instance, data.lifetime);
            }
        }

        private void StartPersistentEffectLifecycle(GameObject instance, string giftId)
        {
            if (instance == null) return;

            instance.SetActive(true);
            PlayParticleOrAudio(instance);

            _activeEffects.Add(new ActiveEffect
            {
                EffectInstance = instance,
                IsPersistent = true,
                GiftId = giftId
            });
        }

        private void SetupAndMonitorOneTimeEffect(GameObject instance, float lifetime)
        {
            if (instance == null) return;

            instance.SetActive(true);
            
            var ps = instance.GetComponent<ParticleSystem>();
            var audio = instance.GetComponent<AudioSource>();

            if (ps != null)
            {
                ps.Play();
                StartCoroutine(CleanupRoutine_ParticleSystem(instance, ps));
            }
            else if (audio != null)
            {
                audio.Play();
                StartCoroutine(CleanupRoutine_AudioSource(instance, audio));
            }
            else
            {
                // Fallback to time-based cleanup
                float delay = lifetime > 0f ? lifetime : 5f;
                StartCoroutine(CleanupRoutine_Timer(instance, delay));
            }
        }

        #endregion

        #region Cleanup Coroutines

        private IEnumerator CleanupRoutine_ParticleSystem(GameObject instance, ParticleSystem ps)
        {
            if (ps == null)
            {
                SafeDestroy(instance);
                yield break;
            }

            // Wait until done emitting
            while (ps != null && ps.isPlaying) yield return null;
            
            // Wait until all particles are dead
            while (ps != null && ps.particleCount > 0) yield return null;

            SafeDestroy(instance);
        }

        private IEnumerator CleanupRoutine_AudioSource(GameObject instance, AudioSource audio)
        {
            if (audio == null)
            {
                SafeDestroy(instance);
                yield break;
            }

            while (audio != null && audio.isPlaying) yield return null;

            SafeDestroy(instance);
        }

        private IEnumerator CleanupRoutine_Timer(GameObject instance, float delay)
        {
            yield return new WaitForSeconds(delay);
            SafeDestroy(instance);
        }

        private void CleanupPersistentEffectsForGift(string giftId)
        {
            // Iterate backwards to remove safely
            for (int i = _activeEffects.Count - 1; i >= 0; i--)
            {
                if (_activeEffects[i].GiftId == giftId && _activeEffects[i].IsPersistent)
                {
                    StopAndDestroyEffect(_activeEffects[i].EffectInstance);
                    _activeEffects.RemoveAt(i);
                }
            }
        }

        private void CleanupAllPersistentEffects()
        {
            foreach (var active in _activeEffects)
            {
                StopAndDestroyEffect(active.EffectInstance);
            }
            _activeEffects.Clear();
        }

        private void StopAndDestroyEffect(GameObject instance)
        {
            if (instance == null) return;

            var ps = instance.GetComponent<ParticleSystem>();
            if (ps != null) ps.Stop();

            var audio = instance.GetComponent<AudioSource>();
            if (audio != null) audio.Stop();

            SafeDestroy(instance);
        }

        private void SafeDestroy(GameObject obj)
        {
            if (obj != null) Destroy(obj);
        }

        private void PlayParticleOrAudio(GameObject obj)
        {
            var ps = obj.GetComponent<ParticleSystem>();
            if (ps != null && !ps.isPlaying) ps.Play();

            var audio = obj.GetComponent<AudioSource>();
            if (audio != null && !audio.isPlaying) audio.Play();
        }

        #endregion

        #region Helper Methods

        private Transform GetPlayerTransform()
        {
            if (GridMotionManager.Instance != null && GridMotionManager.Instance.player != null)
            {
                return GridMotionManager.Instance.player.transform;
            }
            return null;
        }

        private Vector3 GetPlayerPosition()
        {
            var t = GetPlayerTransform();
            return t != null ? t.position : Vector3.zero;
        }

        private Vector3 GetPlatformPosition(int levelIndex)
        {
            // Try to get exact platform position from manager
            if (FloorsManager.Instance != null)
            {
                // Prefer the actual GameObject position if it exists (physically instantiated)
                if (FloorsManager.Instance.GetPlatform(levelIndex, out GameObject platform))
                {
                    return platform.transform.position;
                }
                
                // Fallback to calculated Y height
                return new Vector3(0, FloorsManager.Instance.GetPlatformY(levelIndex), 0);
            }
            
            // Extreme fallback: estimate based on player
            Vector3 playerPos = GetPlayerPosition();
            return new Vector3(0, playerPos.y, 0);
        }

        #endregion
    }
}
