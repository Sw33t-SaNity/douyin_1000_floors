using UnityEngine;
using System.Collections.Generic;

namespace Douyin.YF.Live
{
    /// <summary>
    /// Data structure for effect configuration with spawn offset, rotation, and lifetime.
    /// Using struct for better Unity serialization compatibility.
    /// </summary>
    [System.Serializable]
    public struct EffectData
    {
        [Tooltip("The effect prefab to instantiate.")]
        public GameObject prefab;

        [Header("Position Settings")]
        [Tooltip("Base position offset from spawn location (e.g., player position or platform position).")]
        public Vector3 offset;

        [Tooltip("Random +/- variance applied to the offset on each axis.\nExample: (1, 0, 0) means the X position will vary by +/- 1.")]
        public Vector3 offsetRandom;

        [Header("Rotation Settings")]
        [Tooltip("Base rotation in Euler angles (degrees).")]
        public Vector3 rotation;

        [Tooltip("Random +/- variance applied to the rotation on each axis.\nExample: (0, 180, 0) means the Y rotation will vary by +/- 180 degrees.")]
        public Vector3 rotationRandom;

        [Header("Lifetime Settings")]
        [Tooltip("Lifetime in seconds. -1 = auto-cleanup based on ParticleSystem/AudioSource, 0 or unset = use default (5s), positive = custom lifetime.")]
        public float lifetime;

        /// <summary>
        /// Calculates the final position offset by applying the random range to the base offset.
        /// </summary>
        public Vector3 GetRandomizedOffset()
        {
            return offset + new Vector3(
                Random.Range(-offsetRandom.x, offsetRandom.x),
                Random.Range(-offsetRandom.y, offsetRandom.y),
                Random.Range(-offsetRandom.z, offsetRandom.z)
            );
        }

        /// <summary>
        /// Calculates the final rotation quaternion by applying the random range to the base rotation.
        /// </summary>
        public Quaternion GetRandomizedRotation()
        {
            Vector3 finalEuler = rotation + new Vector3(
                Random.Range(-rotationRandom.x, rotationRandom.x),
                Random.Range(-rotationRandom.y, rotationRandom.y),
                Random.Range(-rotationRandom.z, rotationRandom.z)
            );
            return Quaternion.Euler(finalEuler);
        }

        /// <summary>
        /// Helper method to create an EffectData with default values.
        /// </summary>
        public static EffectData Default()
        {
            return new EffectData
            {
                prefab = null,
                offset = Vector3.zero,
                offsetRandom = Vector3.zero,
                rotation = Vector3.zero,
                rotationRandom = Vector3.zero,
                lifetime = -1f // Default to auto-cleanup
            };
        }
    }

    /// <summary>
    /// ScriptableObject that defines effects and behavior for a gift action.
    /// Used to configure persistent effects, one-time effects, grid motion, and optional cutscenes.
    /// </summary>
    [CreateAssetMenu(fileName = "NewGiftActionData", menuName = "Douyin Live/Gift Action Data")]
    public class GiftActionData : ScriptableObject
    {
        [Header("Grid Motion")]
        [Tooltip("Number of levels to move. Positive = up, Negative = down.")]
        public int levelsToMove = 0;

        [Header("Persistent Effects")]
        [Tooltip("Effect prefabs that persist during the entire grid motion. These will be instantiated at player position (with offset), parented to player (so they follow during movement), and cleaned up when movement finishes. Prefabs should have ParticleSystem or AudioSource components.")]
        public List<EffectData> persistentEffects = new List<EffectData>();

        [Header("One-Time Effects")]
        [Tooltip("Effect prefabs that play once when gift is received. These will be instantiated at player position (with offset) and auto-cleanup when finished.\n\nAuto-Cleanup Detection:\n• ParticleSystem: Waits until isPlaying=false AND particleCount=0 (all particles disappeared)\n• AudioSource: Waits until isPlaying=false (audio clip finished)\n• Other: Falls back to lifetime or 5 second timer\n\nPrefabs should have ParticleSystem or AudioSource components for proper cleanup.")]
        public List<EffectData> oneTimeEffects = new List<EffectData>();

        [Header("Floor Break Effects (Extra)")]
        [Tooltip("Effect prefabs that play when a platform breaks while this gift's grid motion is ongoing. These effects are spawned at the broken platform's position (with offset). Leave empty if this gift doesn't need extra break effects.")]
        public List<EffectData> floorBreakEffects = new List<EffectData>();

        [Header("Cutscene (Optional)")]
        [Tooltip("If assigned, a cutscene will play when this gift is received. You decide which gifts get cutscenes.")]
        public YF_3DGameBase.SO_CutsceneData cutsceneData;

        [Tooltip("If true, cutscene will be queued to play after the current cutscene finishes. If false, cutscene will try to play immediately (and fail if one is already playing).")]
        public bool queueCutscene = true;
    }
}