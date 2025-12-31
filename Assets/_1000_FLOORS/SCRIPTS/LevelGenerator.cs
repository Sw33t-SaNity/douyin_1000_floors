using UnityEngine;
using System.Collections.Generic;

public class LevelGenerator : MonoBehaviour
{
    [Header("References")]
    public Transform player; 
    public GameObject platformPrefab;

    [Header("Grid Settings")]
    [Tooltip("How far apart platforms are vertically.")]
    public float verticalDistance = 4f;
    
    [Tooltip("How many platforms to keep ABOVE the player. Set to 0 or 1 for 'destruction' effect.")]
    public int visibleAbove = 1; 
    
    [Tooltip("How many platforms to generate BELOW the player.")]
    public int visibleBelow = 10;

    [Header("Platform Parameters")]
    [Range(10f, 360f)] public float platformWidth = 90f; 
    
    // --- INTERNAL STATE ---
    private Dictionary<int, GameObject> _activePlatforms = new Dictionary<int, GameObject>();
    private Queue<GameObject> _inactivePool = new Queue<GameObject>();
    private int _lastPlayerIndex = int.MaxValue;

    // ========================================================================
    // RUNTIME LOGIC
    // ========================================================================

    void Start()
    {
        // 1. CLEANUP: Destroy any preview objects left over from the Editor
        ClearAllChildPlatforms();

        if (player == null)
        {
            Debug.LogError("LevelGenerator: Player Transform is not assigned!");
            return;
        }

        // 2. RUNTIME INITIALIZATION (Pool Pre-warming)
        for (int i = 0; i < visibleBelow + visibleAbove + 5; i++)
        {
            GameObject p = CreateNewPlatform();
            p.SetActive(false);
            _inactivePool.Enqueue(p);
        }
    }

    void Update()
    {
        if (player == null) return;

        // 1. Calculate Player's "Grid Index" (World Y / Distance)
        int playerIndex = Mathf.FloorToInt(player.position.y / verticalDistance);

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
        int maxIndex = centerIndex + visibleAbove;

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
    }

    GameObject CreateNewPlatform()
    {
        GameObject p = Instantiate(platformPrefab, Vector3.zero, Quaternion.identity);
        p.transform.parent = this.transform;
        
        // Ensure Physics settings
        Rigidbody rb = p.GetComponent<Rigidbody>();
        if (rb == null) rb = p.AddComponent<Rigidbody>();
        rb.isKinematic = true; 
        rb.useGravity = false;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousSpeculative;
        
        return p;
    }

    void SpawnPlatformAtIndex(int index)
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
        
        p.transform.rotation = newRot;
        if (p.TryGetComponent<Rigidbody>(out Rigidbody rb)) rb.rotation = newRot;

        // 3. Reset Internal State (Animation/Movement)
        MovingSectorPlatform mp = p.GetComponent<MovingSectorPlatform>();
        if (mp != null) mp.ResetState();

        // 4. Generate Mesh (Resize)
        SectorPlatformMeshGenerator gen = p.GetComponent<SectorPlatformMeshGenerator>();
        if (gen != null)
        {
            gen.angleWidth = platformWidth;
            gen.GenerateMesh();
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