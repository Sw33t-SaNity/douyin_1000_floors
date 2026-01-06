using UnityEngine;

namespace YF_3DGameBase
{
    [System.Serializable]
    public class DamageInfo
    {
        public Vector3 knockbackForce;    // Direction * Strength
        public bool ignoreGroundCollision; // True for Spikes (Ghost Mode), False for Enemies
        public float stunDuration;        // How long player loses control (e.g. 0.5s)
        public bool resetMomentum;
        // Helper Constructor
        public DamageInfo(Vector3 force, bool ignoreGround, float stun, bool reset = false)
        {
            knockbackForce = force;
            ignoreGroundCollision = ignoreGround;
            stunDuration = stun;
            resetMomentum = reset;
        }
    }
}