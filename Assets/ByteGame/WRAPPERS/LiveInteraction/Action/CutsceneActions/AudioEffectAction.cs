using UnityEngine;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Action that plays audio when a cutscene finishes.
    /// </summary>
    [CreateAssetMenu(fileName = "AudioEffectAction", menuName = "Douyin Live/Interaction Actions/Cutscene/Audio Effect")]
    public class AudioEffectAction : CutsceneAction
    {
        [Header("Audio Configuration")]
        [Tooltip("Audio clip to play.")]
        public AudioClip audioClip;

        [Tooltip("Volume (0-1).")]
        [Range(0f, 1f)]
        public float volume = 1f;

        [Tooltip("If true, plays at the hero's position. If false, plays at Vector3.zero.")]
        public bool playAtHeroPosition = false;

        public override void Execute(string cutsceneId)
        {
            if (audioClip == null)
            {
                Debug.LogWarning("[AudioEffectAction] No audio clip assigned!");
                return;
            }

            Vector3 position = Vector3.zero;
            if (playAtHeroPosition)
            {
                var hero = FindObjectOfType<YF_3DGameBase.HeroController>();
                if (hero != null)
                {
                    position = hero.transform.position;
                }
            }

            AudioSource.PlayClipAtPoint(audioClip, position, volume);
        }
    }
}
