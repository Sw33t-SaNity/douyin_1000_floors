using System.Collections.Generic;
using System.Runtime.Serialization;

namespace DouyinGame.Data
{
    // --- CUSTOM BACKEND MODELS (Your Private Server) ---

    [DataContract]
    public class StartGameResponse
    {
        [DataMember(Name = "roundId")] public string roundId;
    }

    [DataContract]
    public class OverMessage
    {
        [DataMember(Name = "roomId")] public string roomId = "";
        [DataMember(Name = "roundId")] public string roundId = "";
        [DataMember(Name = "anchorOpenId")] public string anchorOpenId = "";
        [DataMember(Name = "userList")] public List<OverPlayerData> userList;
        [DataMember(Name = "anchorMoney")] public int anchorMoney;
    }

    [DataContract]
    public class OverPlayerData
    {
        [DataMember(Name = "secOpenid")] public string secOpenid = "";
        [DataMember(Name = "addMoney")] public int addMoney;
        [DataMember(Name = "carList")] public List<int> carList;
        [DataMember(Name = "nowCarId")] public int nowCarId;
    }
}