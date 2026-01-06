using UnityEngine;
using YF_3DGameBase;

namespace ThousandFloors
{
    /// <summary>
    /// Manages the 1000-floor countdown logic.
    /// </summary>
    public class ScoreManager : YF_3DGameBase.ScoreManager
    {
        // Aliases for project-specific naming
        public int floorsRemaining => CurrentScore;
        public int totalProgress => initialScore - CurrentScore;

        protected override void Awake()
        {
            base.Awake();
        }

        private void OnEnable()
        {
            ThousandFloorsEvents.OnScoreChanged += HandleScoreChanged;
        }

        private void OnDisable()
        {
            ThousandFloorsEvents.OnScoreChanged -= HandleScoreChanged;
        }

        private void HandleScoreChanged(int delta, Vector3 worldPos, bool isProgress)
        {
            // delta is -1 for progress (moving down), +1 for setback (moving up)
            ChangeScore(delta);
            Debug.Log($"[Score] Delta: {delta} | Remaining: {floorsRemaining}");
            
            // Update UI here if you have a UI reference
            // UIManager.Instance.UpdateFloors(floorsRemaining);
        }
    }
}