using UnityEngine;
using YF_3DGameBase;

namespace YF_3DGameBase.Examples
{
    /// <summary>
    /// EXAMPLE: This script demonstrates how to use the cutscene system.
    /// 
    /// SIMPLIFIED ARCHITECTURE:
    /// Everything is configured in GiftActionData - one asset per gift type.
    /// 
    /// SETUP STEPS:
    /// 1. Create a CutsceneManager GameObject in your scene (or it will auto-create)
    /// 2. Create a SO_CutsceneData asset for each unique cutscene (optional)
    ///    - Right-click > Create > YF_3DGameBase > Cutscene Data
    ///    - Assign a Timeline asset to it
    ///    - Give it a unique cutsceneId
    /// 3. For each gift type, create a GiftActionData asset:
    ///    - Right-click > Create > Douyin Live > Gift Action Data
    ///    - Configure: levelsToMove, persistentEffects, oneTimeEffects
    ///    - Optionally assign cutsceneData (for "big" gifts with cutscenes)
    ///    - Set queueCutscene=true to queue (plays after current) or false to skip if one is playing
    /// 4. Create a UnifiedGiftAction asset:
    ///    - Right-click > Create > Douyin Live > Interaction Actions > Gift > Unified Gift Action
    ///    - Assign your GiftActionData
    /// 5. Add to LiveInteractionConfig's gift mappings
    /// 
    /// HOW IT WORKS:
    /// - Gift received → UnifiedGiftAction executes
    /// - Cutscene queued/played (if configured)
    /// - Grid motion + effects queued (pauses during cutscene)
    /// - Effects play during motion, cleanup when motion finishes
    /// 
    /// ALTERNATIVE: You can also trigger cutscenes directly from code:
    /// </summary>
    public class CutsceneUsageExample : MonoBehaviour
    {
        [Header("Example: Direct Cutscene Playback")]
        [Tooltip("Assign a cutscene data asset to test direct playback.")]
        public SO_CutsceneData testCutscene;

        private void Update()
        {
            // Example: Press Space to play cutscene directly (for testing)
            if (Input.GetKeyDown(KeyCode.Space) && testCutscene != null)
            {
                if (CutsceneManager.Instance != null)
                {
                    CutsceneManager.Instance.PlayCutscene(testCutscene);
                }
            }

            // Example: Press Escape to stop current cutscene
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                if (CutsceneManager.Instance != null && CutsceneManager.Instance.IsPlayingCutscene)
                {
                    CutsceneManager.Instance.StopCutscene();
                }
            }
        }

        // Example: Subscribe to cutscene events
        private void OnEnable()
        {
            GlobalEvents.OnCutsceneStarted += OnCutsceneStarted;
            GlobalEvents.OnCutsceneFinished += OnCutsceneFinished;
        }

        private void OnDisable()
        {
            GlobalEvents.OnCutsceneStarted -= OnCutsceneStarted;
            GlobalEvents.OnCutsceneFinished -= OnCutsceneFinished;
        }

        private void OnCutsceneStarted(string cutsceneId)
        {
            Debug.Log($"Cutscene '{cutsceneId}' started! You can do things like hide UI, play music, etc.");
        }

        private void OnCutsceneFinished(string cutsceneId)
        {
            Debug.Log($"Cutscene '{cutsceneId}' finished!");
            // Grid motion will automatically resume (it was paused during cutscene)
            // Effects continue to play during the motion
        }
    }
}
