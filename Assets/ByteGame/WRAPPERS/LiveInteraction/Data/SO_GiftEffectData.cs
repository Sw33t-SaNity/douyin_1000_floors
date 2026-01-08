using UnityEngine;
using System.Collections.Generic;

namespace Douyin.YF.Live
{
    /// <summary>
    /// ScriptableObject that defines effects and behavior for a gift.
    /// Used to configure persistent effects, one-time effects, and grid motion.
    /// </summary>
    [CreateAssetMenu(fileName = "NewGiftEffect", menuName = "Douyin Live/Gift Effect Data")]
    public class SO_GiftEffectData : ScriptableObject
    {
        [Header("Gift Identity")]
        [Tooltip("Gift ID this effect data applies to.")]
        public string giftId;

        [Header("Grid Motion")]
        [Tooltip("Number of levels to move. Positive = up, Negative = down.")]
        public int levelsToMove = 0;

        [Header("Persistent Effects")]
        [Tooltip("Effects that persist during the entire grid motion. Cleaned up when movement finishes.")]
        public List<GameObject> persistentEffects = new List<GameObject>();

        [Header("One-Time Effects")]
        [Tooltip("Effects that play once when gift is received. Auto-cleanup when finished.")]
        public List<GameObject> oneTimeEffects = new List<GameObject>();

        [Header("Cutscene (Big Gifts)")]
        [Tooltip("If assigned, a cutscene will play for big value gifts.")]
        public YF_3DGameBase.SO_CutsceneData cutsceneData;

        [Header("Settings")]
        [Tooltip("Minimum gift value to trigger cutscene. If 0, cutscene always plays if assigned.")]
        public long minGiftValueForCutscene = 1000;
    }
}
