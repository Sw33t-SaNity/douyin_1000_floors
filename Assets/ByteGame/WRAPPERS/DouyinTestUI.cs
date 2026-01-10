using UnityEngine;
using DouyinGame.Core;
using Douyin.YF.Live;
using System.Collections.Generic;

namespace DouyinGame.Testing
{
    /// <summary>
    /// A simple IMGUI-based test panel to verify Douyin SDK integration and interaction logic.
    /// Attach this to any GameObject in your scene.
    /// </summary>
    public class DouyinTestUI : MonoBehaviour
    {
        private string _giftId = "gift_id_here";
        private string _commentText = "666";
        private string _likeCountStr = "1";
        private string _fansLevel = "1";
        private bool _isVisible = true;

        private bool _showGiftDropdown = false;
        private Vector2 _giftScrollPos;
        
        private Vector2 _scrollPos;
        private List<string> _logs = new List<string>();

        private void OnEnable()
        {
            Application.logMessageReceived += HandleLog;
            
            // Subscribe to DouyinNetworkManager events for better feedback
            if (DouyinNetworkManager.Instance != null)
            {
                DouyinNetworkManager.Instance.OnGiftReceived += OnGiftReceived;
                DouyinNetworkManager.Instance.OnCommentReceived += OnCommentReceived;
                DouyinNetworkManager.Instance.OnLikeReceived += OnLikeReceived;
                DouyinNetworkManager.Instance.OnFansclubJoined += OnFansclubJoined;
            }
        }

        private void OnDisable()
        {
            Application.logMessageReceived -= HandleLog;
            
            if (DouyinNetworkManager.Instance != null)
            {
                DouyinNetworkManager.Instance.OnGiftReceived -= OnGiftReceived;
                DouyinNetworkManager.Instance.OnCommentReceived -= OnCommentReceived;
                DouyinNetworkManager.Instance.OnLikeReceived -= OnLikeReceived;
                DouyinNetworkManager.Instance.OnFansclubJoined -= OnFansclubJoined;
            }
        }

        private void OnGiftReceived(ByteDance.LiveOpenSdk.Push.IGiftMessage gift)
        {
            AddLog($"🎁 Gift received: {gift.SecGiftId} (Value: {gift.GiftValue}, Count: {gift.GiftCount})");
        }

        private void OnCommentReceived(ByteDance.LiveOpenSdk.Push.ICommentMessage comment)
        {
            AddLog($"💬 Comment: {comment.Content} from {comment.Sender.Nickname}");
        }

        private void OnLikeReceived(ByteDance.LiveOpenSdk.Push.ILikeMessage like)
        {
            AddLog($"❤️ Like: {like.LikeCount} from {like.Sender.Nickname}");
        }

        private void OnFansclubJoined(ByteDance.LiveOpenSdk.Push.IFansClubMessage fans)
        {
            AddLog($"⭐ Fansclub: Level {fans.FansClubLevel} from {fans.Sender.Nickname}");
        }

        private void HandleLog(string logString, string stackTrace, LogType type)
        {
            _logs.Add($"[{type}] {logString}");
            if (_logs.Count > 50) _logs.RemoveAt(0);
            _scrollPos.y = float.MaxValue; // Auto-scroll to bottom
        }

        private void AddLog(string message)
        {
            _logs.Add($"[TestUI] {message}");
            if (_logs.Count > 50) _logs.RemoveAt(0);
            _scrollPos.y = float.MaxValue; // Auto-scroll to bottom
            Debug.Log($"[DouyinTestUI] {message}");
        }

