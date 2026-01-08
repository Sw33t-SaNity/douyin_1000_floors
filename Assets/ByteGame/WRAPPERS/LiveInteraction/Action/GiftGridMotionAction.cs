using UnityEngine;
using ByteDance.LiveOpenSdk.Push;
using ThousandFloors;
using YF_3DGameBase;

namespace Douyin.YF.Live
{
    /// <summary>
    /// GiftAction that triggers grid motion with effects and optional cutscene.
    /// Automatically handles effect lifecycle and movement stacking.
    /// </summary>
    [CreateAssetMenu(fileName = "GiftMotionAction", menuName = "Douyin Live/Interaction Actions/Gift/Motion with Effects")]
    public class GiftMotionAction : GiftAction
    {
        [Header("Action Configuration")]
        [Tooltip("Action data that defines levels to move, persistent effects, one-time effects, and optional cutscene.")]
        public GiftActionData actionData;

        public override void Execute(IGiftMessage data)
        {
            if (actionData == null)
            {
                Debug.LogWarning("[GiftMotionAction] No action data assigned!");
                return;
            }

            if (GridMotionQueue.Instance == null)
            {
                Debug.LogWarning("[GiftMotionAction] GridMotionQueue instance not found! Make sure GridMotionQueue is in the scene.");
                return;
            }

            // Play cutscene if assigned (you decide which gifts get cutscenes in the data asset)
            if (actionData.cutsceneData != null && CutsceneManager.Instance != null)
            {
                CutsceneManager.Instance.PlayCutscene(actionData.cutsceneData);
            }

            // Queue grid motion with effects
            // The queue system handles stacking, pausing during cutscenes, and effect lifecycle
            string giftId = !string.IsNullOrEmpty(data.SecGiftId) ? data.SecGiftId : $"gift_{data.GiftValue}";
            GridMotionQueue.Instance.QueueMovement(
                actionData.levelsToMove,
                giftId,
                actionData.persistentEffects,
                actionData.oneTimeEffects
            );
        }
    }
}
