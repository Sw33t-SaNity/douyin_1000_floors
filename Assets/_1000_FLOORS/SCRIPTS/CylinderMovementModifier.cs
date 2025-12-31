using UnityEngine;

public class CylinderMovementModifier : MonoBehaviour, IMovementModifier
{
    public Transform cylinderCenter;

    [Header("Cylinder Constraint")]
    [Tooltip("The actual radius of the platform.")]
    public float fixedRadius = 5.0f;

    private Rigidbody _rb;

    void Awake()
    {
        _rb = GetComponent<Rigidbody>();
        if (_rb == null) Debug.LogError("Missing Rigidbody!", this);
    }

    public Vector3 CalculateVelocity(Rigidbody rb, Vector2 input, float baseSpeed, float accel)
    {
        if (cylinderCenter == null) return Vector3.zero;

        // 1. Calculate Direction from Center
        Vector3 directionFromCenter = rb.position - cylinderCenter.position;
        directionFromCenter.y = 0; 
        directionFromCenter.Normalize();

        // 2. Calculate Tangent (Left/Right direction)
        Vector3 tangent = Vector3.Cross(Vector3.up, directionFromCenter);
        
        // 3. Simple Target Direction
        Vector3 targetDirection = (tangent * -input.x).normalized;

        // 4. Simple Velocity (No scaling, just pure speed)
        Vector3 targetVelocity = targetDirection * baseSpeed;

        // 5. Apply Acceleration
        Vector3 currentFlatVel = new Vector3(rb.velocity.x, 0, rb.velocity.z);
        
        // NOTE: If movement feels "slidey" or slow to start, increase 'Acceleration' in HeroController
        return Vector3.MoveTowards(currentFlatVel, targetVelocity, accel * Time.fixedDeltaTime);
    }

    public void HandleRotation(Rigidbody rb, Vector2 input, float rotationSpeed)
    {
        if (Mathf.Abs(input.x) < 0.1f) return;
        if (cylinderCenter == null) return;

        Vector3 directionFromCenter = rb.position - cylinderCenter.position;
        directionFromCenter.y = 0;
        directionFromCenter.Normalize();

        Vector3 tangent = Vector3.Cross(Vector3.up, directionFromCenter);
        
        // Look along the tangent
        Vector3 lookDirection = tangent * -input.x;

        if (lookDirection != Vector3.zero)
        {
            Quaternion targetRotation = Quaternion.LookRotation(lookDirection.normalized, Vector3.up);
            rb.MoveRotation(Quaternion.RotateTowards(rb.rotation, targetRotation, rotationSpeed * Time.fixedDeltaTime));
        }
    }

    public bool ShouldHandleRotation() 
    {
        return true; 
    }

    void FixedUpdate()
    {
        if (cylinderCenter == null || _rb == null) return;

        Vector3 directionFromCenter = _rb.position - cylinderCenter.position;
        directionFromCenter.y = 0;

        if (directionFromCenter.sqrMagnitude < 0.0001f) return;

        // 
        // Lock player to the fixedRadius
        Vector3 correctedPosition = cylinderCenter.position + directionFromCenter.normalized * fixedRadius;
        correctedPosition.y = _rb.position.y;
        
        _rb.MovePosition(correctedPosition);
    }
}