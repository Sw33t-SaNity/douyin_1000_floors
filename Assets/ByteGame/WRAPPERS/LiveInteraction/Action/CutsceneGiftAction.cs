using UnityEngine;
using ByteDance.LiveOpenSdk.Push;
using YF_3DGameBase;

namespace Douyin.YF.Live
{
    /// <summary>
    /// GiftAction that plays a cutscene when a gift is received.
    /// Create an instance of this ScriptableObject and assign it to a gift mapping in LiveInteractionConfig.
    /// </summary>
    [CreateAssetMenu(fileName = "CutsceneGiftAction", menuName = "Douyin Live/Interaction Actions/Gift/Play Cutscene")]
    public class CutsceneGiftAction : GiftAction
    {
        [Header("Cutscene Configuration")]
        [Tooltip("The cutscene data asset that defines which Timeline to play.")]
        public SO_CutsceneData cutsceneData;

        [Header("Optional Settings")]
        [Tooltip("If true, will only play if no cutscene is currently playing.")]
        public bool skipIfCutscenePlaying = true;

        public override void Execute(IGiftMessage data)
        {
            if (cutsceneData == null)
            {
                Debug.LogWarning("[CutsceneGiftAction] No cutscene data assigned!");
                return;
            }

            if (CutsceneManager.Instance == null)
            {
                Debug.LogWarning("[CutsceneGiftAction] CutsceneManager instance not found! Make sure CutsceneManager is in the scene.");
                return;
            }

            // Check if we should skip
            if (skipIfCutscenePlaying && CutsceneManager.Instance.IsPlayingCutscene)
            {
                Debug.Log($"[CutsceneGiftAction] Skipping cutscene '{cutsceneData.cutsceneId}' because another cutscene is already playing.");
                return;
            }

            // Play the cutscene
            bool success = CutsceneManager.Instance.PlayCutscene(cutsceneData);
            if (!success)
            {
                Debug.LogWarning($"[CutsceneGiftAction] Failed to play cutscene '{cutsceneData.cutsceneId}'.");
            }
        }
    }
}
