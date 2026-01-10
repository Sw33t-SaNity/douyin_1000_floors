using UnityEngine;
using System.Collections;
using YF_3DGameBase;

namespace ThousandFloors
{
    /// <summary>
    /// Singleton manager that handles forced, kinematic movement of the hero between grid levels (vertical floors).
    /// Used for "Fast Travel" or level skipping mechanics.
    /// </summary>
    public class GridMotionManager : MonoBehaviour
    {
        public static GridMotionManager Instance { get; private set; }

        #region Inspector Settings
        [Header("References")]
        [Tooltip("The player GameObject that will be moved. Must have Rigidbody, Collider, Animator, and HeroController components.")]
        public GameObject player;

        [Header("Movement Settings")]
        [Tooltip("Vertical speed in units per second.")]
        public float moveSpeed = 20f;
        
        [Tooltip("Curve to smooth the start and end of the movement.")]
        public AnimationCurve motionCurve = AnimationCurve.EaseInOut(0, 0, 1, 1);

        [Header("Animation Keys")]
        [SerializeField] private string animOnGroundBool = "Is_Onground";
        [SerializeField] private string animKinematicBool = "IsKinematic";
        [SerializeField] private string animVelocityFloat = "VerticalVelocity";
        #endregion

        #region Constants & Internal State
        // Offset to ensure we land slightly above the platform to prevent physics clipping
        private const float LANDING_OFFSET_Y = 0.05f; 
        private const float DEFAULT_MOVE_DURATION = 0.5f;
        // Determines how early before the platform we trigger the "Crossed Level" event
        private const float LEVEL_CHECK_OFFSET_RATIO = 0.25f;

        private Rigidbody _rb;
        private Collider _col;
        private Animator _anim;
        private CylinderMovementModifier _cylinderModifier;
        private Transform _playerTransform;

        /// <summary>
        /// Returns true if the hero is currently executing a forced grid move.
        /// </summary>
        public bool IsMovingForced { get; private set; }

        /// <summary>
        /// If true, movement will pause (used during cutscenes).
        /// </summary>
        public bool IsPaused { get; set; }
        #endregion

        #region Unity Lifecycle
        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;

            IsMovingForced = false;
        }

        void Start()
        {
            // Initialize player references
            if (player == null)
            {
                // Try to find player by tag
                GameObject foundPlayer = GameObject.FindGameObjectWithTag("Player");
                if (foundPlayer != null)
                {
                    player = foundPlayer;
                }
                else
                {
                    Debug.LogWarning("[GridMotionManager] Player reference not set and no GameObject with 'Player' tag found!");
                }
            }

            if (player != null)
            {
                InitializePlayerReferences();
            }
        }

        private void InitializePlayerReferences()
        {
            _playerTransform = player.transform;
            _rb = player.GetComponent<Rigidbody>();
            _col = player.GetComponent<Collider>();
            _anim = player.GetComponent<Animator>();
            _cylinderModifier = player.GetComponent<CylinderMovementModifier>();

            if (_rb == null)
            {
                Debug.LogError("[GridMotionManager] Player GameObject must have a Rigidbody component!");
            }
            if (_col == null)
            {
                Debug.LogError("[GridMotionManager] Player GameObject must have a Collider component!");
            }
        }
        #endregion

        #region Public API
        /// <summary>
        /// Initiates the movement sequence to move the player up or down by a specific number of levels.
        /// </summary>
        /// <param name="levelDelta">Positive for up, negative for down.</param>
        public void MoveLevels(int levelDelta)
        {
            if (levelDelta == 0)
            {
                Debug.LogWarning("[GridMotionManager] MoveLevels called with 0 delta - ignoring.");
                return;
            }

            if (IsMovingForced)
            {
                Debug.LogWarning($"[GridMotionManager] Already moving! Ignoring request to move {levelDelta} levels.");
                return; // Prevent concurrent movements
            }

            // Ensure player is initialized
            if (player == null || _playerTransform == null)
            {
                Debug.LogError("[GridMotionManager] Cannot move - player reference is null! Make sure player is assigned in inspector or has 'Player' tag.");
                return;
            }

            // Ensure FloorsManager is available
            if (FloorsManager.Instance == null)
            {
                Debug.LogError("[GridMotionManager] Cannot move - FloorsManager.Instance is null! Make sure FloorsManager is in the scene.");
                return;
            }

            StartCoroutine(MoveRoutine(levelDelta));
        }

