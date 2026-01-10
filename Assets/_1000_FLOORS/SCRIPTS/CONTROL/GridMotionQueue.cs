using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using YF_3DGameBase;
using MoreMountains.Feedbacks;
using Douyin.YF.Live;

namespace ThousandFloors
{
    /// <summary>
    /// Manages queued grid motion requests with stacking, pausing during cutscenes, and effect lifecycle.
    /// Handles the complex logic of:
    /// - Stacking multiple gift movements (50 + 100 = 150 total)
    /// - Up/down cancellation (50 down + 10 up = net 40 down, but both effects play)
    /// - Pausing during cutscenes
    /// - Managing persistent vs one-time effects
    /// </summary>
    public class GridMotionQueue : MonoBehaviour
    {
        public static GridMotionQueue Instance { get; private set; }

        [Header("References")]
        [Tooltip("GridMotionManager is now a singleton manager. No reference needed.")]
        [System.Obsolete("GridMotionManager is now a singleton - use GridMotionManager.Instance instead")]
        [SerializeField] private GridMotionManager _gridMotionManager;

        [Header("Settings")]
        [Tooltip("If true, movements are paused automatically when cutscenes play.")]
        [SerializeField] private bool _pauseDuringCutscenes = true;

        [Header("Feedbacks")]
        [Tooltip("Camera shake feedback that plays whenever a platform breaks.")]
        [SerializeField] private MMF_Player _platformBreakCameraShake;

        // Internal state
        private int _pendingLevelDelta = 0; // Net movement to execute
        private bool _isMoving = false;
        private bool _isPaused = false;
        private List<ActiveEffect> _activeEffects = new List<ActiveEffect>();

        // Track individual gift contributions for effect management
        private struct GiftMovement
        {
            public int levelDelta;
            public string giftId;
            public List<EffectData> persistentEffects; // Effects that last during movement
            public List<EffectData> oneTimeEffects; // Effects that play once
            public List<EffectData> floorBreakEffects; // Extra effects when platform breaks during this movement
        }

        private List<GiftMovement> _queuedMovements = new List<GiftMovement>();
        
        // Track currently executing movements (for floor break effect triggers)
        // Maps giftId to their floor break effect data
        private Dictionary<string, List<EffectData>> _activeGiftFloorBreakEffects = new Dictionary<string, List<EffectData>>();

        private struct ActiveEffect
        {
            public GameObject effect;
            public bool isPersistent;
            public string giftId;
        }

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
        }

        private void OnEnable()
        {
            if (_pauseDuringCutscenes)
            {
                GlobalEvents.OnCutsceneStarted += HandleCutsceneStarted;
                GlobalEvents.OnCutsceneFinished += HandleCutsceneFinished;
            }
            
            // Listen for platform break events to trigger extra effects
            ThousandFloorsEvents.OnPlatformBroken += HandlePlatformBroken;
        }

        private void OnDisable()
        {
            GlobalEvents.OnCutsceneStarted -= HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished -= HandleCutsceneFinished;
            ThousandFloorsEvents.OnPlatformBroken -= HandlePlatformBroken;
        }

        private void HandleCutsceneStarted(string cutsceneId)
        {
            // Always set paused flag, even if movement hasn't started yet
            // This ensures queued movements won't start during the cutscene
            _isPaused = true;
            Debug.Log("[GridMotionQueue] Pausing grid motion during cutscene. IsMoving: " + _isMoving);
        }

        private void HandleCutsceneFinished(string cutsceneId)
        {
            // Resume movement and ensure processing starts if there's pending movement
            _isPaused = false;
            Debug.Log($"[GridMotionQueue] Resuming grid motion after cutscene. Pending movement: {_pendingLevelDelta}, Queued: {_queuedMovements.Count}");
            
            // If there's pending movement but the coroutine isn't running, start it
            // This handles the case where movement was queued while cutscene was playing
            if ((_pendingLevelDelta != 0 || _queuedMovements.Count > 0) && !_isMoving)
            {
                Debug.Log("[GridMotionQueue] Starting movement processing after cutscene finished.");
                StartCoroutine(ProcessMovementQueue());
            }
        }

