using UnityEngine;
using UnityEngine.InputSystem;

namespace YF_3DGameBase
{
    /// <summary>
    /// Manages the hero's physics-based movement, jump logic, animation states, 
    /// and "Game Feel" feedbacks (squash & stretch, particles).
    /// </summary>
    [RequireComponent(typeof(Animator))]
    [RequireComponent(typeof(Rigidbody))]
    [RequireComponent(typeof(CapsuleCollider))]
    [RequireComponent(typeof(CharacterStats))]
    public class HeroController : MonoBehaviour
    {
        public enum HeroState { Normal, Stunned, InputLocked }

        #region Events
        public event System.Action OnJumped;
        public event System.Action<float, Transform> OnLanded;
        public event System.Action<DamageInfo> OnDamaged;
        #endregion

        #region Inspector - Landing Config
        [Tooltip("Below this vertical speed, no squash occurs upon landing.")]
        public float minFallSpeed = 5f;
        #endregion

        #region Internal References
        private CharacterStats _stats;
        private Animator _animator;
        private Rigidbody _rb;
        private CapsuleCollider _capCollider;
        private IA_Hero _heroActions;
        private I_MovementModifier _movementModifier;
        #endregion

        #region State Management
        private Vector2 _movementInput;
        private bool _isGrounded;
        private bool _wasGrounded;
        private HeroState _currentState = HeroState.Normal;
        private bool _isGhostMode = false;
        private float _stunTimer = 0f;
        private float _coyoteTimeCounter;
        private bool _ignoreVelocityCheck = false;
        
        // Track the current platform for moving platform logic
        private IPlatform _currentPlatform;
        private Transform _currentPlatformTransform;
        
        // Stores velocity from the VERY END of the previous FixedUpdate 
        // to handle impact logic correctly before physics resolves collisions.
        private float _lastFrameVelocityY; 
        #endregion

        #region Animator Hashes
        private readonly int _hashIsWalking = Animator.StringToHash("Is_Walking");
        private readonly int _hashIsOnGround = Animator.StringToHash("Is_Onground");
        private readonly int _hashHurt = Animator.StringToHash("Hurt");
        private readonly int _hashJump = Animator.StringToHash("Jump");
        private readonly int _hashVerticalVelocity = Animator.StringToHash("VerticalVelocity");
        private readonly int _hashCurrentSpeed = Animator.StringToHash("CurrentSpeed");
        private readonly int _hashIsKinematic = Animator.StringToHash("IsKinematic");
        #endregion

        #region Unity Lifecycle
        private void Awake()
        {
            _heroActions = new IA_Hero();
            _movementModifier = GetComponent<I_MovementModifier>();
            _animator = GetComponent<Animator>();
            _rb = GetComponent<Rigidbody>();
            _capCollider = GetComponent<CapsuleCollider>();
            _stats = GetComponent<CharacterStats>();
        }

        private void OnEnable()
        {
            _heroActions.Gameplay.Enable();
            _heroActions.Gameplay.Jump.performed += OnJump;
            
            if (_stats != null) _stats.OnTakenDamage += HandleKnockback;
            GlobalEvents.OnToggleInputLock += HandleInputLock;
        }

        private void OnDisable()
        {
            _heroActions.Gameplay.Disable();
            _heroActions.Gameplay.Jump.performed -= OnJump;
            
            if (_stats != null) _stats.OnTakenDamage -= HandleKnockback;
            GlobalEvents.OnToggleInputLock -= HandleInputLock;
        }

        void Start()
        {
            _rb.constraints = RigidbodyConstraints.FreezeRotation;
            
            // Set up frictionless material to prevent sticking to walls
            if (_capCollider != null)
            {
                PhysicMaterial frictionLess = new PhysicMaterial {
                    dynamicFriction = 0,
                    staticFriction = 0,
                    frictionCombine = PhysicMaterialCombine.Minimum,
                    name = "NoFriction"
                };
                _capCollider.material = frictionLess;
            }
        }