        /// <summary>
        /// Checks if GridMotionManager is ready to perform movements.
        /// </summary>
        public bool IsReady()
        {
            return player != null && _playerTransform != null && FloorsManager.Instance != null;
        }
        #endregion

        #region Main Coroutine
        private IEnumerator MoveRoutine(int levelDelta)
        {
            // Validate player reference (double-check, should have been caught in MoveLevels)
            if (player == null || _playerTransform == null)
            {
                Debug.LogError("[GridMotionManager] Cannot move - player reference is null! This should not happen if MoveLevels validation worked.");
                IsMovingForced = false;
                yield break;
            }

            // --- 1. SETUP ---
            IsMovingForced = true;
            int currentLevel = FloorsManager.Instance.GetLevelIndex(_playerTransform.position.y);
            int targetLevel = currentLevel + levelDelta;
            float targetY = FloorsManager.Instance.GetPlatformY(targetLevel);
            
            Vector3 startPos = _playerTransform.position;
            Vector3 targetPos = new Vector3(startPos.x, targetY, startPos.z);

            // --- 2. INITIALIZE STATE ---
            SetPhysicsAndInputState(isMoving: true);
            ThousandFloorsEvents.HeroMoveStarted(currentLevel, targetLevel);

            // Calculate rotation needed to align with the target platform's "front"
            CalculateRotationTargets(targetLevel, startPos, out Quaternion startRot, out Quaternion endRot, out bool rotateCylinder);

            SetAnimationState(isMoving: true, levelDelta);

            // --- 3. MOVEMENT LOOP ---
            float distance = Vector3.Distance(startPos, targetPos);
            float duration = moveSpeed > 0 ? distance / moveSpeed : DEFAULT_MOVE_DURATION;
            float elapsed = 0;
            int lastProcessedLevel = currentLevel;

            while (elapsed < duration)
            {
                // Pause support: wait if paused (e.g., during cutscene)
                while (IsPaused)
                {
                    yield return null;
                }

                float t = elapsed / duration;
                float curveT = motionCurve.Evaluate(t);

                // Lerp Position
                _playerTransform.position = Vector3.Lerp(startPos, targetPos, curveT);

                // Slerp Rotation (if using cylindrical coordinates)
                if (rotateCylinder)
                {
                    _cylinderModifier.cylinderCenter.rotation = Quaternion.Slerp(startRot, endRot, curveT);
                }

                // Event Check: Have we passed a floor during this frame?
                lastProcessedLevel = CheckLevelCrossings(lastProcessedLevel, _playerTransform.position.y, levelDelta, targetLevel);

                elapsed += Time.deltaTime;
                yield return null;
            }

            // --- 4. FINALIZE ---
            
            // A. Restore Physics State
            SetPhysicsAndInputState(isMoving: false);
            SetAnimationState(isMoving: false);
            
            // B. Snap Position & Velocity
            _rb.velocity = Vector3.zero; 
            
            // C. Final Position Snap
            // Apply Offset to prevent embedding in the floor and physics depenetration spikes
            _playerTransform.position = new Vector3(targetPos.x, targetPos.y + LANDING_OFFSET_Y, targetPos.z);
            
            if (rotateCylinder)
            {
                _cylinderModifier.cylinderCenter.rotation = endRot;
            }

            // D. CRITICAL FIX: Force Physics Engine to update Transform positions immediately
            // This ensures the Collider is actually at the new position before the next GroundCheck runs.
            Physics.SyncTransforms();

            // E. Manually tell HeroController "We are on the ground, don't check physics this frame"
            if (FloorsManager.Instance.GetPlatform(targetLevel, out GameObject targetPlatform))
            {
                 HeroController hero = player.GetComponent<HeroController>();
                 if (hero != null)
                 {
                     hero.ForceSnapToGround(targetPlatform.transform, true);
                 }
            }

            // Final event check to ensure no levels were skipped in the last frame
            CheckLevelCrossings(lastProcessedLevel, _playerTransform.position.y, levelDelta, targetLevel);

            ThousandFloorsEvents.HeroMoveCompleted(currentLevel, targetLevel);
            IsMovingForced = false;
        }
        #endregion

