using UnityEngine;
using YF_3DGameBase;

namespace ThousandFloors
{
    public class CylinderCamera : MonoBehaviour
    {
        [Header("Targets")]
        public Transform player;
        public Transform cylinderCenterTransform; 

        [Header("Settings")]
        public float distanceFromPlayer = 10f;
        public float heightOffset = 2f;
        
        [Header("Smoothing")]
        public float angleSmoothTime = 0.1f;
        public float heightSmoothTime = 0.1f;
        public float rotationSmoothTime = 0.1f;

        // Internal Velocity tracking for SmoothDamp
        private float currentAngleVelocity;
        private float currentHeightVelocity;
        
        // Internal State
        private float _currentAngle;
        private float _currentHeight;

        void Start()
        {
            SnapPosition(); // Auto-snap on start to prevent first-frame jitter
        }

        private void OnEnable()
        {
        }

        private void OnDisable()
        {
        }

        void LateUpdate()
        {
            if (player == null) return;

            Vector3 origin = GetOrigin();

            // 1. Calculate Target Angle/Height
            Vector3 playerDir = player.position - origin;
            float targetAngle = Mathf.Atan2(playerDir.z, playerDir.x) * Mathf.Rad2Deg;
            float targetHeight = player.position.y + heightOffset;

            // 2. Handle Wrapping (Shortest path across 180/-180 boundary)
            float deltaAngle = Mathf.DeltaAngle(_currentAngle, targetAngle);
            float continuousTargetAngle = _currentAngle + deltaAngle;

            // 3. Smooth (Always use smoothing to respect settings, even during forced moves)
            _currentAngle = Mathf.SmoothDamp(_currentAngle, continuousTargetAngle, ref currentAngleVelocity, angleSmoothTime);
            _currentHeight = Mathf.SmoothDamp(_currentHeight, targetHeight, ref currentHeightVelocity, heightSmoothTime);

            // 4. Apply
            ApplyPosition(origin, _currentAngle, _currentHeight);
            ApplyRotation();
        }

        // --- EDITOR TOOLS ---

        [ContextMenu("Snap Camera Position")]
        public void SnapPosition()
        {
            if (player == null) 
            {
                Debug.LogError("CylinderCamera: Assign Player first!");
                return;
            }

            Vector3 origin = GetOrigin();
            Vector3 playerDir = player.position - origin;

            // 1. Force internal state to match player NOW
            _currentAngle = Mathf.Atan2(playerDir.z, playerDir.x) * Mathf.Rad2Deg;
            _currentHeight = player.position.y + heightOffset;

            // 2. Reset velocities so it doesn't drift
            currentAngleVelocity = 0f;
            currentHeightVelocity = 0f;

            // 3. Apply immediately
            ApplyPosition(origin, _currentAngle, _currentHeight);
            transform.LookAt(player.position); // Instant look
        }

        // --- HELPERS ---

        Vector3 GetOrigin()
        {
            return (cylinderCenterTransform != null) ? cylinderCenterTransform.position : Vector3.zero;
        }

        void ApplyPosition(Vector3 origin, float angleDeg, float height)
        {
            float rad = angleDeg * Mathf.Deg2Rad;
            Vector3 newPos = new Vector3(
                origin.x + Mathf.Cos(rad) * distanceFromPlayer,
                height,
                origin.z + Mathf.Sin(rad) * distanceFromPlayer
            );
            transform.position = newPos;
        }

        void ApplyRotation()
        {
            if (player == null) return;
            Quaternion targetRotation = Quaternion.LookRotation(player.position - transform.position);
            transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, rotationSmoothTime);
        }
    }
}