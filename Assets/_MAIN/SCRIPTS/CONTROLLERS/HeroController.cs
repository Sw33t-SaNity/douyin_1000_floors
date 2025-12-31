using UnityEngine;
using UnityEngine.InputSystem;
using MoreMountains.Feedbacks;
using MoreMountains.Tools; // Required for MMSpring

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(Rigidbody))]
[RequireComponent(typeof(CapsuleCollider))]
[RequireComponent(typeof(CharacterStats))]
public class HeroController : MonoBehaviour
{
    // --- REFERENCES ---
    [Header("Game Feel - Damage")]
    public MMF_Player damageFeedback;
    public MMF_Player JumpFeedback;
    [Header("Game Feel - Landing (Spring)")]
    [Tooltip("Direct reference to the MMSpringSquashAndStretch component on the visual child.")]
    public MMF_Player landingFeedback; 

    [Header("Landing Config")]
    [Tooltip("Below this vertical speed, no squash occurs.")]
    public float minFallSpeed = 5f;

    [Tooltip("At this vertical speed, maximum squash force is applied.")]
    public float maxFallSpeed = 20f;
    
    [Header("Spring Forces")]
    [Tooltip("Force applied to the spring at Min Fall Speed.")]
    public float minSquashForce = 0.5f; 
    [Tooltip("Force applied to the spring at Max Fall Speed.")]
    public float maxSquashForce = 3.0f;

    // --- INTERNAL COMPONENT REFS ---
    private CharacterStats stats;
    private Animator animator;
    private Rigidbody rb;
    private CapsuleCollider capCollider;
    private IA_Hero heroActions;
    private IMovementModifier movementModifier;

    // --- STATE ---
    private Vector2 movementInput;
    private bool isGrounded;
    private bool wasGrounded;
    private bool isStunned = false; 
    private bool isGhostMode = false;
    private float stunTimer = 0f;
    private float coyoteTimeCounter;
    private IPlatform currentPlatform;
    
    private float _previousFrameVelocityY; 

    // --- ANIMATOR HASHES ---
    private readonly int hashIsWalking = Animator.StringToHash("Is_Walking");
    private readonly int hashIsOnGround = Animator.StringToHash("Is_Onground");
    private readonly int hashHurt = Animator.StringToHash("Hurt");
    private readonly int hashJump = Animator.StringToHash("Jump");
    private readonly int hashVerticalVelocity = Animator.StringToHash("VerticalVelocity");
    private readonly int hashCurrentSpeed = Animator.StringToHash("CurrentSpeed");

    private void Awake()
    {
        heroActions = new IA_Hero();
        movementModifier = GetComponent<IMovementModifier>();
        animator = GetComponent<Animator>();
        rb = GetComponent<Rigidbody>();
        capCollider = GetComponent<CapsuleCollider>();
        stats = GetComponent<CharacterStats>();
    }

    private void OnEnable()
    {
        heroActions.Gameplay.Enable();
        heroActions.Gameplay.Jump.performed += OnJump;
        if (stats != null) stats.OnTakenDamage += HandleKnockback;
    }

    private void OnDisable()
    {
        heroActions.Gameplay.Disable();
        heroActions.Gameplay.Jump.performed -= OnJump;
        if (stats != null) stats.OnTakenDamage -= HandleKnockback;
    }

    void Start()
    {
        rb.constraints = RigidbodyConstraints.FreezeRotation;
        
        if (capCollider != null)
        {
            PhysicMaterial frictionLess = new PhysicMaterial {
                dynamicFriction = 0,
                staticFriction = 0,
                frictionCombine = PhysicMaterialCombine.Minimum,
                name = "NoFriction"
            };
            capCollider.material = frictionLess;
        }
    }

    void Update()
    {
        // 1. TIMER LOGIC
        if (stunTimer > 0)
        {
            stunTimer -= Time.deltaTime;
            if (stunTimer <= 0)
            {
                isStunned = false; 
                if (isGhostMode)
                {
                    Physics.IgnoreLayerCollision(gameObject.layer, stats.data.platformLayerIndex, false);
                    isGhostMode = false;
                }
            }
        }

        // 2. INPUT
        if (!isStunned)
        {
            movementInput = heroActions.Gameplay.Move.ReadValue<Vector2>();
        }

        // 3. COYOTE TIME
        if (isGrounded)
        {
            coyoteTimeCounter = stats.data.coyoteTime;
        }
        else
        {
            coyoteTimeCounter -= Time.deltaTime;
        }

        UpdateAnimator();
    }

