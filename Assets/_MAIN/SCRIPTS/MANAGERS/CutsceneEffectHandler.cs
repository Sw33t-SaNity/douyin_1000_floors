using UnityEngine;
using System.Collections.Generic;
using Douyin.YF.Live;

namespace YF_3DGameBase
{
    /// <summary>
    /// Component that listens to cutscene completion events and executes actions.
    /// Uses the InteractionAction pattern to allow flexible, modular responses to cutscene finishes.
    /// Actions can include particle effects, grid motion, audio, or any custom behavior.
    /// 
    /// Usage: 
    /// 1. Add this component to a GameObject in your scene
    /// 2. Create CutsceneAction ScriptableObjects (ParticleEffectAction, GridMotionAction, etc.)
    /// 3. Map cutscene IDs to lists of actions that should execute when those cutscenes finish
    /// </summary>
    public class CutsceneEffectHandler : MonoBehaviour
    {
        [System.Serializable]
        public class CutsceneActionMapping
        {
            [Tooltip("The cutscene ID that triggers these actions.")]
            public string cutsceneId;

            [Tooltip("Actions to execute when this cutscene finishes. Can be particle effects, grid motion, audio, or any custom action.")]
            public List<CutsceneAction> actions = new List<CutsceneAction>();
        }

        [Header("Cutscene Action Mappings")]
        [Tooltip("Map cutscene IDs to actions that should execute when they finish.")]
        [SerializeField] private List<CutsceneActionMapping> _actionMappings = new List<CutsceneActionMapping>();

        [Header("Settings")]
        [Tooltip("If true, logs when actions are executed. Useful for debugging.")]
        [SerializeField] private bool _enableLogging = true;

        private Dictionary<string, List<CutsceneAction>> _actionLookup;

        private void Awake()
        {
            // Build lookup dictionary for fast access
            _actionLookup = new Dictionary<string, List<CutsceneAction>>();
            foreach (var mapping in _actionMappings)
            {
                if (!string.IsNullOrEmpty(mapping.cutsceneId) && mapping.actions != null && mapping.actions.Count > 0)
                {
                    _actionLookup[mapping.cutsceneId] = mapping.actions;
                }
            }
        }

        private void OnEnable()
        {
            GlobalEvents.OnCutsceneFinished += HandleCutsceneFinished;
        }

        private void OnDisable()
        {
            GlobalEvents.OnCutsceneFinished -= HandleCutsceneFinished;
        }

        private void HandleCutsceneFinished(string cutsceneId)
        {
            if (_actionLookup == null || !_actionLookup.ContainsKey(cutsceneId))
            {
                return;
            }

            List<CutsceneAction> actions = _actionLookup[cutsceneId];
            if (actions == null || actions.Count == 0) return;

            int executedCount = 0;
            foreach (CutsceneAction action in actions)
            {
                if (action == null) continue;

                try
                {
                    action.Execute(cutsceneId);
                    executedCount++;
                }
                catch (System.Exception e)
                {
                    Debug.LogError($"[CutsceneEffectHandler] Error executing action '{action.name}' for cutscene '{cutsceneId}': {e}");
                }
            }

            if (_enableLogging)
            {
                Debug.Log($"[CutsceneEffectHandler] Executed {executedCount} action(s) for cutscene '{cutsceneId}'.");
            }
        }

        /// <summary>
        /// Manually trigger actions for a specific cutscene ID (useful for testing).
        /// </summary>
        public void TriggerActionsForCutscene(string cutsceneId)
        {
            HandleCutsceneFinished(cutsceneId);
        }

        /// <summary>
        /// Adds a new action mapping at runtime (useful for dynamic cutscenes).
        /// </summary>
        public void AddActionMapping(string cutsceneId, CutsceneAction action)
        {
            if (string.IsNullOrEmpty(cutsceneId) || action == null) return;

            if (!_actionLookup.ContainsKey(cutsceneId))
            {
                _actionLookup[cutsceneId] = new List<CutsceneAction>();
            }

            _actionLookup[cutsceneId].Add(action);
        }
    }
}
