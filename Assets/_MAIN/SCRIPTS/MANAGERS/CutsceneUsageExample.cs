using UnityEngine;
using YF_3DGameBase;

namespace YF_3DGameBase.Examples
{
    /// <summary>
    /// EXAMPLE: This script demonstrates how to use the cutscene system.
    /// 
    /// SETUP STEPS:
    /// 1. Create a CutsceneManager GameObject in your scene (or it will auto-create)
    /// 2. Create a SO_CutsceneData asset (Right-click > Create > YF_3DGameBase > Cutscene Data)
    ///    - Assign a Timeline asset to it
    ///    - Give it a unique cutsceneId (e.g., "GiftCelebration")
    /// 3. To trigger from gifts:
    ///    - Create a CutsceneGiftAction asset (Right-click > Create > Douyin Live > Interaction Actions > Gift > Play Cutscene)
    ///    - Assign your SO_CutsceneData to it
    ///    - Add it to your LiveInteractionConfig's gift mappings
    /// 4. To execute actions after cutscene finishes:
    ///    - Add CutsceneEffectHandler component to a GameObject
    ///    - Create CutsceneAction assets (ParticleEffectAction, GridMotionAction, AudioEffectAction, etc.)
    ///    - Map cutscene IDs to lists of actions in CutsceneEffectHandler
    ///    - Actions can include: particle effects, grid motion, audio, or custom behaviors
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
            Debug.Log($"Cutscene '{cutsceneId}' finished! Actions are automatically executed via CutsceneEffectHandler.");
            
            // NOTE: For effects, use CutsceneAction ScriptableObjects instead of code here.
            // This keeps the system modular and decoupled. Examples:
            // - ParticleEffectAction: Plays particle systems
            // - GridMotionAction: Moves hero up/down levels
            // - AudioEffectAction: Plays sound effects
            // - MultiAction: Combines multiple actions
            //
            // All actions are configured in CutsceneEffectHandler component.
        }
    }
}
