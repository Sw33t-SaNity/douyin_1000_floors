using UnityEngine;
using System.Collections.Generic;

namespace Douyin.YF.Live
{
    /// <summary>
    /// ScriptableObject that defines effects and behavior for a gift action.
    /// Used to configure persistent effects, one-time effects, grid motion, and optional cutscenes.
    /// </summary>
    [CreateAssetMenu(fileName = "NewGiftActionData", menuName = "Douyin Live/Gift Action Data")]
    public class GiftActionData : ScriptableObject
    {
        [Header("Grid Motion")]
        [Tooltip("Number of levels to move. Positive = up, Negative = down.")]
        public int levelsToMove = 0;

        [Header("Persistent Effects")]
        [Tooltip("Effect prefabs that persist during the entire grid motion. These will be instantiated at player position, parented to player (so they follow during movement), and cleaned up when movement finishes. Prefabs should have ParticleSystem or AudioSource components.")]
        public List<GameObject> persistentEffects = new List<GameObject>();

        [Header("One-Time Effects")]
        [Tooltip("Effect prefabs that play once when gift is received. These will be instantiated at player position and auto-cleanup when finished.\n\nAuto-Cleanup Detection:\n• ParticleSystem: Waits until isPlaying=false AND particleCount=0 (all particles disappeared)\n• AudioSource: Waits until isPlaying=false (audio clip finished)\n• Other: Falls back to 5 second timer\n\nPrefabs should have ParticleSystem or AudioSource components for proper cleanup.")]
        public List<GameObject> oneTimeEffects = new List<GameObject>();

        [Header("Cutscene (Optional)")]
        [Tooltip("If assigned, a cutscene will play when this gift is received. You decide which gifts get cutscenes.")]
        public YF_3DGameBase.SO_CutsceneData cutsceneData;
    }
}
