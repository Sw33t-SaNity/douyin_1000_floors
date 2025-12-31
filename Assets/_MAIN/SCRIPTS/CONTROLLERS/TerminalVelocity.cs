using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class TerminalVelocity : MonoBehaviour
{
    [Tooltip("Max falling speed (Units per second). Keeps physics stable.")]
    public float maxFallSpeed = 30f; 

    private Rigidbody _rb;

    void Awake()
    {
        _rb = GetComponent<Rigidbody>();
    }

    void FixedUpdate()
    {
        // If we are falling faster than the limit...
        if (_rb.velocity.y < -maxFallSpeed)
        {
            // Clamp the Y velocity, keep X and Z the same
            _rb.velocity = new Vector3(_rb.velocity.x, -maxFallSpeed, _rb.velocity.z);
        }
    }
}