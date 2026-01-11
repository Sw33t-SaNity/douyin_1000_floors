using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using DinoFracture;
using AmazingAssets.AdvancedDissolve;

namespace ThousandFloors
{
    /// <summary>
    /// Handles the visual lifecycle of a platform: breaking (via DinoFracture) 
    /// and reappearing (via AdvancedDissolve).
    /// </summary>
    public class PlatformVisualHandler : MonoBehaviour
    {
        public enum VisualState { Normal, Hidden, Dissolving, Fractured }

        #region Inspector Settings
        public int levelIndex;
        
        [Header("References")]
        public GameObject normalVisual;
        public GameObject fracturedPrefab;
        public FractureGeometry fractureComponent;
        
        [Header("Dissolve Settings")]
        [Tooltip("If empty, will automatically find all renderers in normalVisual")]
        public Renderer[] platformRenderers;
        public float dissolveDuration = 0.8f;
        #endregion

        #region Internal State
        private VisualState _currentState = VisualState.Normal;
        private List<Material> _materials = new List<Material>();

        /// <summary>
        /// Returns the current visual state of the platform.
        /// </summary>
        public VisualState CurrentState => _currentState;
        #endregion

        #region Unity Lifecycle
        private void Awake()
        {
            // Auto-populate renderers if not assigned manually
            if ((platformRenderers == null || platformRenderers.Length == 0) && normalVisual != null)
            {
                platformRenderers = normalVisual.GetComponentsInChildren<Renderer>(true);
            }

            // Instantiate renderer materials via renderer.materials (Unity creates unique instances)
            _materials.Clear();
            if (platformRenderers != null)
            {
                foreach (var r in platformRenderers)
                {
                    if (r != null)
                    {
                        var mats = r.materials; // this property instantiates shared materials
                        if (mats != null) _materials.AddRange(mats);
                    }
                }
            }
        }

        private void OnEnable()
        {
            // GUARD: If this is a shard (cloned from a platform), disable this script.
            // Shards are temporary physics objects and shouldn't manage logic.
            if (GetComponent<FracturedObject>() != null)
            {
                enabled = false;
                return;
            }

            ThousandFloorsEvents.OnPlatformStateRequest += HandleStateRequest;
            ThousandFloorsEvents.OnPlatformBroken += HandlePlatformBroken;
        }

        private void OnDisable()
        {
            ThousandFloorsEvents.OnPlatformStateRequest -= HandleStateRequest;
            ThousandFloorsEvents.OnPlatformBroken -= HandlePlatformBroken;
        }
        #endregion

        #region Public API
        /// <summary>
        /// Links this handler to the fracture component. 
        /// Called by FloorsManager after instantiating/recycling the platform.
        /// </summary>
        public void RegisterFractureListener()
        {
            if (fractureComponent != null)
            {
                // Unsubscribe first to prevent duplicate event triggers on recycled objects
                fractureComponent.OnFractureCompleted.RemoveListener(HandleFractureCompleted);
                fractureComponent.OnFractureCompleted.AddListener(HandleFractureCompleted);
            }
            else
            {
                Debug.LogWarning($"[PlatformVisualHandler] No FractureGeometry assigned on level {levelIndex}.");
            }
        }

        /// <summary>
        /// Resets the platform to its clean, unbroken state instantly.
        /// </summary>
        public void ResetVisuals()
        {
            SetVisible(true, playEffects: false);
        }

        public void Break()
        {
            SetVisible(false, playEffects: true);
        }

        public void Reappear()
        {
            SetVisible(true, playEffects: true);
        }
        #endregion

        #region Event Handlers
        private void HandleStateRequest(int level, bool shouldBeVisible)
        {
            if (level != levelIndex) return;

            if (shouldBeVisible && _currentState == VisualState.Hidden) Reappear();
            else if (!shouldBeVisible && _currentState == VisualState.Normal) Break();
        }

        private void HandlePlatformBroken(int level)
        {
            if (level == levelIndex) Break();
        }

        /// <summary>
        /// Callback from DinoFracture when the mesh generation is done.
        /// </summary>
        private void HandleFractureCompleted(OnFractureEventArgs args)
        {
            // Verify this event belongs to us
            if (fractureComponent == null || args.OriginalObject != fractureComponent) return;
            if (!args.IsValid || args.FracturePiecesRootObject == null) return;

            // 1. Hide the original mesh NOW (swapping clean mesh for broken shards)
            if (normalVisual != null)
            {
                var renderers = normalVisual.GetComponentsInChildren<Renderer>(true);
                foreach (var r in renderers) r.enabled = false;
            }

            // 2. Play FX via Manager
            if (FloorsManager.Instance != null)
            {
                FloorsManager.Instance.PlayBreakEffect(transform.position);
            }
        }
        #endregion