        #region Helper Logic
        /// <summary>
        /// Calculates the required cylinder rotation to align the player with the target platform's center.
        /// </summary>
        private void CalculateRotationTargets(int targetLevel, Vector3 playerPos, out Quaternion startRot, out Quaternion endRot, out bool valid)
        {
            startRot = Quaternion.identity;
            endRot = Quaternion.identity;
            valid = _cylinderModifier != null && _cylinderModifier.cylinderCenter != null;

            if (!valid) return;

            // 1. Get Target Platform Angle
            float centerAngleOffset = 0f;
            if (FloorsManager.Instance.GetPlatform(targetLevel, out GameObject platformGo))
            {
                // If it's a generated sector, ask it for its center; otherwise use Transform rotation
                float platformRotY = platformGo.transform.localEulerAngles.y;
                if (platformGo.TryGetComponent<SectorPlatformMeshGenerator>(out var gen))
                {
                    centerAngleOffset = platformRotY + gen.GetLocalCenterAngle();
                }
                else
                {
                    centerAngleOffset = platformRotY;
                }
            }

            // 2. Calculate Current Angles
            startRot = _cylinderModifier.cylinderCenter.rotation;

            // Vector from Center -> Player
            Vector3 dirToPlayer = (playerPos - _cylinderModifier.cylinderCenter.position);
            dirToPlayer.y = 0;

            // Convert Vector to Angle (0-360)
            // Atan2 gives radians, convert to deg.
            float playerWorldAngle = Mathf.Repeat(Mathf.Atan2(dirToPlayer.x, dirToPlayer.z) * Mathf.Rad2Deg, 360f);

            // 3. Determine Rotation Delta
            // We want the cylinder to rotate so the player lands on 'centerAngleOffset'.
            float targetCylinderRotationY = playerWorldAngle - centerAngleOffset;
            float angleDiff = Mathf.DeltaAngle(startRot.eulerAngles.y, targetCylinderRotationY);
            
            // Construct final rotation
            endRot = Quaternion.Euler(0, startRot.eulerAngles.y + angleDiff, 0);
        }

        private void SetPhysicsAndInputState(bool isMoving)
        {
            GlobalEvents.ToggleInputLock(isMoving);

            _rb.isKinematic = isMoving;
            if (_col != null) _col.enabled = !isMoving;
            if (isMoving) _rb.velocity = Vector3.zero; // Clear existing momentum
        }

        private void SetAnimationState(bool isMoving, int levelDelta = 0)
        {
            if (_anim == null) return;

            if (isMoving)
            {
                _anim.SetBool(animOnGroundBool, false);
                _anim.SetBool(animKinematicBool, true);
                // Set velocity to +/- 10 to trigger jump/fall blend trees
                _anim.SetFloat(animVelocityFloat, levelDelta > 0 ? 10f : -10f);
            }
            else
            {
                _anim.SetBool(animOnGroundBool, true);
                _anim.SetFloat(animVelocityFloat, 0f);
            }
        }

        /// <summary>
        /// Checks if the player has passed through floor thresholds and triggers Scoring/Breaking events.
        /// </summary>
        private int CheckLevelCrossings(int lastLevel, float currentY, int delta, int targetLevel)
        {
            float offset = FloorsManager.Instance.verticalDistance * LEVEL_CHECK_OFFSET_RATIO;
            float halfDist = FloorsManager.Instance.verticalDistance * 0.5f;
            
            // Look ahead (+offset) if going up, look behind (-offset) if going down
            float checkY = delta > 0 ? currentY + offset : currentY - offset;
            int currentLevelIdx = FloorsManager.Instance.GetLevelIndex(checkY);

            // Process all levels between last checked and current
            if (delta > 0) // Moving UP
            {
                while (lastLevel < currentLevelIdx && lastLevel < targetLevel)
                {
                    lastLevel++;
                    // Logic: Pre-load the platform visually before we arrive
                    ThousandFloorsEvents.RequestPlatformState(lastLevel, true);
                    
                    Vector3 effectPos = new Vector3(_playerTransform.position.x, FloorsManager.Instance.GetPlatformY(lastLevel) - halfDist, _playerTransform.position.z);
                    ThousandFloorsEvents.ScoreChanged(1, effectPos, true);
                }
            }
            else // Moving DOWN
            {
                while (lastLevel > currentLevelIdx && lastLevel > targetLevel)
                {
                    Vector3 effectPos = new Vector3(_playerTransform.position.x, FloorsManager.Instance.GetPlatformY(lastLevel) - halfDist, _playerTransform.position.z);
                    ThousandFloorsEvents.ScoreChanged(-1, effectPos, true);
                    ThousandFloorsEvents.PlatformBroken(lastLevel);
                    lastLevel--;
                }
            }
            return lastLevel;
        }
        #endregion
    }
}