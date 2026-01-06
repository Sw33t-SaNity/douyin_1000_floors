using UnityEngine;
using System;

namespace ThousandFloors
{
    /// <summary>
    /// Central hub for broadcasting and listening to events specific to the Thousand Floors game.
    /// </summary>
    public static class ThousandFloorsEvents
    {
        #region Grid Motion
        public static event Action<int, int> OnHeroMoveStarted; // (startLevel, targetLevel)
        public static event Action<int, int> OnHeroMoveCompleted; // (startLevel, targetLevel)

        public static void HeroMoveStarted(int start, int target) => OnHeroMoveStarted?.Invoke(start, target);
        public static void HeroMoveCompleted(int start, int target) => OnHeroMoveCompleted?.Invoke(start, target);
        #endregion

        #region Platform State
        public static event Action<int, bool> OnPlatformStateRequest; // (levelIndex, shouldBeVisible)
        public static event Action<int> OnPlatformBroken; // (levelIndex)

        public static void RequestPlatformState(int level, bool visible) => OnPlatformStateRequest?.Invoke(level, visible);
        public static void PlatformBroken(int level) => OnPlatformBroken?.Invoke(level);
        #endregion

        #region Scoring & Feedback
        /// <summary>
        /// Broadcasts a score change.
        /// </summary>
        /// <param name="delta">The amount changed.</param>
        /// <param name="worldPosition">Where the feedback (floating text) should appear.</param>
        /// <param name="isProgress">True if moving down (progress), false if moving up (setback).</param>
        public static event Action<int, Vector3, bool> OnScoreChanged;

        public static void ScoreChanged(int delta, Vector3 worldPosition, bool isProgress) 
            => OnScoreChanged?.Invoke(delta, worldPosition, isProgress);
        #endregion
    }
}