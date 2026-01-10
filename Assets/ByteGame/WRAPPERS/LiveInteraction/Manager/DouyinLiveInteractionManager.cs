using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System;
using DouyinGame.Core;
using ByteDance.LiveOpenSdk.Push;

namespace Douyin.YF.Live
{
    public class DouyinLiveInteractionManager : MonoBehaviour
    {
        public static DouyinLiveInteractionManager Instance { get; private set; }

        [Header("Configuration")]
        [SerializeField] private LiveInteractionConfig config;

        public LiveInteractionConfig Config => config;

        private Dictionary<string, GiftAction> _giftLookup;
        private int _totalLikes = 0;
        private HashSet<int> _triggeredMilestones = new HashSet<int>();

        private bool _isSubscribed = false;
        private Coroutine _subscriptionRetryCoroutine;

        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            InitializeLookup();
        }

        void Start()
        {
            // Try to subscribe immediately - Start() runs after all Awake() calls
            TrySubscribe();
            
            // If still not subscribed, start retry coroutine
            if (!_isSubscribed && _subscriptionRetryCoroutine == null)
            {
                _subscriptionRetryCoroutine = StartCoroutine(RetrySubscriptionCoroutine());
            }
        }

        void OnEnable()
        {
            // Try to subscribe when enabled (in case it was disabled/re-enabled)
            if (!_isSubscribed)
            {
                TrySubscribe();
                
                // If still not subscribed and coroutine isn't running, start it
                if (!_isSubscribed && _subscriptionRetryCoroutine == null)
                {
                    _subscriptionRetryCoroutine = StartCoroutine(RetrySubscriptionCoroutine());
                }
            }
        }

        void OnDisable()
        {
            Unsubscribe();
            if (_subscriptionRetryCoroutine != null)
            {
                StopCoroutine(_subscriptionRetryCoroutine);
                _subscriptionRetryCoroutine = null;
            }
        }

        void OnDestroy()
        {
            Unsubscribe();
            if (_subscriptionRetryCoroutine != null)
            {
                StopCoroutine(_subscriptionRetryCoroutine);
                _subscriptionRetryCoroutine = null;
            }
        }

        private IEnumerator RetrySubscriptionCoroutine()
        {
            const float retryInterval = 0.5f; // Check every 0.5 seconds
            const float maxWaitTime = 10f; // Give up after 10 seconds
            float elapsed = 0f;

            while (!_isSubscribed && elapsed < maxWaitTime)
            {
                yield return new WaitForSeconds(retryInterval);
                elapsed += retryInterval;
                
                TrySubscribe();
                
                if (_isSubscribed)
                {
                    Debug.Log("[DouyinLiveInteractionManager] Successfully subscribed to events after retry");
                    _subscriptionRetryCoroutine = null;
                    yield break;
                }
            }

            if (!_isSubscribed)
            {
                Debug.LogWarning($"[DouyinLiveInteractionManager] Failed to subscribe after {maxWaitTime} seconds. DouyinNetworkManager may not be available.");
            }
            
            _subscriptionRetryCoroutine = null;
        }

        private void TrySubscribe()
        {
            if (DouyinNetworkManager.Instance != null && !_isSubscribed)
            {
                Debug.Log("[DouyinLiveInteractionManager] Subscribing to events");
                DouyinNetworkManager.Instance.OnGiftReceived += HandleRawGift;
                DouyinNetworkManager.Instance.OnLikeReceived += HandleRawLike;
                DouyinNetworkManager.Instance.OnCommentReceived += HandleRawComment;
                _isSubscribed = true;
                
                // Stop retry coroutine if it's running
                if (_subscriptionRetryCoroutine != null)
                {
                    StopCoroutine(_subscriptionRetryCoroutine);
                    _subscriptionRetryCoroutine = null;
                }
            }
        }

        private void Unsubscribe()
        {
            if (DouyinNetworkManager.Instance != null && _isSubscribed)
            {
                DouyinNetworkManager.Instance.OnGiftReceived -= HandleRawGift;
                DouyinNetworkManager.Instance.OnLikeReceived -= HandleRawLike;
                DouyinNetworkManager.Instance.OnCommentReceived -= HandleRawComment;
                _isSubscribed = false;
            }
        }

        private void InitializeLookup()
        {
            if (config == null)
            {
                Debug.LogWarning("[DouyinLiveInteractionManager] Config is null. Cannot initialize gift lookup.");
                return;
            }

            _giftLookup = new Dictionary<string, GiftAction>();
            if (config.giftActions == null)
            {
                Debug.LogWarning("[DouyinLiveInteractionManager] Config.giftActions is null.");
                return;
            }

            foreach (var mapping in config.giftActions)
            {
                if (!string.IsNullOrEmpty(mapping.giftId) && mapping.action != null)
                {
                    if (_giftLookup.ContainsKey(mapping.giftId))
                    {
                        Debug.LogWarning($"[DouyinLiveInteractionManager] Duplicate giftId '{mapping.giftId}' found in config. Using first mapping.");
                    }
                    else
                    {
                        _giftLookup[mapping.giftId] = mapping.action;
                    }
                }
            }

            Debug.Log($"[DouyinLiveInteractionManager] Initialized {_giftLookup.Count} gift mappings.");
        }

        // --- SDK Translation Layer ---

        private void HandleRawGift(IGiftMessage raw)
        {
            if (config == null || raw == null || _giftLookup == null) {
                if (config==null) Debug.Log("[DouyinLiveInteractionManager] config is null");
                if (raw==null) Debug.Log("[DouyinLiveInteractionManager] raw is null");
                if (_giftLookup==null) Debug.Log("[DouyinLiveInteractionManager] _giftLookup is null");
            }
            if (string.IsNullOrEmpty(raw.SecGiftId))
            {
                Debug.LogWarning($"[DouyinLiveInteractionManager] Received gift with null/empty SecGiftId. GiftValue: {raw.GiftValue}, Count: {raw.GiftCount}");
                return;
            }

            if (_giftLookup.TryGetValue(raw.SecGiftId, out var action) && action != null)
            {
                action.Execute(raw);
                Debug.Log($"[DouyinLiveInteractionManager] Executed gift action for giftId '{raw.SecGiftId}'. GiftValue: {raw.GiftValue}, Count: {raw.GiftCount}");
            }
            else
            {
                Debug.Log($"[DouyinLiveInteractionManager] No mapping found for giftId '{raw.SecGiftId}'. GiftValue: {raw.GiftValue}, Count: {raw.GiftCount}");
            }
        }

        private void HandleRawLike(ILikeMessage raw)
        {
            if (config == null || config.likeMilestones == null || raw == null) return;

            _totalLikes += (int)raw.LikeCount;
            
            // Check milestones (1, 100, 1000, etc.)
            foreach (var milestone in config.likeMilestones)
            {
                if (milestone.action != null &&
                    _totalLikes >= milestone.threshold && 
                    !_triggeredMilestones.Contains(milestone.threshold))
                {
                    milestone.action.Execute(raw);
                    _triggeredMilestones.Add(milestone.threshold);
                }
            }
        }

        private void HandleRawComment(ICommentMessage raw)
        {
            if (config == null || config.commentActions == null || raw == null) return;

            foreach (var mapping in config.commentActions)
            {
                if (!string.IsNullOrEmpty(mapping.keyword) && 
                    raw.Content != null && 
                    raw.Content.Contains(mapping.keyword) &&
                    mapping.action != null)
                {
                    mapping.action.Execute(raw);
                }
            }
        }
    }
}