using UnityEngine;
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

        void OnEnable()
        {
            TrySubscribe();
        }

        void OnDisable()
        {
            Unsubscribe();
        }

        void OnDestroy()
        {
            Unsubscribe();
        }

        private void TrySubscribe()
        {
            if (DouyinNetworkManager.Instance != null && !_isSubscribed)
            {
                DouyinNetworkManager.Instance.OnGiftReceived += HandleRawGift;
                DouyinNetworkManager.Instance.OnLikeReceived += HandleRawLike;
                DouyinNetworkManager.Instance.OnCommentReceived += HandleRawComment;
                _isSubscribed = true;
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
            if (config == null) return;

            _giftLookup = new Dictionary<string, GiftAction>();
            foreach (var mapping in config.giftActions)
            {
                if (!string.IsNullOrEmpty(mapping.giftId) && mapping.action != null && !_giftLookup.ContainsKey(mapping.giftId))
                    _giftLookup[mapping.giftId] = mapping.action;
            }
        }

        // --- SDK Translation Layer ---

        private void HandleRawGift(IGiftMessage raw)
        {
            if (config == null || raw == null || _giftLookup == null) return;

            if (_giftLookup.TryGetValue(raw.SecGiftId, out var action) && action != null)
            {
                action.Execute(raw);
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