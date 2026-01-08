using UnityEngine;
using Douyin.YF.Live;
using ThousandFloors;

namespace YF_3DGameBase.Examples
{
    /// <summary>
    /// EXAMPLE: Demonstrates how to use the GridMotionQueue system.
    /// 
    /// SETUP:
    /// 1. Add GridMotionQueue component to a GameObject in your scene
    /// 2. Add GridMotionManager component to a GameObject and assign player reference
    /// 3. Create GiftActionData assets for each gift type:
    ///    - Right-click > Create > Douyin Live > Gift Action Data
    ///    - Configure levels to move, persistent effects, one-time effects
    ///    - Optionally assign cutscene data
    /// 4. Create GiftMotionAction assets:
    ///    - Right-click > Create > Douyin Live > Interaction Actions > Gift > Motion with Effects
    ///    - Assign your GiftActionData
    /// 5. Add GiftMotionAction to LiveInteractionConfig's gift mappings
    /// 
    /// HOW IT WORKS:
    /// - Small gifts: No cutscene, just effects + grid motion
    /// - Big gifts: Cutscene plays, then effects + grid motion (movement pauses during cutscene)
    /// - Multiple gifts: Movements stack (50 + 100 = 150 total), effects play together
    /// - Up/down cancellation: 50 down + 10 up = net 40 down, but both effects play
    /// - Effects: Persistent effects last during movement, one-time effects play once and cleanup
    /// </summary>
    public class GridMotionQueueExample : MonoBehaviour
    {
        [Header("Test Configuration")]
        public Douyin.YF.Live.GiftActionData testActionData;

        private void Update()
        {
            // Example: Press Space to test grid motion
            if (Input.GetKeyDown(KeyCode.Space) && testActionData != null && GridMotionQueue.Instance != null)
            {
                GridMotionQueue.Instance.QueueMovement(
                    testActionData.levelsToMove,
                    "test_gift",
                    testActionData.persistentEffects,
                    testActionData.oneTimeEffects
                );
            }
        }
    }
}
