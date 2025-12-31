public interface IDataReceiver
{
    void OnReceive(ResourceType type, int amount, DamageData info = null);
}