        /// <summary>
        /// Adds a movement request to the queue. Movements are stacked (50 + 100 = 150).
        /// Effects are tracked per gift and cleaned up appropriately.
        /// </summary>
        /// <param name="levelDelta">Levels to move (positive = up, negative = down)</param>
        /// <param name="giftId">Identifier for this gift (for effect tracking)</param>
        /// <param name="persistentEffects">Effects that should persist during movement</param>
        /// <param name="oneTimeEffects">Effects that play once and clean up</param>
        /// <param name="floorBreakEffects">Extra effects to spawn when platforms break during this movement</param>
        public void QueueMovement(int levelDelta, string giftId, List<EffectData> persistentEffects = null, List<EffectData> oneTimeEffects = null, List<EffectData> floorBreakEffects = null)
        {
            Debug.Log($"[GridMotionQueue] QueueMovement called: {levelDelta} levels, giftId: {giftId}, IsMoving: {_isMoving}, IsPaused: {_isPaused}");
            
            // Add to queue
            _queuedMovements.Add(new GiftMovement
            {
                levelDelta = levelDelta,
                giftId = giftId,
                persistentEffects = persistentEffects ?? new List<EffectData>(),
                oneTimeEffects = oneTimeEffects ?? new List<EffectData>(),
                floorBreakEffects = floorBreakEffects ?? new List<EffectData>()
            });

            // Update net movement
            _pendingLevelDelta += levelDelta;

            // Get player position for effect spawning
            Vector3 playerPosition = Vector3.zero;
            Transform playerTransform = null;
            if (GridMotionManager.Instance != null && GridMotionManager.Instance.player != null)
            {
                playerTransform = GridMotionManager.Instance.player.transform;
                playerPosition = playerTransform.position;
            }

            // Play one-time effects immediately (instantiate from prefabs)
            if (oneTimeEffects != null)
            {
                foreach (var effectData in oneTimeEffects)
                {
                    if (effectData.prefab != null)
                    {
                        Vector3 spawnPos = playerPosition + effectData.offset;
                        Quaternion spawnRot = Quaternion.Euler(effectData.rotation);
                        GameObject instance = Instantiate(effectData.prefab, spawnPos, spawnRot);
                        PlayOneTimeEffect(instance, effectData.lifetime);
                    }
                }
            }

            // Start persistent effects and track them (instantiate from prefabs)
            if (persistentEffects != null)
            {
                foreach (var effectData in persistentEffects)
                {
                    if (effectData.prefab != null)
                    {
                        Vector3 spawnPos = playerPosition + effectData.offset;
                        Quaternion spawnRot = Quaternion.Euler(effectData.rotation);
                        GameObject instance = Instantiate(effectData.prefab, spawnPos, spawnRot);
                        // For persistent effects, parent to player so they follow during movement
                        // Using worldPositionStays = true so offset is preserved
                        if (playerTransform != null)
                        {
                            instance.transform.SetParent(playerTransform, true);
                            // After parenting, adjust local position to maintain offset relative to player
                            instance.transform.localPosition = effectData.offset;
                            instance.transform.localRotation = spawnRot;
                        }
                        StartPersistentEffect(instance, giftId);
                    }
                }
            }

            // Track floor break effects immediately when queued (so they're available if movement is already in progress)
            if (!string.IsNullOrEmpty(giftId) && floorBreakEffects != null && floorBreakEffects.Count > 0)
            {
                _activeGiftFloorBreakEffects[giftId] = floorBreakEffects;
                Debug.Log($"[GridMotionQueue] Tracking gift '{giftId}' floor break effects: {floorBreakEffects.Count} effects");
            }

            // Start processing if not already moving
            // Even if paused (cutscene is playing), we still start the coroutine - it will wait
            if (!_isMoving)
            {
                Debug.Log($"[GridMotionQueue] Starting ProcessMovementQueue coroutine. Pending: {_pendingLevelDelta}, Paused: {_isPaused}");
                StartCoroutine(ProcessMovementQueue());
            }
            else
            {
                Debug.Log($"[GridMotionQueue] Movement already in progress. Added to queue. Total pending: {_pendingLevelDelta}, Active gifts: {_activeGiftFloorBreakEffects.Count}");
            }
        }

