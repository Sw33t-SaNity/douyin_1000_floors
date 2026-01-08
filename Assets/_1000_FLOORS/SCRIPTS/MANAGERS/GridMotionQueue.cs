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
        [Tooltip("HeroGridMotion is now a singleton manager. No reference needed.")]
        [System.Obsolete("HeroGridMotion is now a singleton - use HeroGridMotion.Instance instead")]
        [SerializeField] private HeroGridMotion _heroGridMotion;

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

            // Play one-time effects immediately
            if (oneTimeEffects != null)
            {
                foreach (var effect in oneTimeEffects)
                {
                    if (effect != null)
                    {
                        PlayOneTimeEffect(effect);
                    }
                }
            }

            // Start persistent effects and track them
            if (persistentEffects != null)
            {
                foreach (var effect in persistentEffects)
                {
                    if (effect != null)
                    {
                        StartPersistentEffect(effect, giftId);
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
            if (HeroGridMotion.Instance == null || levelDelta == 0)
            {
                yield break;
            }

            // Set pause state on HeroGridMotion before starting
            HeroGridMotion.Instance.IsPaused = _isPaused;
            
            // Start the movement using HeroGridMotion's existing system
            HeroGridMotion.Instance.MoveLevels(levelDelta);
            
            // Monitor movement and update pause state continuously
            while (HeroGridMotion.Instance.IsMovingForced)
            {
                // Update pause state on HeroGridMotion (in case it changed)
                HeroGridMotion.Instance.IsPaused = _isPaused;
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

        private IEnumerator CleanupOneTimeEffectWhenDone(GameObject effect, ParticleSystem ps)
        {
            while (ps != null && ps.isPlaying)
            {
                yield return null;
            }
            CleanupEffect(effect);
        }

        private IEnumerator CleanupOneTimeEffectWhenDone(GameObject effect, AudioSource audio)
        {
            while (audio != null && audio.isPlaying)
            {
                yield return null;
            }
            CleanupEffect(effect);
        }

        private IEnumerator CleanupOneTimeEffectAfterDelay(GameObject effect, float delay)
        {
            yield return new WaitForSeconds(delay);
            CleanupEffect(effect);
        }

        private void CleanupEffect(GameObject effect)
        {
            if (effect == null) return;

            effect.SetActive(false);
            
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