        private void OnGUI()
        {
            // Basic scaling for readability on different resolutions
            float scale = Screen.height / 1080f * 1.5f;
            GUI.matrix = Matrix4x4.Scale(new Vector3(scale, scale, 1));

            if (GUI.Button(new Rect(10, 10, 100, 30), _isVisible ? "Hide UI" : "Show UI"))
            {
                _isVisible = !_isVisible;
            }

            if (!_isVisible) return;

            GUILayout.BeginArea(new Rect(10, 50, 350, 700), "Douyin API Tester", GUI.skin.window);
            
            // Offline Test Mode Toggle
            if (DouyinNetworkManager.Instance != null)
            {
                bool oldOfflineMode = DouyinNetworkManager.Instance.OfflineTestMode;
                bool newOfflineMode = GUILayout.Toggle(oldOfflineMode, "🔌 Offline Test Mode (No Backend Required)");
                if (newOfflineMode != oldOfflineMode)
                {
                    DouyinNetworkManager.Instance.OfflineTestMode = newOfflineMode;
                    if (newOfflineMode)
                    {
                        AddLog("✓ Offline Test Mode ENABLED - Simulation methods will work without EnvId/ServiceId");
                    }
                    else
                    {
                        AddLog("→ Offline Test Mode DISABLED - Full SDK initialization required");
                    }
                }
                
                if (DouyinNetworkManager.Instance.OfflineTestMode)
                {
                    GUI.color = Color.yellow;
                    GUILayout.Label("⚠️ OFFLINE MODE: Backend APIs disabled, simulation enabled", GUI.skin.box);
                    GUI.color = Color.white;
                }
                GUILayout.Space(5);
            }
            
            if (GUILayout.Button("1. Initialize SDK & Cloud"))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    Debug.Log("[TestUI] Initializing SDK...");
                    AddLog("→ Initializing SDK & Cloud...");
                    
                    if (DouyinNetworkManager.Instance.OfflineTestMode)
                    {
                        AddLog("→ Offline mode: Skipping backend initialization...");
                    }
                    
                    _ = DouyinNetworkManager.Instance.InitAsync().ContinueWith(task =>
                    {
                        if (task.IsFaulted)
                        {
                            Debug.LogError($"[TestUI] SDK Init Failed: {task.Exception?.GetBaseException()}");
                            AddLog($"✗ SDK Init Failed: {task.Exception?.GetBaseException()?.Message}");
                        }
                        else
                        {
                            Debug.Log("[TestUI] SDK Initialized (or offline mode enabled)");
                            AddLog("✓ SDK Ready! (Offline mode: simulation works without backend)");
                        }
                    });
                }
                else
                {
                    Debug.LogError("[TestUI] DouyinNetworkManager Instance not found!");
                    AddLog("✗ DouyinNetworkManager Instance not found!");
                }
            }

            GUILayout.Space(10);
            GUILayout.Label("<b>Simulation (Works in Offline Mode!)</b>", GUI.skin.box);
            GUILayout.Label("<size=10>These buttons test your DouyinLiveInteractionManager without requiring EnvId/ServiceId</size>", GUI.skin.label);
            GUILayout.Space(5);
            
            GUILayout.BeginHorizontal();
            GUILayout.Label("Gift:", GUILayout.Width(70));

            var interactionManager = DouyinLiveInteractionManager.Instance;
            if (interactionManager != null && interactionManager.Config != null)
            {
                var giftMappings = interactionManager.Config.giftActions;
                string currentDisplayName = "Select a Gift...";
                
                // Find the display name for the currently selected ID
                var mapping = giftMappings.Find(m => m.giftId == _giftId);
                if (!string.IsNullOrEmpty(mapping.giftId)) 
                    currentDisplayName = string.IsNullOrEmpty(mapping.giftName) ? mapping.giftId : mapping.giftName;

                if (GUILayout.Button(currentDisplayName, GUILayout.Width(180)))
                {
                    _showGiftDropdown = !_showGiftDropdown;
                }
            }
            else
            {
                _giftId = GUILayout.TextField(_giftId, GUILayout.Width(180));
            }

            if (GUILayout.Button("Gift", GUILayout.Width(80)))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    Debug.Log($"[TestUI] Simulating gift: {_giftId}");
                    DouyinNetworkManager.Instance.SimulateGift(_giftId, 1);
                    AddLog($"✓ Sent gift: {_giftId}");
                    
