using UnityEngine;
using System.Collections.Generic;

namespace ThousandFloors
{
    public class FloorsManager : MonoBehaviour
    {
        public static FloorsManager Instance { get; private set; }

        [Header("References")]
        public Transform player; 
        public GameObject platformPrefab;
        public GameObject scoreEffectPrefab;
        public GameObject breakEffectPrefab;

        [Header("Grid Settings")]
        [Tooltip("How far apart platforms are vertically.")]
        public float verticalDistance = 4f;
        
        [Tooltip("How many platforms to keep ABOVE the player. Set to 0 or 1 for 'destruction' effect.")]
        public int visibleAbove = 1; 
        
        [Tooltip("How many platforms to generate BELOW the player.")]
        public int visibleBelow = 10;

        [Header("Platform Parameters")]
        [Range(10f, 360f)] public float platformWidth = 90f; 
        
        [Header("Effect Settings")]
        public int effectPoolSize = 5;

        // --- INTERNAL STATE ---
        private Dictionary<int, GameObject> _activePlatforms = new Dictionary<int, GameObject>();
        private Queue<GameObject> _inactivePool = new Queue<GameObject>();
        private List<ParticleSystem> _effectPool = new List<ParticleSystem>();
        private List<ParticleSystem> _breakEffectPool = new List<ParticleSystem>();
        private int _lastPlayerIndex = int.MaxValue;
        private int _forcedTargetIndex = int.MinValue;

        // ========================================================================
        // RUNTIME LOGIC
        // ========================================================================

        void Awake()
        {
            Instance = this;
        }

        private void OnEnable()
        {
            ThousandFloorsEvents.OnScoreChanged += HandleScoreChanged;
            ThousandFloorsEvents.OnHeroMoveStarted += HandleHeroMoveStarted;
            ThousandFloorsEvents.OnHeroMoveCompleted += HandleHeroMoveCompleted;
        }

        private void OnDisable()
        {
            ThousandFloorsEvents.OnScoreChanged -= HandleScoreChanged;
            ThousandFloorsEvents.OnHeroMoveStarted -= HandleHeroMoveStarted;
            ThousandFloorsEvents.OnHeroMoveCompleted -= HandleHeroMoveCompleted;
        }

        private void HandleHeroMoveStarted(int start, int target)
        {
            _forcedTargetIndex = target;
            UpdateLevel(GetLevelIndex(player.position.y));
        }

        private void HandleHeroMoveCompleted(int start, int target)
        {
            _forcedTargetIndex = int.MinValue;
        }

        private void HandleScoreChanged(int delta, Vector3 worldPos, bool isProgress)
        {
            if (isProgress || delta > 0) PlayScoreEffect(worldPos);
        }

        void Start()
        {
            // Pre-warm pools once at start
            for (int i = 0; i < visibleBelow + visibleAbove + 10; i++)
            {
                GameObject p = CreateNewPlatform();
                p.SetActive(false);
                _inactivePool.Enqueue(p);
            }

            for (int i = 0; i < effectPoolSize; i++)
            {
                CreateNewScoreEffect();
                CreateNewBreakEffect();
            }
        }

        void Update()
        {
            if (player == null) return;

            // 1. Calculate Player's "Grid Index" using Rounding for consistency with motion logic
            int playerIndex = GetLevelIndex(player.position.y);

            // 2. Only run logic if player moved to a new vertical "slot"
            if (playerIndex != _lastPlayerIndex)
            {
                UpdateLevel(playerIndex);
                _lastPlayerIndex = playerIndex;
            }
        }

        void UpdateLevel(int centerIndex)
        {
            int minIndex = centerIndex - visibleBelow;
            
            // Normally only show platforms up to visibleAbove. 
            // But if we are in a forced move, ensure we show up to the target.
            int maxIndex = Mathf.Max(centerIndex + visibleAbove, _forcedTargetIndex);

            // A. RECYCLE: Identify platforms that are now out of range
            List<int> indicesToRemove = new List<int>();

            foreach (var kvp in _activePlatforms)
            {
                if (kvp.Key < minIndex || kvp.Key > maxIndex)
                {
                    indicesToRemove.Add(kvp.Key);
                }
            }

            foreach (int index in indicesToRemove)
            {
                RecyclePlatform(index);
            }

            // B. SPAWN: Identify missing platforms in range
            // Iterate downwards so we process closest to player first
            for (int i = maxIndex; i >= minIndex; i--)
            {
                if (!_activePlatforms.ContainsKey(i))
                {
                    SpawnPlatformAtIndex(i);
                }
            }

            // C. REFRESH: Update visibility for all active platforms based on new player position
            foreach (var kvp in _activePlatforms)
            {
                if (kvp.Value.TryGetComponent<PlatformVisualHandler>(out var vh))
                {
                    // If we are in a forced move, don't touch platforms in the jump path.
                    // They are managed by events in GridMotionManager.
                    if (_forcedTargetIndex > centerIndex && kvp.Key > centerIndex && kvp.Key <= _forcedTargetIndex)
                    {
                        continue; 
                    }

                    int naturalMax = centerIndex + visibleAbove;
                    bool shouldBeVisible = kvp.Key <= naturalMax;
                    vh.SetVisible(shouldBeVisible, false);
                }
            }
        }

