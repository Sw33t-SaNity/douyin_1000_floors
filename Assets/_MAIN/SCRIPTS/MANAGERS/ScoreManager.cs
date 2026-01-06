using UnityEngine;

namespace YF_3DGameBase
{
    public class ScoreManager : MonoBehaviour
    {
        public static ScoreManager Instance { get; protected set; }

        [Header("Settings")]
        public int initialScore = 1000;

        public int CurrentScore => _currentScore;

        protected int _currentScore;

        protected virtual void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            _currentScore = initialScore;
        }

        private void Start()
        {
            // Initial broadcast for UI initialization
            GlobalEvents.ScoreChanged(_currentScore, 0);
        }

        /// <summary>
        /// Updates the score and broadcasts the change.
        /// </summary>
        public void ChangeScore(int delta)
        {
            _currentScore += delta;
            GlobalEvents.ScoreChanged(_currentScore, delta);
        }
    }
}