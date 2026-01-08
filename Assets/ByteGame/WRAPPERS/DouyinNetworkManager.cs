#nullable enable
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using DouyinGame.Data;
using ByteDance.LiveOpenSdk;
using ByteDance.LiveOpenSdk.Push;
using ByteDance.LiveOpenSdk.Room;
using ByteDance.LiveOpenSdk.DyCloud;
using ByteDance.LiveOpenSdk.Utilities;
using ByteDance.LiveOpenSdk.Runtime; 
using ByteDance.LiveOpenSdk.Report;

using ByteDance.LiveOpenSdk.Round; // Added for Round Reporting

namespace DouyinGame.Core
{
    public class DouyinNetworkManager : MonoBehaviour
    {
        public static DouyinNetworkManager Instance { get; private set; }

        [Header("Configuration")]
        public string AppId = ""; 
        public string EnvId = ""; 
        public string ServiceId = "";
        public bool IsDebug = false;

        // --- EVENTS (Using SDK Interfaces) ---
        public event Action<string>? OnRawLog;
        public event Action<ILikeMessage>? OnLikeReceived;
        public event Action<ICommentMessage>? OnCommentReceived;
        public event Action<IGiftMessage>? OnGiftReceived;
        public event Action<IFansClubMessage>? OnFansclubJoined;
        
        // --- SDK SERVICES ---
        private static ILiveOpenSdk Sdk => LiveOpenSdk.Instance;
        private IDyCloudApi _dyCloudApi;
        private IMessagePushService _pushService;
        private IMessageAckService _ackService;
        private IRoundApi _roundApi; // REQUIRED for Douyin Traffic
        private IRoomInfoService _roomInfoService;
        
        private bool _isInitialized = false;

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            
            if (GetComponent<MainThreadDispatcher>() == null) gameObject.AddComponent<MainThreadDispatcher>();
            
            // Initialize asynchronously, but handle errors properly
            _ = InitAsync().ContinueWith(task =>
            {
                if (task.IsFaulted)
                {
                    Debug.LogError($"[DouyinNetworkManager] Initialization failed: {task.Exception?.GetBaseException()}");
                }
            }, TaskContinuationOptions.OnlyOnFaulted);
        }

        private void OnDestroy()
        {
            if (_pushService != null)
            {
                _pushService.OnConnectionStateChanged -= OnConnectionStateChanged;
                _pushService.OnMessage -= HandleSdkMessage;
            }
            Sdk.Uninitialize();
        }

        public async Task InitAsync()
        {
            if (_isInitialized) return;
            try
            {
                // 1. Core SDK
                Sdk.Initialize(this.AppId);

                // 2. Cloud API (For your custom backend)
                _dyCloudApi = Sdk.GetDyCloudApi();
                await _dyCloudApi.InitializeAsync(new DyCloudInitParams {
                    EnvId = this.EnvId, 
                    DefaultServiceId = this.ServiceId, 
                    IsDebug = this.IsDebug 
                });

                // 3. Services
                _roomInfoService = Sdk.GetRoomInfoService();
                _pushService = Sdk.GetMessagePushService();
                _ackService = Sdk.GetMessageAckService();
                _roundApi = Sdk.GetRoundApi(); // Get Round API

                // 4. Wait for room info (REQUIRED before starting push tasks)
                await _roomInfoService.WaitForRoomInfoAsync();

                // 5. Events
                _pushService.OnConnectionStateChanged += OnConnectionStateChanged;
                _pushService.OnMessage += HandleSdkMessage;

                // 6. Start Pushing
                await _pushService.StartPushTaskAsync(PushMessageTypes.LiveComment);
                await _pushService.StartPushTaskAsync(PushMessageTypes.LiveGift);
                await _pushService.StartPushTaskAsync(PushMessageTypes.LiveLike);
                await _pushService.StartPushTaskAsync(PushMessageTypes.LiveFansClub);

                Log("SDK Initialized & Listening");
                _isInitialized = true;
            }
            catch (Exception e)
            {
                Debug.LogError($"[DouyinNetworkManager] Init Failed: {e}");
            }
        }

        private void OnConnectionStateChanged(ConnectionState state)
        {
            Log($"Connection State Changed: {state}");
        }

        private void HandleSdkMessage(IPushMessage message)
        {
            MainThreadDispatcher.Enqueue(() =>
            {
                try
                {
                    switch (message)
                    {
                        case ILikeMessage m: OnLikeReceived?.Invoke(m); break;
                        case ICommentMessage m: OnCommentReceived?.Invoke(m); break;
                        case IGiftMessage m: OnGiftReceived?.Invoke(m); break;
                        case IFansClubMessage m: OnFansclubJoined?.Invoke(m); break;
                    }
                    _ackService.ReportAck(message);
                }
                catch (Exception e) { Debug.LogError($"[SDK] Handle Error: {e}"); }
            });
        }

        // --- GAME FLOW (Updated with Round API) ---

        public async Task StartGameAsync(Action<string?> onGameStarted)
        {
            if (!_isInitialized || _roundApi == null || _dyCloudApi == null)
            {
                Debug.LogError("[DouyinNetworkManager] Services not initialized. Call InitAsync() first.");
                onGameStarted?.Invoke(null);
                return;
            }

            // 1. Tell Douyin Platform "Round Started" (Required for traffic)
            long roundId = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            try {
                await _roundApi.UpdateRoundStatusInfoAsync(new RoundStatusInfo {
                    RoundId = roundId,
                    StartTime = roundId,
                    Status = 1 // 1 = Started
                });
            } catch (Exception e) { 
                Debug.LogError($"[RoundApi] Start Failed: {e}"); 
            }

            // 2. Call YOUR Backend
            const string path = "/start_game"; 
            var response = await CallApi(path, "POST", $"{{\"round_id\": {roundId}}}");
            
            // 3. Callback
            if (response != null) 
            {
                onGameStarted?.Invoke(roundId.ToString());
            }
            else
            {
                Debug.LogWarning("[DouyinNetworkManager] StartGame API call returned null response");
                onGameStarted?.Invoke(null);
            }
        }