    private float _lastFrameVelocityY;

    void FixedUpdate()
    {
        // 1. Capture State
        // We set 'wasGrounded' to what 'isGrounded' was at the end of LAST frame
        wasGrounded = isGrounded; 

        // 2. Physics Checks
        GroundCheck(); // Updates 'isGrounded' to TRUE if we just hit the floor

        // 3. Landing Logic
        HandleLandingSpring();

        // 4. Movement & Physics
        HandleMovement();
        HandleRotation();
        HandleBetterJump();

        // 5. CRITICAL FIX: Capture velocity at the END of the frame
        // This ensures that when the NEXT frame starts, we know how fast we were going
        // right before physics potentially stopped us.
        _lastFrameVelocityY = rb.velocity.y;
    }

    private void HandleLandingSpring()
    {
        // Trigger if we were in the air (was=false) and now we are on ground (is=true)
        if (!wasGrounded && isGrounded)
        {
            // USE THE CACHED VELOCITY, NOT CURRENT VELOCITY
            float impactSpeed = Mathf.Abs(_lastFrameVelocityY);

            if (impactSpeed > minFallSpeed)
            {
                float t = Mathf.InverseLerp(minFallSpeed, maxFallSpeed, impactSpeed);
                float calculatedForce = Mathf.Lerp(minSquashForce, maxSquashForce, t);

                if (landingFeedback != null)
                {
                    // Assuming you found the correct feedback type
                    MMF_SpringFloat _springFloat = landingFeedback.GetFeedbackOfType<MMF_SpringFloat>();
                    if (_springFloat != null)
                    {
                        _springFloat.BumpAmount = calculatedForce;
                        landingFeedback.PlayFeedbacks();
                    }
                }
            }
        }
    }

    private void HandleKnockback(DamageData info)
    {
        if (damageFeedback != null)
        {
            damageFeedback.FeedbacksIntensity = 1f; 
            damageFeedback.PlayFeedbacks();
        }

        isStunned = true;
        stunTimer = info.stunDuration;
        animator.SetTrigger(hashHurt);

        if (info.ignoreGroundCollision)
        {
            isGhostMode = true;
            Physics.IgnoreLayerCollision(gameObject.layer, stats.data.platformLayerIndex, true);
        }

        Vector3 currentHorizontal = new Vector3(rb.velocity.x, 0f, rb.velocity.z);
        if (info.resetMomentum) currentHorizontal = Vector3.zero;

        rb.velocity = currentHorizontal;
        rb.AddForce(info.knockbackForce, ForceMode.Impulse);
    }
    
    // ... [Rest of GroundCheck, HandleMovement, HandleRotation, etc. remains unchanged] ...

    private void GroundCheck()
    {
        if (isGhostMode) 
        {
            isGrounded = false;
            currentPlatform = null;
            return;
        }

        Vector3 spherePosition = transform.position + Vector3.up * stats.data.groundCheckOffset;
        Collider[] hits = Physics.OverlapSphere(spherePosition, stats.data.groundCheckRadius, stats.data.groundLayer, QueryTriggerInteraction.Ignore);
        
        if (hits.Length > 0)
        {
            HandlePlatformInteraction(hits[0]);
        }
        else
        {
            isGrounded = false;
            currentPlatform = null;
        }
    }

    private void HandlePlatformInteraction(Collider groundCollider)
    {
        IPlatform foundPlatform = groundCollider.GetComponent<IPlatform>();
        float platformUpwardSpeed = (foundPlatform != null) ? foundPlatform.GetVelocity().y : 0f;
        float jumpVelocityThreshold = platformUpwardSpeed + (stats.CurrentJumpForce * 0.5f);

        if (rb.velocity.y > jumpVelocityThreshold)
        {
            isGrounded = false;
            currentPlatform = null;
        }
        else
        {
            isGrounded = true;
            currentPlatform = foundPlatform;
            if (currentPlatform != null) currentPlatform.OnStand(this.gameObject);
        }
    }

