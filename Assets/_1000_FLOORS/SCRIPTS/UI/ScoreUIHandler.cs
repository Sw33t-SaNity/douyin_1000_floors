using UnityEngine;
using TMPro;
using MoreMountains.Feedbacks;
using YF_3DGameBase;


namespace ThousandFloors
{
    public class ScoreUIHandler : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI _scoreText;
        [SerializeField] private MMF_Player _scoreFeedback;

        private void OnEnable()
        {
            GlobalEvents.OnScoreChanged += HandleScoreChanged;
        }

        private void OnDisable()
        {
            GlobalEvents.OnScoreChanged -= HandleScoreChanged;
        }

        private void HandleScoreChanged(int currentScore, int delta)
        {
            if (_scoreText == null) return;

            _scoreText.text = currentScore.ToString();

            if (delta != 0 && _scoreFeedback != null)
            {
                _scoreFeedback.PlayFeedbacks();
            }
        }
    }
}