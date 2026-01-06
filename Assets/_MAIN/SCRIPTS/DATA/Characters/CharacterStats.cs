using UnityEngine;
using System;
using System.Collections; // Required for Coroutines

namespace YF_3DGameBase
{
    public class CharacterStats : MonoBehaviour, I_DataReceiver 
    {
        [Tooltip("Drag the ScriptableObject file here")]
        public SO_CharacterData data;
        public event Action<DamageInfo> OnTakenDamage;
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
        public void OnReceive(ResourceType type, float amount, float duration = 0, DamageInfo info = null)
        {
            switch (type)
            {
                case ResourceType.Health:
                    CurrentHealth += (int)amount;
                    CurrentHealth = Mathf.Clamp(CurrentHealth, 0, data.maxHealth);
                    
                    if ((int)amount < 0) 
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
                    CurrentScore += (int)amount; // Track total platforms jumped
                    // Forward to ScoreManager to progress the 1000-floor countdown
                    if (ScoreManager.Instance != null)
                    {
                        ScoreManager.Instance.ChangeScore(-(int)amount);
                        Debug.Log($"Score increased by {(int)amount}. Total Score: {CurrentScore}");
                    }
                    break;

                case ResourceType.Coin:
                    CurrentCoins += (int)amount;
                    Debug.Log($"Ka-ching! Coins: {(int)amount}");
                    break;

                // --- BUFF LOGIC ---
                case ResourceType.Buff_Speed:
                    if (duration == -1) 
                        ApplyForeverBuff(ResourceType.Buff_Speed, amount);
                    else 
                        ApplyBuff(ref _speedCoroutine, BuffSpeedRoutine(amount, duration));
                    break;

                case ResourceType.Buff_Jump:
                    if (duration == -1) 
                        ApplyForeverBuff(ResourceType.Buff_Jump, amount);
                    else 
                        ApplyBuff(ref _jumpCoroutine, BuffJumpRoutine(amount, duration));
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

        /// <summary>
        /// Applies a buff that lasts until ResetToDefaults is called or overridden.
        /// </summary>
        public void ApplyForeverBuff(ResourceType type, float multiplier)
        {
            switch (type)
            {
                case ResourceType.Buff_Speed:
                    if (_speedCoroutine != null) StopCoroutine(_speedCoroutine);
                    _speedCoroutine = null;
                    CurrentMoveSpeed = data.baseMoveSpeed * multiplier; 
                    Debug.Log("<color=cyan>Speed Buff Applied Forever!</color>");
                    break;

                case ResourceType.Buff_Jump:
                    if (_jumpCoroutine != null) StopCoroutine(_jumpCoroutine);
                    _jumpCoroutine = null;
                    CurrentJumpForce = data.baseJumpForce * multiplier; 
                    Debug.Log("<color=yellow>Jump Buff Applied Forever!</color>");
                    break;
            }
        }

        private IEnumerator BuffSpeedRoutine(float multiplier, float duration)
        {
            CurrentMoveSpeed = data.baseMoveSpeed * multiplier; 
            Debug.Log("<color=cyan>Speed Buff Started!</color>");

            // 2. Wait
            yield return new WaitForSeconds(duration);

            // 3. Revert
            CurrentMoveSpeed = data.baseMoveSpeed; 
            Debug.Log("Speed Buff Ended.");
            _speedCoroutine = null;
        }

        private IEnumerator BuffJumpRoutine(float multiplier, float duration)
        {
            CurrentJumpForce = data.baseJumpForce * multiplier; 
            Debug.Log("<color=yellow>Jump Buff Started!</color>");

            yield return new WaitForSeconds(duration);

            CurrentJumpForce = data.baseJumpForce;
            Debug.Log("Jump Buff Ended.");
            _jumpCoroutine = null;
        }
    }
}