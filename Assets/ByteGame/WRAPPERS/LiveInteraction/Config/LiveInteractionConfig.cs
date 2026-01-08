using UnityEngine;
using System.Collections.Generic;
using System;
using Douyin.YF.Live;

namespace Douyin.YF.Live
{
    [CreateAssetMenu(fileName = "LiveInteractionConfig", menuName = "Live/Interaction Config")]
    public class LiveInteractionConfig : ScriptableObject
    {
        [Header("Gift Mappings")]
        public List<GiftMapping> giftActions;

        [Header("Comment Keyword Mappings")]
        public List<CommentMapping> commentActions;

        [Header("Like Milestone Mappings")]
        public List<LikeMilestoneMapping> likeMilestones;

        [Serializable]
        public struct GiftMapping
        {
            public string giftName;
            public string giftId;
            public GiftAction action;
        }

        [Serializable]
        public struct CommentMapping
        {
            public string keyword;
            public CommentAction action;
        }

        [Serializable]
        public struct LikeMilestoneMapping
        {
            public int threshold;
            public LikeAction action;
        }
    }
}