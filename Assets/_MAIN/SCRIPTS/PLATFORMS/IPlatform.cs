using UnityEngine;

public interface IPlatform
{
    // Physics: Used by HeroController to add momentum
    Vector3 GetVelocity();
    // Logic: Used by HeroInteractor to trigger Score/Damage
    void OnStand(GameObject subject);
    // Pooling: Used by LevelGenerator to reset the platform
    void ResetState();
}