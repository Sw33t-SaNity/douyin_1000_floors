using System.Collections.Generic;
using UnityEngine;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Action that executes multiple other actions in sequence when a cutscene finishes.
    /// Useful for combining effects, motion, and audio together.
    /// </summary>
    [CreateAssetMenu(fileName = "MultiAction", menuName = "Douyin Live/Interaction Actions/Cutscene/Multi Action")]
    public class MultiAction : CutsceneAction
    {
        [Header("Action List")]
        [Tooltip("List of actions to execute when this action is triggered.")]
        public List<CutsceneAction> actions = new List<CutsceneAction>();

        [Header("Execution Settings")]
        [Tooltip("If true, stops executing if one action fails. If false, continues with remaining actions.")]
        public bool stopOnError = false;

        public override void Execute(string cutsceneId)
        {
            if (actions == null || actions.Count == 0)
            {
                Debug.LogWarning("[MultiAction] No actions assigned!");
                return;
            }

            foreach (var action in actions)
            {
                if (action == null) continue;

                try
                {
                    action.Execute(cutsceneId);
                }
                catch (System.Exception e)
                {
                    Debug.LogError($"[MultiAction] Error executing action {action.name}: {e}");
                    if (stopOnError) break;
                }
            }
        }
    }
}
