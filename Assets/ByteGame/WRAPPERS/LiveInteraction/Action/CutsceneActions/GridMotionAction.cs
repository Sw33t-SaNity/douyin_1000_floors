using UnityEngine;
using ThousandFloors;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Action that moves the hero up or down levels when a cutscene finishes.
    /// Uses GridMotionQueue for proper stacking and effect management.
    /// 
    /// NOTE: For gift-triggered movements with effects, use GiftMotionAction instead.
    /// This action is for cutscene-triggered movements only.
    /// </summary>
    [CreateAssetMenu(fileName = "GridMotionAction", menuName = "Douyin Live/Interaction Actions/Cutscene/Grid Motion")]
    public class GridMotionAction : CutsceneAction
    {
        [Header("Movement Configuration")]
        [Tooltip("Number of levels to move. Positive = up, Negative = down.")]
        public int levelsToMove = 1;

        [Header("Settings")]
        [Tooltip("If true, uses GridMotionQueue (recommended for stacking). If false, uses direct GridMotionManager.")]
        public bool useQueue = true;

        public override void Execute(string cutsceneId)
        {
            if (useQueue && GridMotionQueue.Instance != null)
            {
                // Use queue system for proper stacking
                GridMotionQueue.Instance.QueueMovement(levelsToMove, $"cutscene_{cutsceneId}", null, null);
            }
            else
            {
                // Fallback to direct movement (using singleton)
                if (GridMotionManager.Instance != null)
                {
                    GridMotionManager.Instance.MoveLevels(levelsToMove);
                }
                else
                {
                    Debug.LogWarning("[GridMotionAction] GridMotionManager.Instance not found! Make sure GridMotionManager is in the scene.");
                }
            }
        }
    }
}
