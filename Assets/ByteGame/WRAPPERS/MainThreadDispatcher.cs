using UnityEngine;
using System.Collections.Generic;
using System.Threading;
using System;

namespace DouyinGame.Core
{
    /// <summary>
    /// Critical infrastructure. Allows background network threads to run code 
    /// on the main Unity thread (required for UI and spawning objects).
    /// </summary>
    public class MainThreadDispatcher : MonoBehaviour
    {
        private static MainThreadDispatcher _instance;
        private readonly Queue<Action> _executionQueue = new Queue<Action>();
        private int _lockFlag;

        public static bool IsInitialized => _instance != null;

        public static void Enqueue(Action action)
        {
            if (action == null)
            {
                Debug.LogWarning("[MainThreadDispatcher] Attempted to enqueue null action");
                return;
            }

            if (_instance == null)
            {
                // We cannot call FindObjectOfType from a background thread.
                // The instance MUST be initialized on the main thread first.
                Debug.LogWarning("[MainThreadDispatcher] Instance not initialized. Action will be dropped.");
                return;
            }

            // Thread-safe enqueue
            while (Interlocked.Exchange(ref _instance._lockFlag, 1) != 0) { }
            _instance._executionQueue.Enqueue(action);
            Interlocked.Exchange(ref _instance._lockFlag, 0);
        }

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            _instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private void Update()
        {
            if (Interlocked.Exchange(ref _lockFlag, 1) == 0)
            {
                while (_executionQueue.Count > 0)
                {
                    try
                    {
                        _executionQueue.Dequeue()?.Invoke();
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"[MainThreadDispatcher] Execution Error: {e}");
                    }
                }
                Interlocked.Exchange(ref _lockFlag, 0);
            }
        }
    }
}