        public async Task GetNoticeAsync(Action<string?> onNoticeReceived)
        {
            if (!_isInitialized || _dyCloudApi == null)
            {
                Debug.LogError("[DouyinNetworkManager] DyCloudApi not initialized. Call InitAsync() first.");
                onNoticeReceived?.Invoke(null);
                return;
            }

            const string path = "/get_notice";
            var response = await CallApi(path, "GET", "");
            if (response != null) 
            {
                onNoticeReceived?.Invoke(response);
            }
            else
            {
                Debug.LogWarning("[DouyinNetworkManager] GetNotice API call returned null response");
                onNoticeReceived?.Invoke(null);
            }
        }

        public async Task GameOverAsync(OverMessage overData)
        {
            if (!_isInitialized || _roundApi == null || _dyCloudApi == null)
            {
                Debug.LogError("[DouyinNetworkManager] Services not initialized. Call InitAsync() first.");
                return;
            }

            if (overData == null)
            {
                Debug.LogError("[DouyinNetworkManager] GameOver called with null overData");
                return;
            }

            // 1. Tell Douyin Platform "Round Ended"
            try {
                if (long.TryParse(overData.roundId, out long rid))
                {
                    await _roundApi.UpdateRoundStatusInfoAsync(new RoundStatusInfo {
                        RoundId = rid,
                        EndTime = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                        Status = 2 // 2 = Ended
                    });
                }
                else
                {
                    Debug.LogWarning($"[DouyinNetworkManager] Invalid roundId format: {overData.roundId}");
                }
            } catch (Exception e) { 
                Debug.LogError($"[RoundApi] End Failed: {e}"); 
            }

            // 2. Call YOUR Backend
            const string path = "/finish_game";
            await CallApi(path, "POST", JsonHelper.ToJson(overData));
        }

        private async Task<string?> CallApi(string path, string method, string body)
        {
            if (_dyCloudApi == null) return null;
            try {
                var res = await _dyCloudApi.CallContainerAsync(path, ServiceId, method, body, new Dictionary<string, string>());
                return res.StatusCode == 200 ? res.Body : null;
            }
            catch (Exception e) { Debug.LogError($"API Fail: {e}"); return null; }
        }

        private void Log(string msg) => MainThreadDispatcher.Enqueue(() => OnRawLog?.Invoke(msg));

        // --- SIMULATION (Mocks) ---
        // These classes are needed because you cannot instantiate Interfaces directly.

        public void SimulateGift(string giftId, int count) => 
            OnGiftReceived?.Invoke(new MockGiftMessage(giftId, count));

        public void SimulateComment(string content) => 
            OnCommentReceived?.Invoke(new MockCommentMessage(content));

        public void SimulateLike(int count) => 
            OnLikeReceived?.Invoke(new MockLikeMessage(count));

        public void SimulateFansclub(int level) => 
            OnFansclubJoined?.Invoke(new MockFansClubMessage(level));

        // --- MOCK CLASSES ---
        // Simple implementations of SDK interfaces for testing.
        
        private class MockUser : IUserInfo {
            public string OpenId => "mock_openid";
            public string Nickname => "SimUser";
            public string AvatarUrl => "";
            public int Gender => 1;
            public int PayGradeLevel => 1;
            public int FansClubLevel => 1;
        }

        private class MockGiftMessage : IGiftMessage {
            public string MsgId => "mock_msg_id";
            public string MsgType => PushMessageTypes.LiveGift;
            public long Timestamp => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            public IUserInfo Sender => new MockUser();
            public long GiftId => 0; 
            public string SecGiftId { get; set; }
            public long GiftCount { get; set; }
            public long GiftValue => 10;
            public bool Combo => false;
            public string SecMagicGiftId => "";
            public bool IsTestData => true;
            public string AudienceSecOpenId => "";

            public MockGiftMessage(string id, long count) { SecGiftId = id; GiftCount = count; }
        }

        private class MockCommentMessage : ICommentMessage {
            public string MsgId => "mock_msg_id";
            public string MsgType => PushMessageTypes.LiveComment;
            public long Timestamp => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            public IUserInfo Sender => new MockUser();
            public string Content { get; set; }
            public MockCommentMessage(string c) { Content = c; }
        }

        private class MockLikeMessage : ILikeMessage {
            public string MsgId => "mock_msg_id";
            public string MsgType => PushMessageTypes.LiveLike;
            public long Timestamp => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            public IUserInfo Sender => new MockUser();
            public long LikeCount { get; set; }
            public MockLikeMessage(long c) { LikeCount = c; }
        }

        private class MockFansClubMessage : IFansClubMessage {
            public string MsgId => "mock_msg_id";
            public string MsgType => PushMessageTypes.LiveFansClub;
            public long Timestamp => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            public IUserInfo Sender => new MockUser();
            public IFansClubMessage.MessageType FansClubMessageType { get; set; }
            public long FansClubLevel { get; set; }
            public MockFansClubMessage(int level) { 
                FansClubLevel = level; 
                FansClubMessageType = IFansClubMessage.MessageType.Join; 
            }
        }
        
        // Helper record for Round API
        private record RoundStatusInfo : IRoundStatusInfo {
            public long RoundId { get; set; }
            public long StartTime { get; set; }
            public long EndTime { get; set; }
            public int Status { get; set; }
            public List<IGroupResultInfo>? GroupResultList { get; set; }
        }
    }
}