using UnityEngine;
using YF_3DGameBase;

namespace ThousandFloors
{
    public class CylinderCamera : MonoBehaviour, ICutsceneCameraController
    {
        [Header("Targets")]
        public Transform player;
        public Transform cylinderCenterTransform;
        
        [Header("Camera Child Reference")]
        [Tooltip("The Camera GameObject that is a child of this control rig. If null, will try to find Camera component in children.")]
        [SerializeField] private Transform _cameraChild;
        
        [Header("Settings")]
        public float distanceFromPlayer = 10f;
        public float heightOffset = 2f;
        
        [Header("Smoothing")]
        public float angleSmoothTime = 0.1f;
        public float heightSmoothTime = 0.1f;
        public float rotationSmoothTime = 0.1f;

        [Header("Grid Motion Camera Adjustment")]
        [Tooltip("Distance from the player when moving DOWN. Higher values pull the camera back (farther) while the player descends.")]
        [SerializeField] private float _gridMotionDownDistance = 12f;

        [Tooltip("Vertical offset when moving DOWN. Lower values look more at broken platforms below.")]
        [SerializeField] private float _gridMotionDownHeightOffset = 1f;

        [Tooltip("Distance from the player when moving UP. Lower values let the camera focus on what's pushing the player.")]
        [SerializeField] private float _gridMotionUpDistance = 8f;

        [Tooltip("Vertical offset when moving UP. Higher values look more at the ceiling/elevator.")]
        [SerializeField] private float _gridMotionUpHeightOffset = 3f;

        [Tooltip("How quickly the camera transitions between grid motion offsets and the default values.")]
        [SerializeField] private float _gridMotionTransitionTime = 0.3f;

        // Internal Velocity tracking for SmoothDamp
        private float currentAngleVelocity;
        private float currentHeightVelocity;
        private float _currentDistanceVelocity;
        private float _currentHeightOffsetVelocity;
        
        // Internal State
        private float _currentAngle;
        private float _currentHeight;
        private float _defaultHeightOffset;
        private float _baseDistanceFromPlayer;
        private float _currentDistanceFromPlayer;
        private float _targetDistanceFromPlayer;
        private float _currentHeightOffset;
        private float _targetHeightOffset;
        private bool _controllerActive = true;

        void Start()
        {
            // Find camera child if not assigned
            if (_cameraChild == null)
            {
                Camera cam = GetComponentInChildren<Camera>();
                if (cam != null)
                {
                    _cameraChild = cam.transform;
                    Debug.Log($"[CylinderCamera] Found camera child: {_cameraChild.name}");
                }
                else
                {
                    Debug.LogWarning("[CylinderCamera] No camera child found. Will update this transform instead.");
                }
            }
            
            _defaultHeightOffset = heightOffset;
            _baseDistanceFromPlayer = distanceFromPlayer;
            InitializeCameraTargets();
            SnapPosition(); // Auto-snap on start to prevent first-frame jitter
        }

        private void OnEnable()
        {
            ThousandFloorsEvents.OnHeroMoveStarted += HandleHeroMoveStarted;
            ThousandFloorsEvents.OnHeroMoveCompleted += HandleHeroMoveCompleted;
            
            // Reset offsets when re-enabled so the camera returns to its gameplay position
            ResetCameraOffsetsToDefault();
            
            // Snap camera position immediately when re-enabled (e.g., after cutscene)
            // This ensures the camera is immediately positioned correctly instead of waiting for LateUpdate
            if (player != null)
            {
                SnapPosition();
            }
        }

        private void OnDisable()
        {
            ThousandFloorsEvents.OnHeroMoveStarted -= HandleHeroMoveStarted;
            ThousandFloorsEvents.OnHeroMoveCompleted -= HandleHeroMoveCompleted;
        }

        void LateUpdate()
        {
            if (player == null || !enabled || !_controllerActive) return;

            // Update base values from inspector at runtime (in case they're changed)
            // Only update if we're at default targets (not in grid motion)
            if (Mathf.Approximately(_targetDistanceFromPlayer, _baseDistanceFromPlayer) && 
                Mathf.Approximately(_targetHeightOffset, _defaultHeightOffset))
            {
                _baseDistanceFromPlayer = distanceFromPlayer;
                _defaultHeightOffset = heightOffset;
                _targetDistanceFromPlayer = distanceFromPlayer;
                _targetHeightOffset = heightOffset;
            }

            _currentDistanceFromPlayer = Mathf.SmoothDamp(
                _currentDistanceFromPlayer,
                _targetDistanceFromPlayer,
                ref _currentDistanceVelocity,
                _gridMotionTransitionTime
            );

            _currentHeightOffset = Mathf.SmoothDamp(
                _currentHeightOffset,
                _targetHeightOffset,
                ref _currentHeightOffsetVelocity,
                _gridMotionTransitionTime
            );

            Vector3 origin = GetOrigin();

            // 1. Calculate Target Angle/Height
            Vector3 playerDir = player.position - origin;
            float targetAngle = Mathf.Atan2(playerDir.z, playerDir.x) * Mathf.Rad2Deg;
            float targetHeight = player.position.y + _currentHeightOffset;

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

            // Update base values from inspector (important for runtime changes)
            _baseDistanceFromPlayer = distanceFromPlayer;
            _defaultHeightOffset = heightOffset;

            // Initialize camera targets with current inspector values
            InitializeCameraTargets();
            
            // Reset velocities
            currentAngleVelocity = 0f;
            currentHeightVelocity = 0f;
            _currentDistanceVelocity = 0f;
            _currentHeightOffsetVelocity = 0f;

            Vector3 origin = GetOrigin();
            Vector3 playerDir = player.position - origin;

            // 1. Force internal state to match player NOW
            _currentAngle = Mathf.Atan2(playerDir.z, playerDir.x) * Mathf.Rad2Deg;
            _currentHeight = player.position.y + _currentHeightOffset;
            _currentDistanceFromPlayer = _targetDistanceFromPlayer;
            _currentHeightOffset = _targetHeightOffset;

            // 2. Apply immediately
            ApplyPosition(origin, _currentAngle, _currentHeight);
            
            // Instant look at player
            Transform targetTransform = _cameraChild != null ? _cameraChild : transform;
            targetTransform.LookAt(player.position);
            
            Debug.Log($"[CylinderCamera] Snapped position. Distance: {_currentDistanceFromPlayer}, Height Offset: {_currentHeightOffset}, Active: {_controllerActive}, Camera Child: {(_cameraChild != null ? _cameraChild.name : "none")}");
        }

