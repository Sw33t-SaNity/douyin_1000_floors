using UnityEngine;
using ByteDance.LiveOpenSdk.Push;
using ThousandFloors;
using YF_3DGameBase;

namespace Douyin.YF.Live
{
    /// <summary>
    /// GiftAction that triggers grid motion with effects.
    /// Supports both small gifts (no cutscene) and big gifts (with cutscene).
    /// Automatically handles effect lifecycle and movement stacking.
    /// </summary>
    [CreateAssetMenu(fileName = "GiftGridMotionAction", menuName = "Douyin Live/Interaction Actions/Gift/Grid Motion with Effects")]
    public class GiftGridMotionAction : GiftAction
    {
        [Header("Gift Effect Configuration")]
        [Tooltip("Effect data that defines levels to move, persistent effects, and one-time effects.")]
        public SO_GiftEffectData effectData;

        [Header("Settings")]
        [Tooltip("If true, will queue movement even if another movement is in progress (stacking).")]
        public bool allowStacking = true;

        public override void Execute(IGiftMessage data)
        {
            if (effectData == null)
            {
                Debug.LogWarning("[GiftGridMotionAction] No effect data assigned!");
                return;
            }

            if (GridMotionQueue.Instance == null)
            {
                Debug.LogWarning("[GiftGridMotionAction] GridMotionQueue instance not found! Make sure GridMotionQueue is in the scene.");
                return;
            }

            // Determine if this is a big gift (should play cutscene)
            bool isBigGift = effectData.cutsceneData != null && 
                            (effectData.minGiftValueForCutscene == 0 || 
                             data.GiftValue >= effectData.minGiftValueForCutscene);

            // Play cutscene for big gifts
            if (isBigGift && CutsceneManager.Instance != null)
            {
                CutsceneManager.Instance.PlayCutscene(effectData.cutsceneData);
            }

            // Queue grid motion with effects
            // The queue system handles stacking, pausing during cutscenes, and effect lifecycle
            // IGiftMessage only has SecGiftId, not GiftId
            string giftId = !string.IsNullOrEmpty(data.SecGiftId) ? data.SecGiftId : $"gift_{data.GiftValue}";
            GridMotionQueue.Instance.QueueMovement(
                effectData.levelsToMove,
                giftId,
                effectData.persistentEffects,
                effectData.oneTimeEffects
            );
        }
    }
}
