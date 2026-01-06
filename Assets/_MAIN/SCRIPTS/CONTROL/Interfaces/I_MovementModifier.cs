using UnityEngine;
namespace YF_3DGameBase
{
    public interface I_MovementModifier
    {
        // Returns the calculated Velocity vector based on input
        Vector3 CalculateVelocity(Rigidbody rb, Vector2 input, float speed, float acceleration);
        
        // Optional: Can we rotate?
        bool ShouldHandleRotation();
        // NEW: Add this line
        void HandleRotation(Rigidbody rb, Vector2 input, float rotationSpeed);

        bool CanJump();
        Vector3 GetVisualVelocity();
    
    }
}