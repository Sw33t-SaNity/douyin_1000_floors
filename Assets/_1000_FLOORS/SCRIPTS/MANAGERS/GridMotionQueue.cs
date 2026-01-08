using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using YF_3DGameBase;

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
            public List<GameObject> persistentEffects; // Effects that last during movement
            public List<GameObject> oneTimeEffects; // Effects that play once
        }

        private List<GiftMovement> _queuedMovements = new List<GiftMovement>();

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
        }

        private void OnDisable()
        {
            GlobalEvents.OnCutsceneStarted -= HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished -= HandleCutsceneFinished;
        }

        private void HandleCutsceneStarted(string cutsceneId)
        {
            if (_isMoving)
            {
                _isPaused = true;
                Debug.Log("[GridMotionQueue] Pausing grid motion during cutscene.");
            }
        }

        private void HandleCutsceneFinished(string cutsceneId)
        {
            if (_isPaused)
            {
                _isPaused = false;
                Debug.Log("[GridMotionQueue] Resuming grid motion after cutscene.");
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
        public void QueueMovement(int levelDelta, string giftId, List<GameObject> persistentEffects = null, List<GameObject> oneTimeEffects = null)
        {
            // Add to queue
            _queuedMovements.Add(new GiftMovement
            {
                levelDelta = levelDelta,
                giftId = giftId,
                persistentEffects = persistentEffects ?? new List<GameObject>(),
                oneTimeEffects = oneTimeEffects ?? new List<GameObject>()
            });

            // Update net movement
            _pendingLevelDelta += levelDelta;

            // Get player position for effect spawning
            Vector3 spawnPosition = Vector3.zero;
            if (GridMotionManager.Instance != null && GridMotionManager.Instance.player != null)
            {
                spawnPosition = GridMotionManager.Instance.player.transform.position;
            }

            // Play one-time effects immediately (instantiate from prefabs)
            if (oneTimeEffects != null)
            {
                foreach (var effectPrefab in oneTimeEffects)
                {
                    if (effectPrefab != null)
                    {
                        GameObject instance = Instantiate(effectPrefab, spawnPosition, Quaternion.identity);
                        PlayOneTimeEffect(instance);
                    }
                }
            }

            // Start persistent effects and track them (instantiate from prefabs)
            if (persistentEffects != null)
            {
                foreach (var effectPrefab in persistentEffects)
                {
                    if (effectPrefab != null)
                    {
                        GameObject instance = Instantiate(effectPrefab, spawnPosition, Quaternion.identity);
                        // For persistent effects, parent to player so they follow during movement
                        if (GridMotionManager.Instance != null && GridMotionManager.Instance.player != null)
                        {
                            instance.transform.SetParent(GridMotionManager.Instance.player.transform, true);
                        }
                        StartPersistentEffect(instance, giftId);
                    }
                }
            }

            // Start processing if not already moving
            if (!_isMoving)
            {
                StartCoroutine(ProcessMovementQueue());
            }
        }

        /// <summary>
        /// Processes the movement queue, handling stacking and pausing.
        /// </summary>
        private IEnumerator ProcessMovementQueue()
        {
            _isMoving = true;

            while (_pendingLevelDelta != 0 || _queuedMovements.Count > 0)
            {
                // Wait if paused (during cutscene)
                while (_isPaused)
                {
                    yield return null;
                }

                // If we have pending movement, execute it
                if (_pendingLevelDelta != 0)
                {
                    int movementToExecute = _pendingLevelDelta;
                    _pendingLevelDelta = 0; // Clear before starting (new gifts will add to it)

                    // Execute the movement
                    yield return StartCoroutine(ExecuteMovement(movementToExecute));
                }
                else
                {
                    yield return null;
                }
            }

            // Clean up all persistent effects when all movement is done
            CleanupAllPersistentEffects();
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

        private void PlayOneTimeEffect(GameObject effect)
        {
            if (effect == null) return;

            effect.SetActive(true);
            
            var particleSystem = effect.GetComponent<ParticleSystem>();
            if (particleSystem != null)
            {
                particleSystem.Play();
                // Auto-cleanup when particle system finishes
                StartCoroutine(CleanupOneTimeEffectWhenDone(effect, particleSystem));
            }
            else
            {
                var audioSource = effect.GetComponent<AudioSource>();
                if (audioSource != null)
                {
                    audioSource.Play();
                    StartCoroutine(CleanupOneTimeEffectWhenDone(effect, audioSource));
                }
                else
                {
                    // If no auto-cleanup component, clean up after a default duration
                    StartCoroutine(CleanupOneTimeEffectAfterDelay(effect, 5f));
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
