using UnityEngine;

[CreateAssetMenu(fileName = "NewHeroData", menuName = "Game/Character Data")]
public class CharacterData : ScriptableObject
{
    [Header("Base Stats")]
    public int maxHealth = 3;
    public float baseMoveSpeed = 5.0f;
    public float baseJumpForce = 7.0f;

    [Header("Physics Config")]
    public float acceleration = 10.0f;
    public float deceleration = 20.0f;
    public float rotationSpeed = 720f;
    
    [Header("Jump Feel")]
    public float coyoteTime = 0.15f;
    public float fallMultiplier = 2.5f;
    public float lowJumpMultiplier = 2.0f;

    [Header("Collision Config")]
    public LayerMask groundLayer;
    public float groundCheckRadius = 0.15f;
    public float groundCheckOffset = 0.05f;

    [Header("Combat / Hurt")]
    public float knockbackForce = 12f;
    [Tooltip("The Layer ID of your Platforms (Check Unity Top Right: Layers). Usually 6 or 7.")]
    public int platformLayerIndex = 0;


    [Header("Debug")]
    public bool showDebugInfo = true;
}