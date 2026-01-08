using UnityEngine;

namespace ThousandFloors
{
    /// <summary>
    /// Attached to the procedurally generated trigger on each platform.
    /// Handles scoring for natural (non-forced) movement.
    /// </summary>
    [RequireComponent(typeof(BoxCollider))]
    public class ScoringTrigger : MonoBehaviour
    {
        [HideInInspector] public int levelIndex;

        private void OnTriggerExit(Collider other)
        {
            // 1. Only respond to the Player tag
            if (!other.CompareTag("Player")) 
                return;

            // 2. Check if the player is currently in a forced grid move
            // HeroGridMotion is now a singleton manager
            if (HeroGridMotion.Instance != null && HeroGridMotion.Instance.IsMovingForced) 
                return;

            // 3. Natural Progress: Player fell through the gap or jumped off
            // We only count it as progress if they are moving DOWN (velocity.y < 0)
            // or if they simply exited the bottom of the trigger volume.
            if (other.attachedRigidbody != null && other.attachedRigidbody.velocity.y < 0.1f)
            {
                // Use the player's current position so the number appears exactly where they are falling
                ThousandFloorsEvents.ScoreChanged(-1, other.transform.position, true);
                ThousandFloorsEvents.PlatformBroken(levelIndex);
            }
        }
    }
}