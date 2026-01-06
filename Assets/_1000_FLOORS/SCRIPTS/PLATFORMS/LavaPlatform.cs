using UnityEngine;
using YF_3DGameBase;

namespace ThousandFloors
{
    public class LavaPlatform : MonoBehaviour, IPlatform
    {
        public float damage = -1;
        public float knockUpForce = 15f;
        
        // Physics Interface
        public Vector3 GetVelocity() { return Vector3.zero; }
        public void ResetState() { }

        public void OnStand(GameObject subject)
        {
            var receiver = subject.GetComponent<I_DataReceiver>();
            if (receiver != null)
            {
                // CONTEXT: "Push UP, Ignore Collision (True), Stun 0.5s"
                DamageInfo info = new DamageInfo(
                    Vector3.up * knockUpForce, 
                    true, 
                    0.5f,
                    false
                );

                receiver.OnReceive(ResourceType.Health, amount: damage, info: info);
            }
        }
    }
}