using UnityEngine;
using ByteDance.LiveOpenSdk.Push;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Base class for all game responses to live events.
    /// </summary>
    public abstract class InteractionAction : ScriptableObject
    {
    }

    public abstract class GiftAction : InteractionAction
    {
        public abstract void Execute(IGiftMessage data);
    }

    public abstract class CommentAction : InteractionAction
    {
        public abstract void Execute(ICommentMessage data);
    }

    public abstract class LikeAction : InteractionAction
    {
        public abstract void Execute(ILikeMessage data);
    }
}