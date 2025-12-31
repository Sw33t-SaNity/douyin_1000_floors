using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public abstract class BasePlatform : MonoBehaviour, IPlatform
{
    // --- SHARED PHYSICS LOGIC ---
    protected Rigidbody _rb;
    private Vector3 _currentVelocity;
    private Vector3 _lastPosition;

    protected virtual void Awake()
    {
        _rb = GetComponent<Rigidbody>();
    }

    protected virtual void FixedUpdate()
    {
        // Calculate physics velocity for the player to inherit
        _currentVelocity = (transform.position - _lastPosition) / Time.fixedDeltaTime;
        _lastPosition = transform.position;
    }

    public Vector3 GetVelocity()
    {
        return _currentVelocity;
    }

    // --- ABSTRACT METHODS ---
    // Force the child classes to define their own behavior
    public abstract void OnStand(GameObject subject);

    public virtual void ResetState()
    {
        _lastPosition = transform.position;
        _currentVelocity = Vector3.zero;
        // Child classes can override this if they need to reset more flags
    }
}