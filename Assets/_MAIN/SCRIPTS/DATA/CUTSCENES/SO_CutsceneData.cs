using UnityEngine;
using UnityEngine.Playables;

namespace YF_3DGameBase
{
    /// <summary>
    /// ScriptableObject that holds a Timeline asset reference and metadata for a cutscene.
    /// Create instances of this to define cutscenes that can be played by CutsceneManager.
    /// </summary>
    [CreateAssetMenu(fileName = "NewCutscene", menuName = "YF_3DGameBase/Cutscene Data")]
    public class SO_CutsceneData : ScriptableObject
    {
        [Header("Cutscene Identity")]
        [Tooltip("Unique identifier for this cutscene. Used in events and logging.")]
        public string cutsceneId;

        [Header("Timeline Asset")]
        [Tooltip("The PlayableDirector asset (Timeline) to play for this cutscene.")]
        public PlayableAsset timelineAsset;

        [Header("Settings")]
        [Tooltip("If true, the cutscene will pause gameplay (via timeScale or physics, based on CutsceneManager settings).")]
        public bool pauseGameTime = true;

        [Tooltip("If true, the cutscene will automatically restore input when finished.")]
        public bool autoRestoreInput = true;

        [Header("Optional")]
        [Tooltip("Optional description for this cutscene (for organization).")]
        [TextArea(2, 4)]
        public string description;
    }
}
