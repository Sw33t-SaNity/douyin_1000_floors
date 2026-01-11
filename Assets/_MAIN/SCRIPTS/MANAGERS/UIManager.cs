using UnityEngine;
using TMPro;
using MoreMountains.Feedbacks;
using ThousandFloors;

namespace YF_3DGameBase
{
    public class UIManager : MonoBehaviour
    {
        public static UIManager Instance { get; private set; }

        [Header("Score UI")]
        [SerializeField] private TextMeshProUGUI _scoreText;
        [Tooltip("Triggered when the player makes progress (score decreases)")]
        [SerializeField] private MMF_Player _scoreProgressFeedback;
        [Tooltip("Triggered when the player hits a penalty (score increases)")]
        [SerializeField] private MMF_Player _scoreSetbackFeedback;
        [Header("Floating Text")]
        [Tooltip("Feedback containing an MMF_FloatingText component to show the delta")]
        [SerializeField] private MMF_Player _addScoreFeedback;

        [Header("Floating Text Colors")]
        [Tooltip("Color used when the player makes progress (score decreases)")]
        [SerializeField] private Gradient _progressGradient = new Gradient();
        [Tooltip("Color used when the player hits a penalty (score increases)")]
        [SerializeField] private Gradient _setbackGradient = new Gradient();

        [Header("Combo Settings")]
        [Tooltip("Time window in seconds to group score changes into a combo")]
        [SerializeField] private float _comboWindow = 0.8f;

        [Header("Cutscene Behaviour")]
        [Tooltip("UI elements to hide during cutscenes")]
        [SerializeField] private GameObject[] _hideOnCutscene;
        [Tooltip("If true, feedbacks will not play during cutscenes")]
        [SerializeField] private bool _pauseFeedbacksDuringCutscene = true;
        
        private float _lastScoreTime;
        private int _accumulatedDelta;
        private bool _isInCutscene = false;
        private bool[] _wasActiveBeforeCutscene;
        private bool _wasScoreTextActive;

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
            ThousandFloorsEvents.OnScoreChanged += HandleScoreChanged;
            GlobalEvents.OnScoreChanged += UpdateScoreText;
            GlobalEvents.OnCutsceneStarted += HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished += HandleCutsceneFinished;
        }

        private void OnDisable()
        {
            ThousandFloorsEvents.OnScoreChanged -= HandleScoreChanged;
            GlobalEvents.OnScoreChanged -= UpdateScoreText;
            GlobalEvents.OnCutsceneStarted -= HandleCutsceneStarted;
            GlobalEvents.OnCutsceneFinished -= HandleCutsceneFinished;
        }

        private void Start()
        {
            if (_scoreText != null && ScoreManager.Instance != null)
            {
                _scoreText.text = ScoreManager.Instance.CurrentScore.ToString();
            }
        }

        private void UpdateScoreText(int currentScore, int delta)
        {
            if (_scoreText != null) _scoreText.text = currentScore.ToString();
        }

        private void HandleScoreChanged(int delta, Vector3 worldPos, bool isProgress)
        {
            if (_scoreText == null || ScoreManager.Instance == null) return;

            // Skip feedbacks during cutscenes if configured
            if (_isInCutscene && _pauseFeedbacksDuringCutscene) return;

            // delta < 0 means progress (remaining floors decreasing)
            if (isProgress && _scoreProgressFeedback != null)
                _scoreProgressFeedback.PlayFeedbacks();
            else if (!isProgress && _scoreSetbackFeedback != null)
                _scoreSetbackFeedback.PlayFeedbacks();

            // Handle Floating Text
            if (delta != 0 && _addScoreFeedback != null)
            {
                // Combo Logic: Accumulate if within window and same direction (both positive or both negative)
                bool sameDirection = _accumulatedDelta != 0 && Mathf.Sign(delta) == Mathf.Sign(_accumulatedDelta);
                
                if (Time.time - _lastScoreTime < _comboWindow && sameDirection)
                {
                    _accumulatedDelta += delta;
                }
                else
                {
                    _accumulatedDelta = delta;
                }
                _lastScoreTime = Time.time;

                MMF_FloatingText floatingText = _addScoreFeedback.GetFeedbackOfType<MMF_FloatingText>();
                if (floatingText != null)
                {
                    floatingText.Value = _accumulatedDelta > 0 ? $"+{_accumulatedDelta}" : _accumulatedDelta.ToString();
                    floatingText.ForceColor = true;
                    floatingText.AnimateColorGradient = isProgress ? _progressGradient : _setbackGradient;
                }

                // Position the feedback at the event location (e.g., between platforms)
                _addScoreFeedback.transform.position = worldPos;
                _addScoreFeedback.PlayFeedbacks();
            }
        }

        #region Cutscene Handling
        private void HandleCutsceneStarted(string cutsceneId)
        {
            _isInCutscene = true;
            
            // Hide UI elements
            if (_hideOnCutscene != null && _hideOnCutscene.Length > 0)
            {
                _wasActiveBeforeCutscene = new bool[_hideOnCutscene.Length];
                for (int i = 0; i < _hideOnCutscene.Length; i++)
                {
                    if (_hideOnCutscene[i] != null)
                    {
                        _wasActiveBeforeCutscene[i] = _hideOnCutscene[i].activeSelf;
                        _hideOnCutscene[i].SetActive(false);
                    }
                }
            }
            
            // Hide ScoreText if it exists
            if (_scoreText != null)
            {
                _wasScoreTextActive = _scoreText.gameObject.activeSelf;
                _scoreText.gameObject.SetActive(false);
            }
            
            Debug.Log($"[UIManager] Cutscene '{cutsceneId}' started - UI hidden, feedbacks paused");
        }

        private void HandleCutsceneFinished(string cutsceneId)
        {
            _isInCutscene = false;
            
            // Restore UI elements
            if (_hideOnCutscene != null && _wasActiveBeforeCutscene != null)
            {
                for (int i = 0; i < _hideOnCutscene.Length; i++)
                {
                    if (_hideOnCutscene[i] != null && i < _wasActiveBeforeCutscene.Length && _wasActiveBeforeCutscene[i])
                    {
                        _hideOnCutscene[i].SetActive(true);
                    }
                }
            }
            
            // Restore ScoreText if it was active before cutscene
            if (_scoreText != null && _wasScoreTextActive)
            {
                _scoreText.gameObject.SetActive(true);
            }
            
            // Reset combo state after cutscene
            _accumulatedDelta = 0;
            
            Debug.Log($"[UIManager] Cutscene '{cutsceneId}' finished - UI restored, feedbacks resumed");
        }
        
        /// <summary>
        /// Returns true if a cutscene is currently playing.
        /// </summary>
        public bool IsInCutscene => _isInCutscene;
        #endregion
    }
}