        GameObject CreateNewPlatform()
        {
            GameObject p = Instantiate(platformPrefab, Vector3.zero, Quaternion.identity);
            
            // Ensure platforms are parented to the cylinder center so they rotate with the tower
            if (player != null && player.TryGetComponent<CylinderMovementModifier>(out var mod) && mod.cylinderCenter != null)
            {
                p.transform.parent = mod.cylinderCenter;
            }
            else
            {
                p.transform.parent = this.transform;
            }
            
            // Ensure Physics settings
            Rigidbody rb = p.GetComponent<Rigidbody>();
            if (rb == null) rb = p.AddComponent<Rigidbody>();
            rb.isKinematic = true; 
            rb.useGravity = false;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousSpeculative;
            
            return p;
        }
        /// <summary>
        /// Returns the platform GameObject at the specified level index if it is currently active.
        /// </summary>
        public bool GetPlatform(int index, out GameObject platform)
        {
            return _activePlatforms.TryGetValue(index, out platform);
        }        void SpawnPlatformAtIndex(int index)
        {
            GameObject p;

            if (_inactivePool.Count > 0)
            {
                p = _inactivePool.Dequeue();
            }
            else
            {
                p = CreateNewPlatform();
            }

            p.SetActive(true);
            p.name = $"Platform_Level_{index}";
            _activePlatforms.Add(index, p);

            // Set Position
            float yPos = index * verticalDistance;
            p.transform.position = new Vector3(0, yPos, 0);
            
            // Sync Rigidbody
            if (p.TryGetComponent<Rigidbody>(out Rigidbody rb)) rb.position = new Vector3(0, yPos, 0);

            ConfigurePlatform(p, index);
        }

        void RecyclePlatform(int index)
        {
            if (_activePlatforms.TryGetValue(index, out GameObject p))
            {
                p.SetActive(false);
                _activePlatforms.Remove(index);
                _inactivePool.Enqueue(p);
            }
        }

        void ConfigurePlatform(GameObject p, int seedIndex)
        {
            // 1. BETTER RANDOMNESS (Spatial Hash)
            // This ensures sequential indices (1, 2, 3) produce non-sequential results
            int hashedSeed = 0;
            unchecked 
            {
                hashedSeed = (seedIndex * 73856093) ^ (seedIndex * 19349663) ^ (seedIndex * 83492791);
            }
            
            System.Random rng = new System.Random(hashedSeed);

            // 2. Calculate Rotation (0 to 360)
            float randomRotation = (float)rng.NextDouble() * 360f;
            Quaternion newRot = Quaternion.Euler(0, randomRotation, 0);
            
            // Use localRotation so the platform's orientation is relative to the tower
            p.transform.localRotation = newRot;
            if (p.TryGetComponent<Rigidbody>(out Rigidbody rb)) rb.rotation = p.transform.rotation;

            // 3. Generate Mesh (Resize) - DO THIS BEFORE VISIBILITY
            // We must update the mesh while the collider is technically active 
            // to ensure the physics bake happens correctly.
            SectorPlatformMeshGenerator gen = p.GetComponent<SectorPlatformMeshGenerator>();
            if (gen != null)
            {
                if (Mathf.Abs(gen.angleWidth - platformWidth) > 0.01f)
                {
                    gen.angleWidth = platformWidth;
                    gen.GenerateMesh();
                }
            }

            // 2.5 Link Visual Handler and Reset State
            PlatformVisualHandler vh = p.GetComponent<PlatformVisualHandler>(); 
            if (vh != null)
            {
                vh.levelIndex = seedIndex;
                
                // Auto-link the fracture component if not set
                if (vh.fractureComponent == null)
                {
                    vh.fractureComponent = p.GetComponentInChildren<DinoFracture.FractureGeometry>();
                }

                vh.RegisterFractureListener();
                
                // Initial visibility should only respect the immediate player vicinity.
                int playerLevel = GetLevelIndex(player.position.y);
                int naturalMax = playerLevel + (_forcedTargetIndex > playerLevel ? 0 : visibleAbove);
                bool shouldBeVisible = seedIndex <= naturalMax;
                vh.SetVisible(shouldBeVisible, false);
            }

            // 2.6 Link Scoring Trigger
            ScoringTrigger st = p.GetComponentInChildren<ScoringTrigger>();
            if (st != null) st.levelIndex = seedIndex;

            // 3. Reset Internal State (Animation/Movement)
            MovingSectorPlatform mp = p.GetComponent<MovingSectorPlatform>();
            if (mp != null) 
            {
                mp.ResetState();
            }
        }