                    // Check if DouyinLiveInteractionManager is subscribed
                    if (DouyinLiveInteractionManager.Instance != null)
                    {
                        AddLog("→ Checking if DouyinLiveInteractionManager received the gift...");
                    }
                    else
                    {
                        AddLog("⚠️ DouyinLiveInteractionManager.Instance is null - gift action may not execute!");
                    }
                }
                else
                {
                    AddLog("✗ DouyinNetworkManager.Instance is null!");
                }
            }
            GUILayout.EndHorizontal();

            if (_showGiftDropdown && interactionManager != null && interactionManager.Config != null)
            {
                _giftScrollPos = GUILayout.BeginScrollView(_giftScrollPos, GUI.skin.box, GUILayout.Height(150));
                foreach (var mapping in interactionManager.Config.giftActions)
                {
                    if (GUILayout.Button($"{mapping.giftName} [{mapping.giftId}]"))
                    {
                        _giftId = mapping.giftId;
                        _showGiftDropdown = false;
                    }
                }
                GUILayout.EndScrollView();
            }

            GUILayout.BeginHorizontal();
            GUILayout.Label("Danmu:", GUILayout.Width(70));
            _commentText = GUILayout.TextField(_commentText);
            if (GUILayout.Button("Comment", GUILayout.Width(80)))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    Debug.Log($"[TestUI] Simulating comment: {_commentText}");
                    DouyinNetworkManager.Instance.SimulateComment(_commentText);
                    AddLog($"✓ Sent comment: {_commentText}");
                }
                else
                {
                    AddLog("✗ DouyinNetworkManager.Instance is null!");
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.BeginHorizontal();
            GUILayout.Label("Likes:", GUILayout.Width(70));
            _likeCountStr = GUILayout.TextField(_likeCountStr);
            if (GUILayout.Button("Like", GUILayout.Width(80)))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    if (int.TryParse(_likeCountStr, out int lCount))
                    {
                        Debug.Log($"[TestUI] Simulating like: {lCount}");
                        DouyinNetworkManager.Instance.SimulateLike(lCount);
                        AddLog($"✓ Sent like: {lCount}");
                    }
                    else
                    {
                        AddLog("✗ Invalid like count!");
                    }
                }
                else
                {
                    AddLog("✗ DouyinNetworkManager.Instance is null!");
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.BeginHorizontal();
            GUILayout.Label("Fans Lvl:", GUILayout.Width(70));
            _fansLevel = GUILayout.TextField(_fansLevel);
            if (GUILayout.Button("Fans", GUILayout.Width(80)))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    if (int.TryParse(_fansLevel, out int fLevel))
                    {
                        Debug.Log($"[TestUI] Simulating fansclub: level {fLevel}");
                        DouyinNetworkManager.Instance.SimulateFansclub(fLevel);
                        AddLog($"✓ Sent fansclub: level {fLevel}");
                    }
                    else
                    {
                        AddLog("✗ Invalid fans level!");
                    }
                }
                else
                {
                    AddLog("✗ DouyinNetworkManager.Instance is null!");
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10);
            GUILayout.Label("<b>Backend API Calls</b>");
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Start Game"))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    Debug.Log("[TestUI] Starting game...");
                    AddLog("→ Starting game...");
                    _ = DouyinNetworkManager.Instance.StartGameAsync((id) => 
                    {
                        Debug.Log($"[TestUI] Round ID: {id ?? "null"}");
                        AddLog($"✓ Game started! Round ID: {id ?? "null"}");
                    });
                }
                else
                {
                    AddLog("✗ DouyinNetworkManager.Instance is null!");
                }
            }
            if (GUILayout.Button("Get Notice"))
            {
                if (DouyinNetworkManager.Instance != null)
                {
                    Debug.Log("[TestUI] Getting notice...");
                    AddLog("→ Getting notice...");
                    _ = DouyinNetworkManager.Instance.GetNoticeAsync((c) => 
                    {
                        Debug.Log($"[TestUI] Notice: {c ?? "null"}");
                        AddLog($"✓ Notice received: {c ?? "null"}");
                    });
                }
                else
                {
                    AddLog("✗ DouyinNetworkManager.Instance is null!");
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10);
            GUILayout.Label("<b>Logs</b>");
            _scrollPos = GUILayout.BeginScrollView(_scrollPos, GUI.skin.box, GUILayout.Height(200));
            foreach (var log in _logs)
            {
                GUILayout.Label(log);
            }
            GUILayout.EndScrollView();

            if (GUILayout.Button("Clear Logs")) _logs.Clear();

            GUILayout.EndArea();
        }
    }
}
