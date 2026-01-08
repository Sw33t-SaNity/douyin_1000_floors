using UnityEngine;
using UnityEngine.Playables;
using System.Collections;

namespace YF_3DGameBase
{
    /// <summary>
    /// Singleton manager that handles cutscene playback using Unity Timeline.
    /// Provides a decoupled interface for playing any cutscene without direct coupling to other systems.
    /// Automatically manages input locking and game state during cutscenes.
    /// </summary>
    public class CutsceneManager : MonoBehaviour
    {
        public static CutsceneManager Instance { get; private set; }

        [Header("Configuration")]
        [Tooltip("The PlayableDirector component that will play cutscenes. If null, one will be created.")]
        [SerializeField] private PlayableDirector _playableDirector;

        [Tooltip("If true, automatically lock input when cutscenes start and unlock when they finish.")]
        [SerializeField] private bool _autoManageInput = true;

        private bool _isPlayingCutscene = false;
        private string _currentCutsceneId = "";
        private SO_CutsceneData _currentCutsceneData;

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

            // Set time scale if needed
            if (cutsceneData.pauseGameTime)
            {
                Time.timeScale = 0f;
            }

            // Play the timeline
            _playableDirector.playableAsset = cutsceneData.timelineAsset;
            _playableDirector.time = 0f;
            _playableDirector.Play();

            // Fire start event
            GlobalEvents.CutsceneStarted(_currentCutsceneId);

            // Start coroutine to monitor completion
            StartCoroutine(MonitorCutsceneCompletion());

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
            // Wait for the timeline to finish
            while (_playableDirector != null && 
                   _playableDirector.state == PlayState.Playing && 
                   _playableDirector.time < _playableDirector.duration)
            {
                yield return null;
            }

            // Timeline finished
            FinishCutscene();
        }

        private void FinishCutscene()
        {
            if (!_isPlayingCutscene) return;

            string finishedId = _currentCutsceneId;

            // Restore time scale if it was paused
            if (_currentCutsceneData != null && _currentCutsceneData.pauseGameTime)
            {
                Time.timeScale = 1f;
            }

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

        private void HandleCutsceneFinished(string cutsceneId)
        {
            // Optional: Handle cutscene finish (e.g., cleanup, effects)
            Debug.Log($"[CutsceneManager] Cutscene '{cutsceneId}' finished.");
        }
    }
}