        void Update()
        {
            HandleTimers();
            HandleInput();
            HandleCoyoteTime();
            UpdateAnimator();
        }

        void FixedUpdate()
        {
            // 1. Capture State: 'wasGrounded' is the state at the end of LAST frame
            _wasGrounded = _isGrounded; 

            // 2. Physics Checks: Updates 'isGrounded' to TRUE if we just hit the floor
            GroundCheck(); 

            // 3. Game Feel: Calculate landing impact
            HandleLandingSpring();

            // 4. Movement Physics
            HandleMovement();
            HandleRotation();
            HandleBetterJump();     // Variable jump height / gravity mods
            HandleTerminalVelocity();

            // 5. CRITICAL FIX: Capture velocity at the END of the frame.
            // When Unity resolves collisions (internally after FixedUpdate), velocity often becomes 0.
            // We save it here to know how fast we were hitting the ground in the NEXT frame.
            _lastFrameVelocityY = _rb.velocity.y;
        }
        #endregion

        #region State Logic
        private void HandleInputLock(bool isLocked)
        {
            if (isLocked) {
                _currentState = HeroState.InputLocked;
                _movementInput = Vector2.zero;
            }
            else if (_currentState == HeroState.InputLocked) _currentState = HeroState.Normal;
        }

        private void HandleTimers()
        {
            if (_stunTimer > 0)
            {
                _stunTimer -= Time.deltaTime;
                if (_stunTimer <= 0)
                {
                    if (_currentState == HeroState.Stunned) _currentState = HeroState.Normal;
                    if (_isGhostMode)
                    {
                        // Restore collisions with platforms
                        Physics.IgnoreLayerCollision(gameObject.layer, _stats.data.platformLayerIndex, false);
                        _isGhostMode = false;
                    }
                }
            }
        }

        private void ResetVelocityCheck()
        {
            _ignoreVelocityCheck = false;
        }

        private void HandleInput()
        {
            if (_currentState == HeroState.Normal)
            {
                _movementInput = _heroActions.Gameplay.Move.ReadValue<Vector2>();
            }
            else
            {
                _movementInput = Vector2.zero;
            }
        }

        private void HandleCoyoteTime()
        {
            if (_isGrounded)
            {
                _coyoteTimeCounter = _stats.data.coyoteTime;
            }
            else
            {
                _coyoteTimeCounter -= Time.deltaTime;
            }
        }
        #endregion

        #region Physics & Movement
        private void GroundCheck()
        {
            // If in ghost mode (falling through platforms due to damage), force ungrounded
            if (_isGhostMode) 
            {
                _isGrounded = false;
                _currentPlatform = null;
                _currentPlatformTransform = null;
                return;
            }

            Vector3 spherePosition = transform.position + Vector3.up * _stats.data.groundCheckOffset;
            Collider[] hits = Physics.OverlapSphere(spherePosition, _stats.data.groundCheckRadius, _stats.data.groundLayer, QueryTriggerInteraction.Ignore);
            
            if (hits.Length > 0)
            {
                HandlePlatformInteraction(hits[0]);
            }
            else
            {
                _isGrounded = false;
                _currentPlatform = null;
                _currentPlatformTransform = null;
            }
        }

        private void HandlePlatformInteraction(Collider groundCollider)
        {
            IPlatform foundPlatform = groundCollider.GetComponent<IPlatform>();
            float platformUpwardSpeed = (foundPlatform != null) ? foundPlatform.GetVelocity().y : 0f;
            
            // Allow jumping *through* platforms from below without snapping to ground immediately
            float jumpVelocityThreshold = platformUpwardSpeed + (_stats.CurrentJumpForce * 0.5f);

            if (!_ignoreVelocityCheck && _rb.velocity.y > jumpVelocityThreshold)
            {
                _isGrounded = false;
                _currentPlatform = null;
                _currentPlatformTransform = null;
            }
            else
            {
                _isGrounded = true;
                _currentPlatform = foundPlatform;
                _currentPlatformTransform = groundCollider.transform;
                if (_currentPlatform != null) _currentPlatform.OnStand(this.gameObject);
            }
        }