        /// <summary>
        /// Processes the movement queue, handling stacking and pausing.
        /// Cleans up effects per movement when each movement completes.
        /// </summary>
        private IEnumerator ProcessMovementQueue()
        {
            _isMoving = true;
            Debug.Log($"[GridMotionQueue] Starting movement processing. Pending: {_pendingLevelDelta}, Queued: {_queuedMovements.Count}, Paused: {_isPaused}");

            while (_pendingLevelDelta != 0 || _queuedMovements.Count > 0)
            {
                // Wait if paused (during cutscene) - keep looping until unpaused
                while (_isPaused)
                {
                    yield return null;
                }

                // Double-check we still have movement (in case it was processed while paused)
                if (_pendingLevelDelta == 0 && _queuedMovements.Count == 0)
                {
                    break;
                }

                // If we have pending movement, execute it
                if (_pendingLevelDelta != 0)
                {
                    // Collect all movements that are part of this execution
                    // Since movements are stacked, we need to track all contributing gifts
                    List<GiftMovement> movementsToExecute = new List<GiftMovement>();
                    int totalMovement = _pendingLevelDelta;
                    
                    // Process all queued movements that contribute to this execution
                    // (Movements are stacked, so we execute the combined total)
                    while (_queuedMovements.Count > 0)
                    {
                        var movement = _queuedMovements[0];
                        _queuedMovements.RemoveAt(0);
                        movementsToExecute.Add(movement);
                        
                        // Track this gift as active for floor break effects
                        if (!string.IsNullOrEmpty(movement.giftId))
                        {
                            if (movement.floorBreakEffects != null && movement.floorBreakEffects.Count > 0)
                            {
                                _activeGiftFloorBreakEffects[movement.giftId] = movement.floorBreakEffects;
                                Debug.Log($"[GridMotionQueue] Marking gift '{movement.giftId}' as active with {movement.floorBreakEffects.Count} floor break effects");
                            }
                        }
                    }
                    
                    int movementToExecute = totalMovement;
                    _pendingLevelDelta = 0; // Clear before starting (new gifts will add to it)

                    Debug.Log($"[GridMotionQueue] Executing combined movement: {movementToExecute} levels from {movementsToExecute.Count} gift(s)");
                    
                    // Execute the combined movement
                    yield return StartCoroutine(ExecuteMovement(movementToExecute));
                    
                    // Movement finished - clean up persistent effects for all contributing gifts
                    foreach (var movement in movementsToExecute)
                    {
                        if (!string.IsNullOrEmpty(movement.giftId))
                        {
                            CleanupPersistentEffectsForGift(movement.giftId);
                            _activeGiftFloorBreakEffects.Remove(movement.giftId);
                            Debug.Log($"[GridMotionQueue] Movement for gift '{movement.giftId}' completed. Cleaned up effects.");
                        }
                    }
                    
                    Debug.Log($"[GridMotionQueue] Movement execution completed. Remaining pending: {_pendingLevelDelta}, Queued: {_queuedMovements.Count}, Active gifts: {_activeGiftFloorBreakEffects.Count}");
                }
                else
                {
                    yield return null;
                }
            }

            Debug.Log("[GridMotionQueue] All movement processing complete. Final cleanup.");
            
            // Final cleanup of any remaining effects (shouldn't happen, but safety net)
            CleanupAllPersistentEffects();
            _activeGiftFloorBreakEffects.Clear();
            _isMoving = false;
        }

        /// <summary>
        /// Executes a single movement, pausing if cutscene starts.
        /// </summary>
        private IEnumerator ExecuteMovement(int levelDelta)
        {
            if (GridMotionManager.Instance == null || levelDelta == 0)
            {
                yield break;
            }

            // Set pause state on GridMotionManager before starting
            GridMotionManager.Instance.IsPaused = _isPaused;
            
            // Start the movement using GridMotionManager's existing system
            GridMotionManager.Instance.MoveLevels(levelDelta);
            
            // Monitor movement and update pause state continuously
            while (GridMotionManager.Instance.IsMovingForced)
            {
                // Update pause state on GridMotionManager (in case it changed)
                GridMotionManager.Instance.IsPaused = _isPaused;
                yield return null;
            }
        }