        private ParticleSystem CreateNewScoreEffect()
        {
            if (scoreEffectPrefab == null) return null;
            
            GameObject go = Instantiate(scoreEffectPrefab, transform);
            go.SetActive(true);
            ParticleSystem ps = go.GetComponentInChildren<ParticleSystem>();
            if (ps != null)
            {
                _effectPool.Add(ps);
            }
            return ps;
        }

        private ParticleSystem CreateNewBreakEffect()
        {
            if (breakEffectPrefab == null) return null;
            
            GameObject go = Instantiate(breakEffectPrefab, transform);
            go.SetActive(true);
            ParticleSystem ps = go.GetComponentInChildren<ParticleSystem>();
            if (ps != null)
            {
                _breakEffectPool.Add(ps);
            }
            return ps;
        }

        public void PlayScoreEffect(Vector3 position)
        {
            if (scoreEffectPrefab == null) return;

            ParticleSystem effect = null;
            for (int i = 0; i < _effectPool.Count; i++)
            {
                if (_effectPool[i] == null) continue;

                // Optimization: If the system is not currently emitting, it's ready to be reused.
                // Since Simulation Space is set to World, moving the emitter won't teleport 
                // particles that are already in the air.
                if (!_effectPool[i].isPlaying)
                {
                    effect = _effectPool[i];
                    break;
                }
            }

            if (effect == null) effect = CreateNewScoreEffect();

            if (effect == null) return;

            effect.transform.position = position;
            effect.Play(true); // Play the system and all its children
        }

        public void PlayBreakEffect(Vector3 position)
        {
            if (breakEffectPrefab == null) return;

            ParticleSystem effect = null;
            for (int i = 0; i < _breakEffectPool.Count; i++)
            {
                if (_breakEffectPool[i] == null) continue;

                if (!_breakEffectPool[i].isPlaying)
                {
                    effect = _breakEffectPool[i];
                    break;
                }
            }

            if (effect == null) effect = CreateNewBreakEffect();
            if (effect == null) return;

            effect.transform.position = position;
            effect.Play(true);
        }

        // ========================================================================
        // GRID SYSTEM API
        // ========================================================================

        public float GetPlatformY(int levelIndex)
        {
            return levelIndex * verticalDistance;
        }

        public int GetLevelIndex(float yPosition)
        {
            return Mathf.RoundToInt(yPosition / verticalDistance);
        }

        public void DestroyPlatformsInRange(int minIndex, int maxIndex)
        {
            List<int> toRemove = new List<int>();
            foreach (var kvp in _activePlatforms)
            {
                if (kvp.Key >= minIndex && kvp.Key <= maxIndex)
                {
                    toRemove.Add(kvp.Key);
                }
            }

            foreach (int index in toRemove)
            {
                RecyclePlatform(index);
            }
        }

        // ========================================================================
        // EDITOR PREVIEW LOGIC
        // ========================================================================

        public void GeneratePreview()
        {
            ClearAllChildPlatforms();

            // Generate a snapshot around 0,0,0
            for (int i = visibleAbove; i >= -visibleBelow; i--)
            {
                SpawnPreviewPlatform(i);
            }
        }

        public void ClearAllChildPlatforms()
        {
            // Destroy all children of this generator
            // While loop is safer for DestroyImmediate in Editor
            while (transform.childCount > 0)
            {
                DestroyImmediate(transform.GetChild(0).gameObject);
            }
            
            _activePlatforms.Clear();
            _inactivePool.Clear();
            _lastPlayerIndex = int.MaxValue;
        }

        private void SpawnPreviewPlatform(int index)
        {
            if (platformPrefab == null) return;

            // Instantiate normally (No pooling in Editor Mode)
            GameObject p = Instantiate(platformPrefab, Vector3.zero, Quaternion.identity);
            p.transform.parent = this.transform;
            p.name = $"Preview_Platform_{index}";

            Rigidbody rb = p.GetComponent<Rigidbody>();
            if (rb == null) rb = p.AddComponent<Rigidbody>();
            rb.isKinematic = true;
            rb.useGravity = false;

            float yPos = index * verticalDistance;
            p.transform.position = new Vector3(0, yPos, 0);
            
            ConfigurePlatform(p, index);
        }
    }
}