        private void HandleMovement()
        {
            if (_currentState != HeroState.Normal) return;

            Vector3 finalVelocity = Vector3.zero;

            // Strategy pattern: Allow external modifiers (e.g. ice, mud, grid movement) to override logic
            if (_movementModifier != null)
            {
                finalVelocity = _movementModifier.CalculateVelocity(_rb, _movementInput, _stats.CurrentMoveSpeed, _stats.data.acceleration);
            }
            else 
            {
                // Default physics-based movement with acceleration/deceleration
                Vector3 targetVelocity = new Vector3(_movementInput.x, 0, _movementInput.y) * _stats.CurrentMoveSpeed;
                Vector3 currentHorizontalVelocity = new Vector3(_rb.velocity.x, 0, _rb.velocity.z);
                
                float speedChangeRate = (_movementInput.magnitude > 0.01f) ? _stats.data.acceleration : _stats.data.deceleration;
                finalVelocity = Vector3.MoveTowards(currentHorizontalVelocity, targetVelocity, speedChangeRate * Time.fixedDeltaTime);
            }
            
            // Add platform velocity for parenting effect without actual parenting
            if (_isGrounded && _currentPlatform != null)
            {
                Vector3 platformVel = _currentPlatform.GetVelocity();
                finalVelocity.x += platformVel.x;
                finalVelocity.z += platformVel.z;
            }

            _rb.velocity = new Vector3(finalVelocity.x, _rb.velocity.y, finalVelocity.z);
        }

        private void HandleRotation()
        {
            if (_currentState != HeroState.Normal) return;

            if (_movementModifier != null && _movementModifier.ShouldHandleRotation())
            {
                _movementModifier.HandleRotation(_rb, _movementInput, _stats.data.rotationSpeed);
                return;
            }

            if (_movementInput.magnitude > 0.1f)
            {
                Vector3 movementDirection = new Vector3(_movementInput.x, 0f, _movementInput.y);
                if (movementDirection != Vector3.zero)
                {
                    Quaternion targetRotation = Quaternion.LookRotation(movementDirection, Vector3.up);
                    _rb.MoveRotation(Quaternion.RotateTowards(_rb.rotation, targetRotation, _stats.data.rotationSpeed * Time.fixedDeltaTime));
                }
            }
        }

        private void HandleBetterJump()
        {
            if (_currentState != HeroState.Normal) return;

            // Apply higher gravity when falling for snappier feel
            if (_rb.velocity.y < 0)
            {
                _rb.velocity += Vector3.up * Physics.gravity.y * (_stats.data.fallMultiplier - 1) * Time.fixedDeltaTime;
            }
            // Apply higher gravity if jump button is released (variable jump height)
            else if (_rb.velocity.y > 0 && !_heroActions.Gameplay.Jump.IsPressed())
            {
                _rb.velocity += Vector3.up * Physics.gravity.y * (_stats.data.lowJumpMultiplier - 1) * Time.fixedDeltaTime;
            }
        }

        private void HandleTerminalVelocity()
        {
            if (_rb.velocity.y < -_stats.data.maxFallSpeed)
            {
                _rb.velocity = new Vector3(_rb.velocity.x, -_stats.data.maxFallSpeed, _rb.velocity.z);
            }
        }

        private void OnJump(InputAction.CallbackContext context)
        {
            if (_currentState != HeroState.Normal) return;
            if (_movementModifier != null && !_movementModifier.CanJump()) return;

            // Perform Jump if within Coyote Time
            if (_coyoteTimeCounter > 0f)
            {
                _isGrounded = false;
                _animator.SetTrigger(_hashJump);
                OnJumped?.Invoke();

                float verticalBoost = _stats.CurrentJumpForce;
                
                // Add platform vertical velocity to prevent "sticky" feet on rising platforms
                if (_currentPlatform != null)
                {
                    verticalBoost += _currentPlatform.GetVelocity().y;
                }

                _rb.velocity = new Vector3(_rb.velocity.x, verticalBoost, _rb.velocity.z);
                _coyoteTimeCounter = 0f;
            }
        }
        #endregion

