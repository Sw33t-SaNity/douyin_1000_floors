using System;

namespace YF_3DGameBase
{
    public static class GlobalEvents
    {
        /// <summary>
        /// Event fired when the player's input should be locked or unlocked.
        /// true = locked, false = unlocked.
        /// </summary>
        public static event Action<bool> OnToggleInputLock;

        public static void ToggleInputLock(bool isLocked)
        {
            OnToggleInputLock?.Invoke(isLocked);
        }

        /// <summary>
        /// Event fired when the floors remaining count changes.
        /// Passes (int currentScore, int delta).
        /// </summary>
        public static event Action<int, int> OnScoreChanged;

        public static void ScoreChanged(int currentScore, int delta)
        {
            OnScoreChanged?.Invoke(currentScore, delta);
        }

        #region Cutscene Events
        /// <summary>
        /// Event fired when a cutscene starts playing.
        /// Passes the cutscene ID/name for identification.
        /// </summary>
        public static event Action<string> OnCutsceneStarted;

        /// <summary>
        /// Event fired when a cutscene finishes playing.
        /// Passes the cutscene ID/name for identification.
        /// </summary>
        public static event Action<string> OnCutsceneFinished;

        public static void CutsceneStarted(string cutsceneId)
        {
            OnCutsceneStarted?.Invoke(cutsceneId);
        }

        public static void CutsceneFinished(string cutsceneId)
        {
            OnCutsceneFinished?.Invoke(cutsceneId);
        }
        #endregion
    }
}