        private void StartPersistentEffect(GameObject effect, string giftId)
        {
            if (effect == null) return;

            effect.SetActive(true);
            
            // If it's a particle system, play it
            var particleSystem = effect.GetComponent<ParticleSystem>();
            if (particleSystem != null && !particleSystem.isPlaying)
            {
                particleSystem.Play();
            }

            // If it has an AudioSource, play it
            var audioSource = effect.GetComponent<AudioSource>();
            if (audioSource != null && !audioSource.isPlaying)
            {
                audioSource.Play();
            }

            // Track it
            _activeEffects.Add(new ActiveEffect
            {
                effect = effect,
                isPersistent = true,
                giftId = giftId
            });
        }

        /// <summary>
        /// Public method to play a one-time effect with auto-cleanup.
        /// Used by other systems that need to spawn effects (e.g., player effects from gift actions).
        /// </summary>
        /// <param name="effect">The effect GameObject to play</param>
        /// <param name="lifetime">Lifetime in seconds. -1 = auto-cleanup based on component, 0 = default (5s), positive = custom lifetime.</param>
        public void PlayOneTimeEffect(GameObject effect, float lifetime = -1f)
        {
            if (effect == null) return;

            effect.SetActive(true);
            
            var particleSystem = effect.GetComponent<ParticleSystem>();
            if (particleSystem != null)
            {
                particleSystem.Play();
                // Auto-cleanup when particle system finishes (lifetime ignored for particle systems)
                StartCoroutine(CleanupOneTimeEffectWhenDone(effect, particleSystem));
            }
            else
            {
                var audioSource = effect.GetComponent<AudioSource>();
                if (audioSource != null)
                {
                    audioSource.Play();
                    // Auto-cleanup when audio finishes (lifetime ignored for audio sources)
                    StartCoroutine(CleanupOneTimeEffectWhenDone(effect, audioSource));
                }
                else
                {
                    // If no auto-cleanup component, use lifetime or default duration
                    // lifetime > 0: use custom lifetime
                    // lifetime <= 0: use default 5s
                    float cleanupDelay = lifetime > 0f ? lifetime : 5f;
                    StartCoroutine(CleanupOneTimeEffectAfterDelay(effect, cleanupDelay));
                }
            }
        }

        /// <summary>
        /// Waits for a ParticleSystem to finish playing, then cleans it up.
        /// Checks both isPlaying and particleCount to ensure all particles have finished.
        /// </summary>
        private IEnumerator CleanupOneTimeEffectWhenDone(GameObject effect, ParticleSystem ps)
        {
            if (ps == null)
            {
                CleanupEffect(effect);
                yield break;
            }

            // Wait for the particle system to stop emitting
            while (ps != null && ps.isPlaying)
            {
                yield return null;
            }

            // Wait for all particles to disappear (particleCount > 0)
            while (ps != null && ps.particleCount > 0)
            {
                yield return null;
            }

            CleanupEffect(effect);
        }

        /// <summary>
        /// Waits for an AudioSource to finish playing, then cleans it up.
        /// </summary>
        private IEnumerator CleanupOneTimeEffectWhenDone(GameObject effect, AudioSource audio)
        {
            if (audio == null)
            {
                CleanupEffect(effect);
                yield break;
            }

            // Wait for audio to finish playing
            while (audio != null && audio.isPlaying)
            {
                yield return null;
            }

            CleanupEffect(effect);
        }

        /// <summary>
        /// Fallback cleanup for effects without ParticleSystem or AudioSource.
        /// Uses a timer-based cleanup after a default duration.
        /// </summary>
        private IEnumerator CleanupOneTimeEffectAfterDelay(GameObject effect, float delay)
        {
            yield return new WaitForSeconds(delay);
            CleanupEffect(effect);
        }