        #region Feedbacks & Visuals
        /// <summary>
        /// Manually forces the controller to recognize it has landed. 
        /// Bypasses physics checks for one frame and zeroes out momentum.
        /// </summary>
        public void ForceSnapToGround(Transform platformTransform, bool ignoreVelocityCheck = false)
        {
            // 1. Kill all momentum immediately
            _rb.velocity = Vector3.zero;
            _lastFrameVelocityY = 0f;

            // 2. Force state to grounded
            _isGrounded = true;
            _wasGrounded = true; // Prevent "Landing Impact" feedback from playing again
            
            // Set the flag to true to prevent "depenetration" from ungrounding us
            if (ignoreVelocityCheck)
            {
                _ignoreVelocityCheck = true;
                // Turn it off automatically after 0.2 seconds (approx 10-12 frames)
                Invoke(nameof(ResetVelocityCheck), 0.2f);
            }

            // 3. Manually link the platform
            if (platformTransform != null)
            {
                _currentPlatformTransform = platformTransform;
                _currentPlatform = platformTransform.GetComponent<IPlatform>();
                if (_currentPlatform != null) _currentPlatform.OnStand(this.gameObject);
            }
            
            // 4. Update Animator immediately so we don't see a 1-frame "fall" animation
            UpdateAnimator();
        }

        private void HandleLandingSpring()
        {
            // Trigger if we were in the air (was=false) and now we are on ground (is=true)
            if (!_wasGrounded && _isGrounded)
            {
                // USE THE CACHED VELOCITY (LastFrame), NOT CURRENT VELOCITY (which is now ~0)
                float impactSpeed = Mathf.Abs(_lastFrameVelocityY);

                if (impactSpeed > minFallSpeed) OnLanded?.Invoke(impactSpeed, _currentPlatformTransform);
            }
        }

        private void HandleKnockback(DamageInfo info)
        {
            OnDamaged?.Invoke(info);

            _currentState = HeroState.Stunned;
            _stunTimer = info.stunDuration;
            _animator.SetTrigger(_hashHurt);

            if (info.ignoreGroundCollision)
            {
                _isGhostMode = true;
                Physics.IgnoreLayerCollision(gameObject.layer, _stats.data.platformLayerIndex, true);
            }

            // Physics application
            Vector3 currentHorizontal = new Vector3(_rb.velocity.x, 0f, _rb.velocity.z);
            if (info.resetMomentum) currentHorizontal = Vector3.zero;

            _rb.velocity = currentHorizontal;
            _rb.AddForce(info.knockbackForce, ForceMode.Impulse);
        }

        private void UpdateAnimator()
        {
            // If we have a modifier, it dictates the visual velocity (e.g. for stationary movement animations)
            Vector3 horizontalVelocity = (_movementModifier != null) 
                ? _movementModifier.GetVisualVelocity() 
                : new Vector3(_rb.velocity.x, 0, _rb.velocity.z);

            float currentSpeed = horizontalVelocity.magnitude;
            float normalizedSpeed = currentSpeed / _stats.CurrentMoveSpeed;

            bool isWalking = _isGrounded && currentSpeed > 0.1f && _movementInput.magnitude > 0.1f;

            _animator.SetBool(_hashIsWalking, isWalking);
            _animator.SetBool(_hashIsOnGround, _isGrounded);
            _animator.SetFloat(_hashCurrentSpeed, normalizedSpeed);
            _animator.SetBool(_hashIsKinematic, _rb.isKinematic);

            // Only update VerticalVelocity if not in a forced move (kinematic)
            if (!_rb.isKinematic)
            {
                float displayVertSpeed = _isGrounded ? 0f : _rb.velocity.y;
                _animator.SetFloat(_hashVerticalVelocity, displayVertSpeed);
            }
        }
        #endregion
    }
}