using UnityEngine;
using ByteDance.LiveOpenSdk.Push;
using ThousandFloors;
using YF_3DGameBase;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Unified GiftAction that handles all gift behaviors: effects, grid motion, and cutscenes.
    /// Every gift uses this single action type - the only difference is the configuration in GiftActionData.
    /// </summary>
    [CreateAssetMenu(fileName = "ThousandFloorGiftAction", menuName = "Douyin Live/Interaction Actions/Gift/Thousand Floor Gift Action")]
    public class ThousandFloorGiftAction : GiftAction
    {
        [Header("Action Configuration")]
        [Tooltip("Action data that defines levels to move, persistent effects, one-time effects, and optional cutscene.")]
        public GiftActionData actionData;

        public override void Execute(IGiftMessage data)
        {
            if (actionData == null)
            {
                Debug.LogWarning("[ThousandFloorGiftAction] No action data assigned!");
                return;
            }

            // Play cutscene if assigned (with queuing support)
            if (actionData.cutsceneData != null && CutsceneManager.Instance != null)
            {
                if (actionData.queueCutscene)
                {
                    // Queue the cutscene to play after current one finishes
                    CutsceneManager.Instance.QueueCutscene(actionData.cutsceneData);
                }
                else
                {
                    // Try to play immediately (will fail if one is already playing)
                    CutsceneManager.Instance.PlayCutscene(actionData.cutsceneData);
                }
            }

            // Queue grid motion with effects (only if there's actual movement or effects to process)
            // The queue system handles stacking, pausing during cutscenes, and effect lifecycle
            bool hasMovement = actionData.levelsToMove != 0;
            bool hasEffects = (actionData.persistentEffects != null && actionData.persistentEffects.Count > 0) ||
                              (actionData.oneTimeEffects != null && actionData.oneTimeEffects.Count > 0) ||
                              (actionData.floorBreakEffects != null && actionData.floorBreakEffects.Count > 0);

            if (hasMovement || hasEffects)
            {
                if (GridMotionQueue.Instance == null)
                {
                    Debug.LogWarning("[ThousandFloorGiftAction] GridMotionQueue instance not found! Make sure GridMotionQueue is in the scene.");
                    return;
                }

                string giftId = !string.IsNullOrEmpty(data.SecGiftId) ? data.SecGiftId : $"gift_{data.GiftValue}";
                GridMotionQueue.Instance.QueueMovement(
                    actionData.levelsToMove,
                    giftId,
                    actionData.persistentEffects,
                    actionData.oneTimeEffects,
                    actionData.floorBreakEffects
                );
            }
        }
    }
}