        private void CleanupEffect(GameObject effect)
        {
            if (effect == null) return;

            // Stop particle systems
            var particleSystem = effect.GetComponent<ParticleSystem>();
            if (particleSystem != null)
            {
                particleSystem.Stop();
            }

            // Stop audio
            var audioSource = effect.GetComponent<AudioSource>();
            if (audioSource != null)
            {
                audioSource.Stop();
            }

            // Destroy the instantiated GameObject (since it was created from a prefab)
            Destroy(effect);
        }

        /// <summary>
        /// Handles platform break events - spawns extra effects if any active gift movements have floor break effects configured.
        /// </summary>
        private void HandlePlatformBroken(int levelIndex)
        {
            if (_platformBreakCameraShake != null)
            {
                _platformBreakCameraShake.PlayFeedbacks();
            }

            if (_activeGiftFloorBreakEffects.Count == 0) return;

            // Get actual platform position from FloorsManager
            Vector3 platformPosition = Vector3.zero;
            if (FloorsManager.Instance != null)
            {
                float platformY = FloorsManager.Instance.GetPlatformY(levelIndex);
                platformPosition = new Vector3(0, platformY, 0);
                
                // Try to get actual platform GameObject position if it exists
                if (FloorsManager.Instance.GetPlatform(levelIndex, out GameObject platform))
                {
                    platformPosition = platform.transform.position;
                }
            }
            else if (GridMotionManager.Instance != null && GridMotionManager.Instance.player != null)
            {
                // Fallback: estimate position based on player and level index
                float estimatedY = GridMotionManager.Instance.player.transform.position.y;
                if (FloorsManager.Instance != null)
                {
                    estimatedY = FloorsManager.Instance.GetPlatformY(levelIndex);
                }
                platformPosition = new Vector3(0, estimatedY, 0);
            }

            // Spawn floor break effects for all active gifts that have them configured
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

        /// <summary>
        /// Spawns floor break effects for a specific gift at the given position.
        /// </summary>
        private void SpawnFloorBreakEffects(string giftId, List<EffectData> effectDataList, Vector3 platformPosition, int levelIndex)
        {
            foreach (var effectData in effectDataList)
            {
                if (effectData.prefab != null)
                {
                    Vector3 spawnPos = platformPosition + effectData.offset;
                    Quaternion spawnRot = Quaternion.Euler(effectData.rotation);
                    GameObject instance = Instantiate(effectData.prefab, spawnPos, spawnRot);
                    PlayOneTimeEffect(instance, effectData.lifetime);
                    Debug.Log($"[GridMotionQueue] Spawned floor break effect '{effectData.prefab.name}' for gift '{giftId}' at level {levelIndex} (offset: {effectData.offset}, lifetime: {effectData.lifetime})");
                }
            }
        }

        /// <summary>
        /// Cleans up persistent effects for a specific gift.
        /// </summary>
        private void CleanupPersistentEffectsForGift(string giftId)
        {
            for (int i = _activeEffects.Count - 1; i >= 0; i--)
            {
                if (_activeEffects[i].giftId == giftId && _activeEffects[i].isPersistent)
                {
                    if (_activeEffects[i].effect != null)
                    {
                        CleanupEffect(_activeEffects[i].effect);
                    }
                    _activeEffects.RemoveAt(i);
                }
            }
        }

        private void CleanupAllPersistentEffects()
        {
            foreach (var activeEffect in _activeEffects)
            {
                if (activeEffect.effect != null)
                {
                    CleanupEffect(activeEffect.effect);
                }
            }
            _activeEffects.Clear();
        }

        /// <summary>
        /// Gets the current net pending movement (sum of all queued movements).
        /// </summary>
        public int GetPendingMovement() => _pendingLevelDelta;

        /// <summary>
        /// Returns true if grid motion is currently active (moving or queued).
        /// </summary>
        public bool IsActive() => _isMoving || _pendingLevelDelta != 0;

        /// <summary>
        /// Returns true if grid motion is currently paused (during cutscene).
        /// </summary>
        public bool IsPaused() => _isPaused;
    }
}
