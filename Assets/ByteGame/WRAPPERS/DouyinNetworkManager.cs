using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using DouyinGame.Data;
using ByteDance.LiveOpenSdk;
using ByteDance.LiveOpenSdk.Runtime;
using ByteDance.LiveOpenSdk.DyCloud;
using ByteDance.LiveOpenSdk.Utilities;

namespace DouyinGame.Core
{
    public class DouyinNetworkManager : MonoBehaviour
    {
        public static DouyinNetworkManager Instance { get; private set; }

        [Header("Configuration")]
        public string EnvId = "env-oROsSOYskv"; 
        public string ServiceId = "1lcaszhps2jnz";
        public bool IsDebug = false;

        // Extracted Gift IDs
        public List<string> GiftIdList = new List<string>()
        {
            "n1/Dg1905sj1FyoBlQBvmbaDZFBNaKuKZH6zxHkv8Lg5x2cRfrKUTb8gzMs=", // Fairy Stick
            "28rYzVFNyXEXFC8HI+f/WG+I7a6lfl3OyZZjUS+CVuwCgYZrPrUdytGHu0c=", // Pill
            "fJs8HKQ0xlPRixn8JAUiL2gFRiLD9S6IFCFdvZODSnhyo9YN8q7xUuVVyZI=", // Mirror
            "PJ0FFeaDzXUreuUBZH6Hs+b56Jh0tQjrq0bIrrlZmv13GSAL9Q1hf59fjGk=", // Donut
            "IkkadLfz7O/a5UR45p/OOCCG6ewAWVbsuzR/Z+v1v76CBU+mTG/wPjqdpfg=", // Battery
            "gx7pmjQfhBaDOG2XkWI2peZ66YFWkCWRjZXpTqb23O/epru+sxWyTV/3Ufs=", // Love Bomb
            "pGLo7HKNk1i4djkicmJXf6iWEyd+pfPBjbsHmd3WcX0Ierm2UdnRR7UINvI=", // Airdrop
        };

        // --- EVENTS ---
        public event Action<string> OnRawLog;
        public event Action<LikeMessage> OnLikeReceived;
        public event Action<PlayerMessage> OnCommentReceived;
        public event Action<GiftMessage> OnGiftReceived;
        public event Action<FansclubMessage> OnFansclubJoined;
        
        // --- INTERNAL SDK REFERENCES ---
        private static ILiveOpenSdk Sdk => LiveOpenSdk.Instance;
        private IDyCloudApi _dyCloudApi;
        private IDyCloudWebSocket _webSocket;
        private bool _isInitialized = false;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            _ = InitAsync();
        }

        private void OnDestroy()
        {
            if (_webSocket != null) _webSocket.Close();
        }

        // --- INITIALIZATION ---

        public async Task InitAsync()
        {
            if (_isInitialized) return;

            var initParams = new DyCloudInitParams
            {
                EnvId = this.EnvId,
                DefaultServiceId = this.ServiceId,
                DebugIpAddress = "",
                IsDebug = this.IsDebug
            };

            _dyCloudApi = Sdk.GetDyCloudApi();

            try
            {
                await _dyCloudApi.InitializeAsync(initParams);
                Dispatch(() => OnRawLog?.Invoke("Cloud Initialized Successfully"));
                _isInitialized = true;
                await ConnectWebSocket();
            }
            catch (Exception e)
            {
                Debug.LogError($"Cloud Init Failed: {e.Message}");
                Dispatch(() => OnRawLog?.Invoke("Cloud Init Failed"));
            }
        }

        // --- WEBSOCKET HANDLING ---

        private async Task ConnectWebSocket()
        {
            string wsPath = "/websocket_callback";

            _webSocket = _dyCloudApi.WebSocket;
            _webSocket.OnOpen += () => Dispatch(() => OnRawLog?.Invoke("WS Open"));
            _webSocket.OnClose += () => Dispatch(() => OnRawLog?.Invoke("WS Close"));
            _webSocket.OnError += (err) => Dispatch(() => OnRawLog?.Invoke($"WS Error: {err}"));
            _webSocket.OnMessage += HandleIncomingMessage;

            try
            {
                await _webSocket.ConnectContainerAsync(wsPath);
                Dispatch(() => OnRawLog?.Invoke("WS Connected"));
            }
            catch (Exception e)
            {
                Debug.LogError($"WS Connect Failed: {e.Message}");
            }
        }

        private void HandleIncomingMessage(string json)
        {
            if (string.IsNullOrEmpty(json)) return;

            Dispatch(() =>
            {
                try 
                {
                    // Updated to use JsonHelper from DouyinUtils.cs
                    var message = JsonHelper.FromJson<DyCloudSocketMessage>(json);
                    if (message == null) return;

                    switch (message.MsgType)
                    {
                        case "live_like":
                            var likeData = JsonHelper.FromJson<LikeMessage>(message.Data);
                            OnLikeReceived?.Invoke(likeData);
                            break;
                        case "live_comment":
                            var commentData = JsonHelper.FromJson<PlayerMessage>(message.Data);
                            OnCommentReceived?.Invoke(commentData);
                            break;
                        case "live_gift":
                            var giftData = JsonHelper.FromJson<GiftMessage>(message.Data);
                            OnGiftReceived?.Invoke(giftData);
                            break;
                        case "live_fansclub":
                            var fanData = JsonHelper.FromJson<FansclubMessage>(message.Data);
                            OnFansclubJoined?.Invoke(fanData);
                            break;
                    }
                }
                catch(Exception e)
                {
                    Debug.LogError($"Parse Error: {e.Message}");
                }
            });
        }

        // --- GAME API CALLS ---

        public async void StartGame(Action<string> onGameStarted)
        {
            const string path = "/start_game"; 
            var response = await CallApi(path, "POST", "");
            if (response != null)
            {
                var data = JsonHelper.FromJson<StartGameResponse>(response);
                Dispatch(() => onGameStarted?.Invoke(data.roundId));
            }
        }

        public async void GameOver(OverMessage overData)
        {
            const string path = "/finish_game";
            string json = JsonHelper.ToJson(overData);
            await CallApi(path, "POST", json);
        }

        public async void GetPlayerInfo(string userId, Action<string> onInfoReceived)
        {
            const string path = "/GetPlayer";
            string json = "{\"secOpenid\": \"" + userId + "\"}"; // Kept manual JSON for simplicity
            
            var response = await CallApi(path, "POST", json);
            if (response != null)
            {
                Dispatch(() => onInfoReceived?.Invoke(response));
            }
        }

        public async void GetNotice(Action<string> onNoticeReceived)
        {
            const string path = "/GetAnnouncement";
            var response = await CallApi(path, "POST", "");
            if (response != null)
            {
                var wrapper = JsonHelper.FromJson<NoticeResponseWrapper>(response);
                Dispatch(() => onNoticeReceived?.Invoke(wrapper.data.content));
            }
        }

        private async Task<string> CallApi(string path, string method, string body)
        {
            if (_dyCloudApi == null) return null;

            try
            {
                var response = await _dyCloudApi.CallContainerAsync(
                    path, 
                    this.ServiceId, 
                    method, 
                    body, 
                    new Dictionary<string, string>());

                if (response.StatusCode == 200) return response.Body;
                
                Debug.LogError($"API Error {path}: {response.StatusCode} {response.Body}");
                return null;
            }
            catch (Exception e)
            {
                Debug.LogError($"API Exception {path}: {e.Message}");
                return null;
            }
        }

        private void Dispatch(Action action)
        {
            MainThreadDispatcher.Enqueue(action);
        }
    }
}