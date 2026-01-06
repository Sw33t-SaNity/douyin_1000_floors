using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.UI;

// This script handles downloading and caching user avatars.
// It is separate so you can use it for UI lists, 3D characters, or leaderboards.
public class AvatarLoader : MonoBehaviour
{
    public static AvatarLoader Instance { get; private set; }

    // Cache: Stores downloaded sprites so we don't download the same one twice.
    private Dictionary<string, Sprite> _headCache = new Dictionary<string, Sprite>();

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
    }

    /// <summary>
    /// Load avatar into a UI Image component
    /// </summary>
    public void LoadAvatar(string url, Image targetImage)
    {
        if (string.IsNullOrEmpty(url)) return;

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
        if (string.IsNullOrEmpty(url)) return;

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
                
                // Create a sprite from the texture
                Sprite newSprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f));
                
                // Cache it
                if (!_headCache.ContainsKey(url))
                {
                    _headCache.Add(url, newSprite);
                }

                onCompleted?.Invoke(newSprite);
            }
            else
            {
                Debug.LogError($"Avatar download failed: {url} | Error: {www.error}");
            }
        }
    }
}