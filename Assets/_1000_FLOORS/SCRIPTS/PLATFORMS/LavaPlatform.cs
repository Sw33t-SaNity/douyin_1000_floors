using UnityEngine;

public class LavaPlatform : MonoBehaviour, IPlatform
{
    public int damage = -1;
    public float knockUpForce = 15f;
    
    // Physics Interface
    public Vector3 GetVelocity() { return Vector3.zero; }
    public void ResetState() { }

    public void OnStand(GameObject subject)
    {
        var receiver = subject.GetComponent<IDataReceiver>();
        if (receiver != null)
        {
            // CONTEXT: "Push UP, Ignore Collision (True), Stun 0.5s"
            DamageData info = new DamageData(
                Vector3.up * knockUpForce, 
                true, 
                0.5f,
                false
            );

            receiver.OnReceive(ResourceType.Health, damage, info);
        }
    }
}