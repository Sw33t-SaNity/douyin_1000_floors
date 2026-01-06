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
        
        private float _lastScoreTime;
        private int _accumulatedDelta;

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
        }

        private void OnDisable()
        {
            ThousandFloorsEvents.OnScoreChanged -= HandleScoreChanged;
            GlobalEvents.OnScoreChanged -= UpdateScoreText;
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
    }
}