        private void InitializeCameraTargets()
        {
            _targetDistanceFromPlayer = _baseDistanceFromPlayer;
            _currentDistanceFromPlayer = _baseDistanceFromPlayer;
            _targetHeightOffset = _defaultHeightOffset;
            _currentHeightOffset = _defaultHeightOffset;
            _currentDistanceVelocity = 0f;
            _currentHeightOffsetVelocity = 0f;
        }

        private void ResetCameraOffsetsToDefault()
        {
            _targetDistanceFromPlayer = _baseDistanceFromPlayer;
            _targetHeightOffset = _defaultHeightOffset;
            _currentDistanceVelocity = 0f;
            _currentHeightOffsetVelocity = 0f;
        }

        private void SetGridMotionTargets(float distance, float heightOffset)
        {
            _targetDistanceFromPlayer = distance;
            _targetHeightOffset = heightOffset;
        }

        public void SetControllerActive(bool active)
        {
            if (_controllerActive == active) return;

            Debug.Log($"[CylinderCamera] SetControllerActive called: {active} (was {_controllerActive})");
            
            _controllerActive = active;
            
            if (active)
            {
                // Update base values from inspector before resetting
                _baseDistanceFromPlayer = distanceFromPlayer;
                _defaultHeightOffset = heightOffset;
                ResetCameraOffsetsToDefault();

                if (player != null)
                {
                    // Force immediate snap to ensure camera is in correct position
                    SnapPosition();
                }
            }
        }

        public bool IsControllerActive => _controllerActive;

        // --- HELPERS ---

        Vector3 GetOrigin()
        {
            return (cylinderCenterTransform != null) ? cylinderCenterTransform.position : Vector3.zero;
        }

        void ApplyPosition(Vector3 origin, float angleDeg, float height)
        {
            float rad = angleDeg * Mathf.Deg2Rad;
            Vector3 newPos = new Vector3(
                origin.x + Mathf.Cos(rad) * _currentDistanceFromPlayer,
                height,
                origin.z + Mathf.Sin(rad) * _currentDistanceFromPlayer
            );
            
            // Update the camera child if it exists, otherwise update this transform
            if (_cameraChild != null)
            {
                _cameraChild.position = newPos;
            }
            else
            {
                transform.position = newPos;
            }
        }

        void ApplyRotation()
        {
            if (player == null) return;
            
            // Determine which transform to rotate (camera child or this transform)
            Transform targetTransform = _cameraChild != null ? _cameraChild : transform;
            Vector3 targetPosition = targetTransform.position;
            
            Quaternion targetRotation = Quaternion.LookRotation(player.position - targetPosition);
            Quaternion currentRotation = targetTransform.rotation;
            Quaternion smoothedRotation = Quaternion.Slerp(currentRotation, targetRotation, rotationSmoothTime);
            
            targetTransform.rotation = smoothedRotation;
        }

        #region Grid Motion Event Handlers
        
        /// <summary>
        /// Handles grid motion start - adjusts camera Z offset based on direction.
        /// </summary>
        private void HandleHeroMoveStarted(int startLevel, int targetLevel)
        {
            int levelDelta = targetLevel - startLevel;

            if (levelDelta < 0)
            {
                SetGridMotionTargets(_gridMotionDownDistance, _gridMotionDownHeightOffset);
                Debug.Log($"[CylinderCamera] Grid motion DOWN detected ({levelDelta} levels). Adjusting distance to {_gridMotionDownDistance} and height offset to {_gridMotionDownHeightOffset}.");
            }
            else if (levelDelta > 0)
            {
                SetGridMotionTargets(_gridMotionUpDistance, _gridMotionUpHeightOffset);
                Debug.Log($"[CylinderCamera] Grid motion UP detected ({levelDelta} levels). Adjusting distance to {_gridMotionUpDistance} and height offset to {_gridMotionUpHeightOffset}.");
            }
        }

        /// <summary>
        /// Handles grid motion completion - resets camera Z offset to neutral.
        /// </summary>
        private void HandleHeroMoveCompleted(int startLevel, int targetLevel)
        {
            ResetCameraOffsetsToDefault();
            Debug.Log("[CylinderCamera] Grid motion completed. Restoring default distance/height offsets.");
        }
        
        #endregion
    }
}