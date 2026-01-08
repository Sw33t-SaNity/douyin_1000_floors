using UnityEngine;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Action that plays particle effects when a cutscene finishes.
    /// </summary>
    [CreateAssetMenu(fileName = "ParticleEffectAction", menuName = "Douyin Live/Interaction Actions/Cutscene/Particle Effect")]
    public class ParticleEffectAction : CutsceneAction
    {
        [Header("Particle Configuration")]
        [Tooltip("The particle system prefab or GameObject to instantiate/activate.")]
        public GameObject particlePrefab;

        [Tooltip("If true, instantiates a new particle system. If false, activates an existing one in the scene.")]
        public bool instantiateNew = true;

        [Tooltip("Position where the particle should appear. If null, uses Vector3.zero.")]
        public Vector3 spawnPosition;

        [Tooltip("If true, uses the hero's position as the spawn point.")]
        public bool useHeroPosition = false;

        [Tooltip("If instantiateNew is false, this is the GameObject in the scene to activate.")]
        public GameObject targetGameObject;

        public override void Execute(string cutsceneId)
        {
            Vector3 position = spawnPosition;
            
            if (useHeroPosition)
            {
                var hero = FindObjectOfType<YF_3DGameBase.HeroController>();
                if (hero != null)
                {
                    position = hero.transform.position;
                }
            }

            if (instantiateNew && particlePrefab != null)
            {
                GameObject instance = Instantiate(particlePrefab, position, Quaternion.identity);
                var particleSystem = instance.GetComponent<ParticleSystem>();
                if (particleSystem != null && !particleSystem.isPlaying)
                {
                    particleSystem.Play();
                }
            }
            else if (!instantiateNew && targetGameObject != null)
            {
                targetGameObject.transform.position = position;
                targetGameObject.SetActive(true);
                
                var particleSystem = targetGameObject.GetComponent<ParticleSystem>();
                if (particleSystem != null && !particleSystem.isPlaying)
                {
                    particleSystem.Play();
                }
            }
        }
    }
}
