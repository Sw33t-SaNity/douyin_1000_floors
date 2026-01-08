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

    /// <summary>
    /// Base class for actions that execute when a cutscene finishes.
    /// These actions can perform various effects like particle systems, grid motion, audio, etc.
    /// </summary>
    public abstract class CutsceneAction : InteractionAction
    {
        /// <summary>
        /// Executes the action when a cutscene finishes.
        /// </summary>
        /// <param name="cutsceneId">The ID of the cutscene that just finished.</param>
        public abstract void Execute(string cutsceneId);
    }
}