using UnityEngine;
using MoreMountains.Feedbacks;

namespace YF_3DGameBase
{
    [RequireComponent(typeof(HeroController))]
    public class HeroEffectsController : MonoBehaviour
    {
        [Header("Feedbacks")]
        public MMF_Player jumpFeedback;
        public MMF_Player landingFeedback;
        public MMF_Player damageFeedback;

        [Header("Landing Settings")]
        public float maxFallSpeed = 20f;
        public float minSquashForce = 0.5f;
        public float maxSquashForce = 3.0f;

        private HeroController _controller;

        private void Awake()
        {
            _controller = GetComponent<HeroController>();
        }

        private void OnEnable()
        {
            _controller.OnJumped += HandleJump;
            _controller.OnLanded += HandleLanding;
            _controller.OnDamaged += HandleDamage;
        }

        private void OnDisable()
        {
            _controller.OnJumped -= HandleJump;
            _controller.OnLanded -= HandleLanding;
            _controller.OnDamaged -= HandleDamage;
        }

        private void HandleJump()
        {
            if (jumpFeedback != null) jumpFeedback.PlayFeedbacks();
        }

        private void HandleLanding(float impactSpeed, Transform platform)
        {
            if (landingFeedback == null) return;

            float t = Mathf.InverseLerp(_controller.minFallSpeed, maxFallSpeed, impactSpeed);
            float force = Mathf.Lerp(minSquashForce, maxSquashForce, t);

            // Update MM Spring
            MMF_SpringFloat spring = landingFeedback.GetFeedbackOfType<MMF_SpringFloat>();
            if (spring != null) spring.BumpAmount = force;

            // Update Particles
            MMF_ParticlesInstantiation particles = landingFeedback.GetFeedbackOfType<MMF_ParticlesInstantiation>();
            if (particles != null && platform != null)
            {
                particles.NestParticles = true;
                particles.InstantiateParticlesPosition = platform;
                particles.Offset = transform.position - platform.position;
            }

            landingFeedback.PlayFeedbacks();
        }

        private void HandleDamage(DamageInfo info)
        {
            if (damageFeedback != null)
            {
                damageFeedback.FeedbacksIntensity = 1f;
                damageFeedback.PlayFeedbacks();
            }
        }
    }
}