        #region Core Logic
        /// <summary>
        /// Ensures materials are instantiated (not shared) so dissolve effects work per-platform.
        /// </summary>
        private void EnsureMaterialsInstantiated()
        {
            if (platformRenderers == null || platformRenderers.Length == 0) return;

            if (_materials == null) _materials = new List<Material>();
            if (_materials.Count == 0)
            {
                foreach (var r in platformRenderers)
                {
                    if (r == null) continue;
                    var mats = r.materials; // instantiates if needed
                    if (mats != null) _materials.AddRange(mats);
                }
            }
        }

        /// <summary>
        /// Main toggle for platform visibility. Handles physical colliders and visual transitions.
        /// </summary>
        /// <param name="visible">Target state.</param>
        /// <param name="playEffects">If true, plays dissolve/fracture. If false, snaps instantly.</param>
        public void SetVisible(bool visible, bool playEffects)
        {
            VisualState targetState = visible ? VisualState.Normal : VisualState.Hidden;
            
            // Optimization: If already dissolving to the target state, let it finish
            if (visible && _currentState == VisualState.Dissolving && playEffects) return;

            if (!playEffects && _currentState == targetState) return;

            _currentState = targetState;
            StopAllCoroutines();

            if (platformRenderers == null || platformRenderers.Length == 0) return;

            // 1. Handle Colliders (Physics)
            // Triggers (like score zones) usually stay active; physical colliders toggle.
            var colliders = GetComponentsInChildren<Collider>(true);
            foreach (var c in colliders)
            {
                if (!c.isTrigger) c.enabled = visible;
            }

            switch (_currentState)
            {
                case VisualState.Normal: HandleReappear(playEffects); break;
                case VisualState.Hidden: HandleBreak(playEffects); break;
            }
        }

        private void HandleReappear(bool playEffects)
        {
            // Fix: Resync MeshCollider just in case DinoFracture messed with the sharedMesh
            if (TryGetComponent<MeshCollider>(out var mc) && TryGetComponent<MeshFilter>(out var mf))
            {
                mc.sharedMesh = null;
                mc.sharedMesh = mf.sharedMesh;
            }

            // Ensure materials are instantiated (in case they weren't in Awake)
            EnsureMaterialsInstantiated();

            // Enable renderers first so materials are accessible
            foreach (var r in platformRenderers) if (r != null) r.enabled = true;

            // If playing effects, set clip to 1 (invisible) first to avoid a 1-frame "pop".
            if (playEffects)
            {
                if (FloorsManager.Instance != null)
                {
                    FloorsManager.Instance.PlayReappearEffect(transform.position);
                }

                SetDissolveClip(1f);
                _currentState = VisualState.Dissolving;
                StartCoroutine(DissolveRoutine(1f, 0f)); // Fade In
            }
            else
            {
                SetDissolveClip(0f);
            }
        }

        private void HandleBreak(bool playEffects)
        {
            if (playEffects)
            {
                if (fractureComponent != null)
                {
                    _currentState = VisualState.Fractured;
                    // Force synchronous fracture to remove delay gaps
                    if (fractureComponent is RuntimeFracturedGeometry runtime)
                    {
                        runtime.Asynchronous = false;
                    }

                    // Fallback: If pre-fractured pieces are missing, instantiate them manually
                    if (fractureComponent is PreFracturedGeometry pre && pre.GeneratedPieces == null && fracturedPrefab != null)
                    {
                        pre.GeneratedPieces = Instantiate(fracturedPrefab, transform.position, transform.rotation, transform.parent);
                        pre.GeneratedPieces.SetActive(false);
                    }
                    
                    // Trigger fracture. Visuals will be hidden in HandleFractureCompleted callback.
                    fractureComponent.Fracture();
                }
                else if (normalVisual != null)
                {
                    // Fallback if no fracture component: just hide
                    foreach (var r in platformRenderers) if (r != null) r.enabled = false;
                    _currentState = VisualState.Hidden;
                }
            }
            else
            {
                SetDissolveClip(1f);
                foreach (var r in platformRenderers) if (r != null) r.enabled = false;
            }
        }

        private IEnumerator DissolveRoutine(float start, float end)
        {
            float elapsed = 0;
            while (elapsed < dissolveDuration)
            {
                float val = Mathf.Lerp(start, end, elapsed / dissolveDuration);
                SetDissolveClip(val);
                elapsed += Time.deltaTime;
                yield return null;
            }

            SetDissolveClip(end);
            if (end == 0f) _currentState = VisualState.Normal;
        }

        private void SetDissolveClip(float val)
        {
            if (_materials == null || _materials.Count == 0)
            {
                Debug.LogWarning($"[PlatformVisualHandler] No materials cached for level {levelIndex}. Cannot set dissolve clip.");
                return;
            }

            foreach (var mat in _materials)
            {
                if (mat != null)
                {
                    try
                    {
                        AdvancedDissolveProperties.Cutout.Standard.UpdateLocalProperty(mat, AdvancedDissolveProperties.Cutout.Standard.Property.Clip, val);
                    }
                    catch (System.Exception e)
                    {
                        Debug.LogWarning($"[PlatformVisualHandler] Failed to update dissolve property on material '{mat.name}': {e.Message}");
                    }
                }
            }
        }
        #endregion
    }
}