using System.Collections.Generic;
using System.Runtime.Serialization;

namespace DouyinGame.Data
{
    // --- Existing Message Types ---
    [DataContract]
    public class PlayerMessage
    {
        [DataMember(Name = "msg_id")] public string msg_id = "";
        [DataMember(Name = "sec_openid")] public string sec_openid = "";
        [DataMember(Name = "content")] public string content = "";
        [DataMember(Name = "avatar_url")] public string avatar_url = "";
        [DataMember(Name = "nickname")] public string nickname = "";
        [DataMember(Name = "timestamp")] public string timestamp = "";
    }

    [DataContract]
    public class GiftMessage
    {
        [DataMember(Name = "msg_id")] public string msg_id = "";
        [DataMember(Name = "sec_openid")] public string sec_openid = "";
        [DataMember(Name = "sec_gift_id")] public string sec_gift_id = "";
        [DataMember(Name = "gift_num")] public string gift_num = "";
        [DataMember(Name = "gift_value")] public string gift_value = "";
        [DataMember(Name = "avatar_url")] public string avatar_url = "";
        [DataMember(Name = "nickname")] public string nickname = "";
        [DataMember(Name = "timestamp")] public string timestamp = "";
        [DataMember(Name = "sec_magic_gift_id")] public string sec_magic_gift_id = "";
    }

    [DataContract]
    public class FansclubMessage
    {
        [DataMember(Name = "msg_id")] public string msg_id = "";
        [DataMember(Name = "sec_openid")] public string sec_openid = "";
        [DataMember(Name = "nickname")] public string nickname = "";
        [DataMember(Name = "timestamp")] public string timestamp = "";
        [DataMember(Name = "fansclub_level")] public string fansclub_level = "";
    }

    [DataContract]
    public class LikeMessage
    {
        [DataMember(Name = "msg_id")] public string msg_id = "";
        [DataMember(Name = "sec_openid")] public string sec_openid = "";
        [DataMember(Name = "like_num")] public string like_num = "";
        [DataMember(Name = "avatar_url")] public string avatar_url = "";
        [DataMember(Name = "nickname")] public string nickname = "";
        [DataMember(Name = "timestamp")] public string timestamp = "";
    }

    // --- Extracted Game Specific Responses ---

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

    [DataContract]
    public class NoticeResponseWrapper
    {
        [DataMember(Name = "data")] public NoticeContent data;
    }

    [DataContract]
    public class NoticeContent
    {
        [DataMember(Name = "content")] public string content;
    }
}