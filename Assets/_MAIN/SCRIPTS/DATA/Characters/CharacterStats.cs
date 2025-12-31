using UnityEngine;
using System;
using System.Collections; // Required for Coroutines

public class CharacterStats : MonoBehaviour, IDataReceiver
{
    [Tooltip("Drag the ScriptableObject file here")]
    public CharacterData data;
    public event Action<DamageData> OnTakenDamage;
    // --- Dynamic Properties ---
    public float CurrentMoveSpeed { get; set; }
    public float CurrentJumpForce { get; set; }
    
    public int CurrentHealth { get; private set; }
    public int CurrentScore { get; private set; }
    public int CurrentCoins { get; private set; }

    // Track active Coroutines so we don't stack them infinitely
    private Coroutine _speedCoroutine;
    private Coroutine _jumpCoroutine;

    private void Awake()
    {
        if (data == null)
        {
            Debug.LogError("CharacterStats is missing Data File!");
            return;
        }
        ResetToDefaults();
    }

    public void ResetToDefaults()
    {
        CurrentMoveSpeed = data.baseMoveSpeed;
        CurrentJumpForce = data.baseJumpForce;
        CurrentHealth = data.maxHealth;
        CurrentScore = 0;
        CurrentCoins = 0;
    }

    // --- INTERFACE IMPLEMENTATION ---
    public void OnReceive(ResourceType type, int amount, DamageData info = null)
    {
        switch (type)
        {
            case ResourceType.Health:
                CurrentHealth += amount;
                CurrentHealth = Mathf.Clamp(CurrentHealth, 0, data.maxHealth);
                
                if (amount < 0) 
                {
                    Debug.Log("Ouch!");
                    // Trigger the event so Controller knows to Knockback
                    if (info != null)
                    {
                        OnTakenDamage?.Invoke(info);
                    }
                }
                // if (CurrentHealth <= 0) HandleDeath();
                break;

            case ResourceType.Score:
                CurrentScore += amount;
                Debug.Log($"Score! Total: {CurrentScore}");
                break;

            case ResourceType.Coin:
                CurrentCoins += amount;
                Debug.Log($"Ka-ching! Coins: {CurrentCoins}");
                break;

            // --- BUFF LOGIC ---
            // We treat 'amount' as DURATION (in seconds) for simplicity.
            // Or you can treat it as %. Here I assume it's Duration.
            
            case ResourceType.Buff_Speed:
                ApplyBuff(ref _speedCoroutine, BuffSpeedRoutine(amount));
                break;

            case ResourceType.Buff_Jump:
                ApplyBuff(ref _jumpCoroutine, BuffJumpRoutine(amount));
                break;
        }
    }

    private void HandleDeath()
    {
        // Debug.Log("PLAYER DIED");
        // Disable controls, show UI, etc.
    }

    // --- BUFF SYSTEM ---

    // Helper to stop existing buff before starting a new one (refresh duration)
    private void ApplyBuff(ref Coroutine trackingRoutine, IEnumerator newRoutine)
    {
        if (trackingRoutine != null) StopCoroutine(trackingRoutine);
        trackingRoutine = StartCoroutine(newRoutine);
    }

    private IEnumerator BuffSpeedRoutine(float duration)
    {
        // 1. Apply Effect (e.g., +50% Speed)
        float originalSpeed = CurrentMoveSpeed;
        CurrentMoveSpeed = originalSpeed * 1.5f; 
        Debug.Log("<color=cyan>Speed Buff Started!</color>");

        // 2. Wait
        yield return new WaitForSeconds(duration);

        // 3. Revert
        CurrentMoveSpeed = originalSpeed; 
        Debug.Log("Speed Buff Ended.");
        _speedCoroutine = null;
    }

    private IEnumerator BuffJumpRoutine(float duration)
    {
        float originalJump = CurrentJumpForce;
        CurrentJumpForce = originalJump * 1.3f; // +30% Jump
        Debug.Log("<color=yellow>Jump Buff Started!</color>");

        yield return new WaitForSeconds(duration);

        CurrentJumpForce = originalJump;
        Debug.Log("Jump Buff Ended.");
        _jumpCoroutine = null;
    }
}