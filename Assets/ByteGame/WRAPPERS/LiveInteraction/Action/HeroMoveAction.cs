using UnityEngine;
using ThousandFloors;
using ByteDance.LiveOpenSdk.Push;

namespace Douyin.YF.Live.ThousandFloors
{
    [CreateAssetMenu(fileName = "HeroMoveAction", menuName = "Douyin Live/Interaction Actions/Gift/Hero Move")]
    public class HeroMoveAction : GiftAction
    {
        public int levelsToMove = 1;

        public override void Execute(IGiftMessage data)
        {
            // Use singleton manager
            if (HeroGridMotion.Instance != null)
            {
                HeroGridMotion.Instance.MoveLevels(levelsToMove);
            }
            else
            {
                Debug.LogWarning("[HeroMoveAction] HeroGridMotion.Instance not found! Make sure HeroGridMotion manager is in the scene.");
            }
        }
    }
}