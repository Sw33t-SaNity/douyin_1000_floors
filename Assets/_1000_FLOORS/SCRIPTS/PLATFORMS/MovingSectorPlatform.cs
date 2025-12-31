using UnityEngine;

public class MovingSectorPlatform : BasePlatform
{
    public int scoreValue = 1;
    private bool _hasGivenScore = false;

    public override void OnStand(GameObject subject)
    {
        // Only run if we haven't paid out yet
        if (_hasGivenScore) return;
        subject.GetComponent<IDataReceiver>().OnReceive(ResourceType.Score, scoreValue);
        _hasGivenScore = true;
    }

    public override void ResetState()
    {
        base.ResetState();
        StopAllCoroutines();
        _hasGivenScore = false;
    }
}