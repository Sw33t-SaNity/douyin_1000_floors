using UnityEngine;
using YF_3DGameBase;

namespace ThousandFloors
{
    public class MovingSectorPlatform : BasePlatform
    {
        public int scoreValue = 1;
        private bool _hasGivenScore;
        private GameObject _subjectOnPlatform;
        

        public override void OnStand(GameObject subject)
        {
            // Player has landed on the platform.
            // They are now eligible for a score when they jump off.
            // Optimization: Only arm the platform if the object is actually the player.
            if (!subject.CompareTag("Player")) return;

            _subjectOnPlatform = subject;
            _hasGivenScore = false; // Allow score to be given again for a new stand.
        }

        private void OnTriggerEnter(Collider other)
        {
            // Arm the platform if the player enters the trigger, even if they don't land (airborne pass)
            if (!_hasGivenScore && _subjectOnPlatform == null)
            {
                // Check for the "Player" tag to ignore other falling objects.
                if (other.CompareTag("Player") && other.GetComponent<I_DataReceiver>() != null)
                {
                    _subjectOnPlatform = other.gameObject;
                }
            }
        }

        private void OnTriggerExit(Collider other)
        {
            // Scoring is now handled by the specialized ScoringTrigger component
        }

        public override void ResetState()
        {
            base.ResetState();
            StopAllCoroutines();
            
            _hasGivenScore = false;
            _subjectOnPlatform = null;
        }
    }
}