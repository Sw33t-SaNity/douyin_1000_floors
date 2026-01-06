using UnityEngine;
using System.Collections.Generic;
using DinoFracture;

#if UNITY_EDITOR
using UnityEditor;
#endif


namespace ThousandFloors
{
    [ExecuteAlways]
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer), typeof(MeshCollider))]
    public class SectorPlatformMeshGenerator : MonoBehaviour
    {
        // ... [Your existing Variable Headers remain the same] ...
        [Header("Dimensions")]
        [Range(10f, 360f)] public float angleWidth = 45f;
        [Min(0f)] public float innerRadius = 0f;
        [Min(0.1f)] public float outerRadius = 5.0f;
        public float height = 0.5f;
        [Range(0f, 1f)] public float bevel = 0.2f;

        [Header("Detail")]
        [Range(2, 64)] public int segments = 16;
        [Tooltip("Tiles per meter")] public float uvScale = 1.0f;
        public bool snapTextureX = true; 
        public bool useMultipleMaterials = true;

        // Internal Meshes
        private Mesh _uniqueMesh;
        private MeshFilter _meshFilter;
        private MeshCollider _meshCollider;

        struct ProfilePoint { public Vector3 pos; public float vCoord; public int matIndex; }

        void Awake() 
        { 
            InitializeMesh();
    #if UNITY_EDITOR
            if (!Application.isPlaying)
            {
                EditorApplication.delayCall += GenerateMesh;
                return;
            }
    #endif
            GenerateMesh();
        }

        void OnValidate() 
        { 
            if (innerRadius >= outerRadius) innerRadius = outerRadius - 0.01f; 

    #if UNITY_EDITOR
            // Delaying the call to GenerateMesh prevents the "SendMessage cannot be called during OnValidate" error.
            EditorApplication.delayCall -= GenerateMesh;
            EditorApplication.delayCall += GenerateMesh;
    #else
            GenerateMesh();
    #endif
        }

        // New Function: Ensures we have a valid, unique mesh instance
        void InitializeMesh()
        {
            if (_meshFilter == null) _meshFilter = GetComponent<MeshFilter>();
            if (_meshCollider == null) _meshCollider = GetComponent<MeshCollider>();

            // Only create a new mesh if we don't have one yet
            if (_uniqueMesh == null)
            {
                _uniqueMesh = new Mesh();
                _uniqueMesh.name = "Procedural_Instance_" + GetInstanceID();
                _uniqueMesh.MarkDynamic(); // Optimizes the mesh for frequent updates
            }

            _meshFilter.sharedMesh = _uniqueMesh;
            _meshCollider.sharedMesh = _uniqueMesh;
        }

        public void GenerateMesh()
        {
    #if UNITY_EDITOR
            // Safety check: the object might have been destroyed before the delayed call fires.
            if (this == null) return;
    #endif

            // 1. Ensure we have our unique mesh ready
    #if UNITY_EDITOR
            // In Editor mode (not playing), avoiding memory leaks is tricky. 
            // We create a temp mesh just for visualization.
            if (!Application.isPlaying)
            {
                if (_meshFilter == null) _meshFilter = GetComponent<MeshFilter>();
                
                // Optimization: Clean up previous temp mesh to prevent memory leaks in the Editor
                if (_meshFilter.sharedMesh != null && _meshFilter.sharedMesh.name == "Editor_Temp")
                {
                    DestroyImmediate(_meshFilter.sharedMesh);
                }

                Mesh tempMesh = new Mesh();
                tempMesh.name = "Editor_Temp";
                FillMesh(tempMesh); // Fill the data
                _meshFilter.sharedMesh = tempMesh; // Use sharedMesh to avoid implicit copying
                return;
            }
    #endif
            
            // In Runtime, strictly use our unique instance
            InitializeMesh();
            FillMesh(_uniqueMesh);
            
            // Force Collider Update
            _meshCollider.sharedMesh = null; // Detach to force refresh
            _meshCollider.sharedMesh = _uniqueMesh; // Reattach

            // Notify DinoFracture that the mesh data has changed
            if (TryGetComponent<FractureGeometry>(out var fracture))
            {
                fracture.CheckMeshValidity();
            }
        }

        /// <summary>
        /// Returns the local Y-axis angle of the center of the generated mesh.
        /// Based on the current FillMesh logic (starts at South/180 and moves towards East/90).
        /// </summary>
        public float GetLocalCenterAngle()
        {
            return 180f - (angleWidth * 0.5f);
        }

        // I moved the math logic into a separate function to keep things clean
        void FillMesh(Mesh mesh)
        {
            mesh.Clear();

            List<Vector3> verts = new List<Vector3>();
            List<Vector2> uvs = new List<Vector2>();
            List<Vector3> normals = new List<Vector3>();
            List<int>[] tris = new List<int>[] { new List<int>(), new List<int>(), new List<int>() };

            // --- MATH LOGIC (Same as before) ---
            float midRadius = innerRadius + (outerRadius - innerRadius) * 0.5f;
            float totalArcLength = midRadius * angleWidth * Mathf.Deg2Rad;
            float finalTileCountX = totalArcLength * uvScale;
            if (snapTextureX) finalTileCountX = Mathf.Max(1, Mathf.Round(finalTileCountX));

            float h = height / 2f;
            float bevelSize = Mathf.Min(bevel, (outerRadius - innerRadius) * 0.5f, height * 0.5f); 
            float dTop = (outerRadius - bevelSize) - innerRadius;
            float dBevel = Mathf.Sqrt(bevelSize*bevelSize + bevelSize*bevelSize);
            float dSide = (height - 2*bevelSize);
            float dBot = dTop;
            float dInner = height;

            ProfilePoint[] p = new ProfilePoint[] {
                new ProfilePoint { pos = new Vector3(innerRadius, h, 0),       vCoord = 0,               matIndex = 0 }, 
                new ProfilePoint { pos = new Vector3(outerRadius - bevelSize, h, 0),   vCoord = dTop,    matIndex = 0 }, 
                new ProfilePoint { pos = new Vector3(outerRadius, h - bevelSize, 0),   vCoord = dTop + dBevel,   matIndex = 1 }, 
                new ProfilePoint { pos = new Vector3(outerRadius, -h, 0),      vCoord = dTop+dBevel+dSide, matIndex = 1 }, 
                new ProfilePoint { pos = new Vector3(innerRadius, -h, 0),      vCoord = dTop+dBevel+dSide+dBot, matIndex = 0 },
                new ProfilePoint { pos = new Vector3(innerRadius, h, 0),       vCoord = dTop+dBevel+dSide+dBot+dInner, matIndex = 0 } // Close the loop
            };

            float angleStep = angleWidth / segments;

            for (int i = 0; i <= segments; i++)
            {
                float angle = i * angleStep;
                float rad = (angle - 90) * Mathf.Deg2Rad;
                Vector3 dir = new Vector3(Mathf.Cos(rad), 0, Mathf.Sin(rad));
                float u = ((float)i / segments) * finalTileCountX;

                for (int k = 0; k < p.Length; k++)
                {
                    verts.Add(dir * p[k].pos.x + Vector3.up * p[k].pos.y);
                    Vector3 n = Vector3.up; 
                    if (k == 2 || k == 3) n = dir; 
                    else if (k == 4) n = Vector3.down;
                    else if (k == 1) n = (Vector3.up + dir).normalized;
                    else if (k == 5 || k == 0) n = -dir; // Inner wall faces inward
                    normals.Add(n);
                    uvs.Add(new Vector2(u, p[k].vCoord * uvScale));
                }

                if (i > 0)
                {
                    int currSlice = i * p.Length;
                    int prevSlice = (i - 1) * p.Length;
                    for (int k = 0; k < p.Length - 1; k++)
                    {
                        int submesh = (k == 1 || k == 2) ? 1 : 0;
                        int idx0 = prevSlice + k, idx1 = prevSlice + k + 1, idx2 = currSlice + k + 1, idx3 = currSlice + k;
                        tris[submesh].Add(idx0); tris[submesh].Add(idx3); tris[submesh].Add(idx1);
                        tris[submesh].Add(idx1); tris[submesh].Add(idx3); tris[submesh].Add(idx2);
                    }
                }
            }

            // CAPS
            GenerateCap(tris[2], verts, uvs, normals, p, 0, true);  
            GenerateCap(tris[2], verts, uvs, normals, p, segments, false); 

            // ASSIGN
            mesh.SetVertices(verts);
            mesh.SetUVs(0, uvs);
            mesh.SetNormals(normals);
            mesh.RecalculateTangents(); 

            if (useMultipleMaterials) {
                mesh.subMeshCount = 3;
                mesh.SetTriangles(tris[0], 0);
                mesh.SetTriangles(tris[1], 1);
                mesh.SetTriangles(tris[2], 2);
            } else {
                mesh.subMeshCount = 1;
                List<int> all = new List<int>();
                all.AddRange(tris[0]); all.AddRange(tris[1]); all.AddRange(tris[2]);
                mesh.SetTriangles(all, 0);
            }
            mesh.RecalculateBounds();
        }

        void GenerateCap(List<int> triList, List<Vector3> verts, List<Vector2> uvs, List<Vector3> normals, ProfilePoint[] p, int sliceIndex, bool isStart)
        {
            int baseIdx = verts.Count;
            int sliceOffset = sliceIndex * p.Length;
            Vector3 faceNormal = Vector3.Cross(Vector3.up, (verts[sliceOffset+1] - verts[sliceOffset]).normalized); 
            if (isStart) faceNormal = -faceNormal;

            for(int k=0; k<p.Length; k++) {
                verts.Add(verts[sliceOffset + k]);
                normals.Add(faceNormal);
                uvs.Add(new Vector2(p[k].pos.x * uvScale, p[k].pos.y * uvScale)); 
            }
            for(int k=1; k < p.Length-1; k++) {
                if (isStart) { triList.Add(baseIdx); triList.Add(baseIdx + k); triList.Add(baseIdx + k + 1); } 
                else { triList.Add(baseIdx); triList.Add(baseIdx + k + 1); triList.Add(baseIdx + k); }
            }
        }
    }
}