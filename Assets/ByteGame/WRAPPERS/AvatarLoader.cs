using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.UI;

namespace DouyinGame.Core
{
    /// <summary>
    /// Handles downloading and caching user avatars.
    /// It is separate so you can use it for UI lists, 3D characters, or leaderboards.
    /// </summary>
    public class AvatarLoader : MonoBehaviour
    {
        public static AvatarLoader Instance { get; private set; }

        // Cache: Stores downloaded sprites so we don't download the same one twice.
        private Dictionary<string, Sprite> _headCache = new Dictionary<string, Sprite>();
        // Track textures for cleanup
        private Dictionary<string, Texture2D> _textureCache = new Dictionary<string, Texture2D>();

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private void OnDestroy()
        {
            // Cleanup textures and sprites to prevent memory leaks
            foreach (var texture in _textureCache.Values)
            {
                if (texture != null)
                {
                    Destroy(texture);
                }
            }
            _textureCache.Clear();
            _headCache.Clear();
        }

        /// <summary>
        /// Load avatar into a UI Image component
        /// </summary>
        public void LoadAvatar(string url, Image targetImage)
        {
            if (string.IsNullOrEmpty(url) || targetImage == null)
            {
                Debug.LogWarning("[AvatarLoader] Invalid URL or target Image");
                return;
            }

            if (_headCache.ContainsKey(url))
            {
                targetImage.sprite = _headCache[url];
            }
            else
            {
                StartCoroutine(DownloadImageRoutine(url, (sprite) => {
                    if (targetImage != null) targetImage.sprite = sprite;
                }));
            }
        }

        /// <summary>
        /// Load avatar into a 3D World SpriteRenderer
        /// </summary>
        public void LoadAvatar(string url, SpriteRenderer targetRenderer)
        {
            if (string.IsNullOrEmpty(url) || targetRenderer == null)
            {
                Debug.LogWarning("[AvatarLoader] Invalid URL or target SpriteRenderer");
                return;
            }

            if (_headCache.ContainsKey(url))
            {
                targetRenderer.sprite = _headCache[url];
                targetRenderer.size = new Vector2(2, 2); // Maintain the size logic from original script
            }
            else
            {
                StartCoroutine(DownloadImageRoutine(url, (sprite) => {
                    if (targetRenderer != null)
                    {
                        targetRenderer.sprite = sprite;
                        targetRenderer.size = new Vector2(2, 2);
                    } 
                }));
            }
        }

        // The actual download logic
        private IEnumerator DownloadImageRoutine(string url, System.Action<Sprite> onCompleted)
        {
            using (UnityWebRequest www = UnityWebRequestTexture.GetTexture(url))
            {
                yield return www.SendWebRequest();

                if (www.result == UnityWebRequest.Result.Success)
                {
                    Texture2D tex = DownloadHandlerTexture.GetContent(www);
                    
                    if (tex == null)
                    {
                        Debug.LogError($"[AvatarLoader] Failed to get texture from response: {url}");
                        onCompleted?.Invoke(null);
                        yield break;
                    }
                    
                    // Create a sprite from the texture
                    Sprite newSprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f));
                    
                    // Cache both sprite and texture for proper cleanup
                    if (!_headCache.ContainsKey(url))
                    {
                        _headCache.Add(url, newSprite);
                        _textureCache.Add(url, tex);
                    }
                    else
                    {
                        // If somehow we got here with a cached entry, destroy the duplicate texture
                        Destroy(tex);
                    }

                    onCompleted?.Invoke(newSprite);
                }
                else
                {
                    Debug.LogError($"[AvatarLoader] Download failed: {url} | Error: {www.error}");
                    onCompleted?.Invoke(null);
                }
            }
        }
    }
}
