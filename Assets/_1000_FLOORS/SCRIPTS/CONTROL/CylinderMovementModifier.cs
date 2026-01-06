using UnityEngine;
using YF_3DGameBase;

namespace ThousandFloors
{
    public class CylinderMovementModifier : MonoBehaviour, I_MovementModifier
    {
        public Transform cylinderCenter;

        [Header("Cylinder Constraint")]
        [Tooltip("The actual radius of the platform.")]
        public float fixedRadius = 5.0f;

        private Rigidbody _rb;
        private bool _isLocked;
        private float _currentAngularVelocity;

        void Awake()
        {
            _rb = GetComponent<Rigidbody>();
            if (_rb == null) Debug.LogError("Missing Rigidbody!", this);
        }

        private void OnEnable()
        {
            GlobalEvents.OnToggleInputLock += HandleInputLock;
        }

        private void OnDisable()
        {
            GlobalEvents.OnToggleInputLock -= HandleInputLock;
        }

        private void HandleInputLock(bool isLocked)
        {
            _isLocked = isLocked;
            if (isLocked) _currentAngularVelocity = 0f;
        }

        public Vector3 CalculateVelocity(Rigidbody rb, Vector2 input, float baseSpeed, float accel)
        {
            if (cylinderCenter == null || fixedRadius < 0.001f) 
                return new Vector3(0, rb.velocity.y, 0);

            // Target angular velocity (deg/s)
            // If input.x is positive (right), we rotate cylinder negative Y to move platform left under player.
            float targetAngularVel = (input.x * baseSpeed / fixedRadius) * Mathf.Rad2Deg;

            // Smoothly approach target angular velocity
            float accelDeg = (accel / fixedRadius) * Mathf.Rad2Deg;
            _currentAngularVelocity = Mathf.MoveTowards(_currentAngularVelocity, targetAngularVel, accelDeg * Time.fixedDeltaTime);

            // Apply rotation to cylinder
            cylinderCenter.Rotate(Vector3.up, _currentAngularVelocity * Time.fixedDeltaTime);

            // Return zero velocity for XZ to keep player stationary relative to camera
            return new Vector3(0, rb.velocity.y, 0);
        }

        /// <summary>
        /// Returns the linear velocity equivalent of the cylinder's rotation.
        /// Used by the Animator to play running animations while the player is world-space stationary.
        /// </summary>
        public Vector3 GetVisualVelocity()
        {
            float linearSpeed = Mathf.Abs(_currentAngularVelocity) * Mathf.Deg2Rad * fixedRadius;
            return new Vector3(linearSpeed, 0, 0);
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

        public bool CanJump()
        {
            return false;
        }

        void FixedUpdate()
        {
            if (_isLocked) return; // Pause radius constraint during forced grid movement
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
}