    private void HandleMovement()
    {
        if (isStunned) return;

        Vector3 finalVelocity = Vector3.zero;

        if (movementModifier != null)
        {
            finalVelocity = movementModifier.CalculateVelocity(rb, movementInput, stats.CurrentMoveSpeed, stats.data.acceleration);
        }
        else 
        {
            Vector3 targetVelocity = new Vector3(movementInput.x, 0, movementInput.y) * stats.CurrentMoveSpeed;
            Vector3 currentHorizontalVelocity = new Vector3(rb.velocity.x, 0, rb.velocity.z);
            float speedChangeRate = (movementInput.magnitude > 0.01f) ? stats.data.acceleration : stats.data.deceleration;
            finalVelocity = Vector3.MoveTowards(currentHorizontalVelocity, targetVelocity, speedChangeRate * Time.fixedDeltaTime);
        }
        
        if (isGrounded && currentPlatform != null)
        {
            Vector3 platformVel = currentPlatform.GetVelocity();
            finalVelocity.x += platformVel.x;
            finalVelocity.z += platformVel.z;
        }

        rb.velocity = new Vector3(finalVelocity.x, rb.velocity.y, finalVelocity.z);
    }

    private void HandleRotation()
    {
        if (isStunned) return;

        if (movementModifier != null && movementModifier.ShouldHandleRotation())
        {
            movementModifier.HandleRotation(rb, movementInput, stats.data.rotationSpeed);
            return;
        }

        if (movementInput.magnitude > 0.1f)
        {
            Vector3 movementDirection = new Vector3(movementInput.x, 0f, movementInput.y);
            if (movementDirection != Vector3.zero)
            {
                Quaternion targetRotation = Quaternion.LookRotation(movementDirection, Vector3.up);
                rb.MoveRotation(Quaternion.RotateTowards(rb.rotation, targetRotation, stats.data.rotationSpeed * Time.fixedDeltaTime));
            }
        }
    }

    private void HandleBetterJump()
    {
        if (isStunned) return;

        if (rb.velocity.y < 0)
        {
            rb.velocity += Vector3.up * Physics.gravity.y * (stats.data.fallMultiplier - 1) * Time.fixedDeltaTime;
        }
        else if (rb.velocity.y > 0 && !heroActions.Gameplay.Jump.IsPressed())
        {
            rb.velocity += Vector3.up * Physics.gravity.y * (stats.data.lowJumpMultiplier - 1) * Time.fixedDeltaTime;
        }
    }

    private void OnJump(InputAction.CallbackContext context)
    {
        if (isStunned) return;

        if (coyoteTimeCounter > 0f)
        {
            isGrounded = false;
            animator.SetTrigger(hashJump);
            JumpFeedback.PlayFeedbacks();

            float verticalBoost = stats.CurrentJumpForce;
            if (currentPlatform != null)
            {
                verticalBoost += currentPlatform.GetVelocity().y;
            }

            rb.velocity = new Vector3(rb.velocity.x, verticalBoost, rb.velocity.z);
            coyoteTimeCounter = 0f;
        }
    }

    private void UpdateAnimator()
    {
        Vector3 horizontalVelocity = new Vector3(rb.velocity.x, 0, rb.velocity.z);
        float currentSpeed = horizontalVelocity.magnitude;
        float normalizedSpeed = currentSpeed / stats.CurrentMoveSpeed;

        bool isWalking = isGrounded && currentSpeed > 0.1f && movementInput.magnitude > 0.1f;

        animator.SetBool(hashIsWalking, isWalking);
        animator.SetBool(hashIsOnGround, isGrounded);
        animator.SetFloat(hashCurrentSpeed, normalizedSpeed);
        float displayVertSpeed = isGrounded ? 0 : rb.velocity.y;
        animator.SetFloat(hashVerticalVelocity, displayVertSpeed);
    }

    // OnGUI and OnDrawGizmos kept same...
}