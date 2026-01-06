namespace YF_3DGameBase
{
    public interface I_DataReceiver
    {
        void OnReceive(ResourceType type, float amount, float duration = 0, DamageInfo info = null); 
    }
}