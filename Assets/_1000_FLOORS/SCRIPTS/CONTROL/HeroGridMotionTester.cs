using UnityEngine;
using UnityEngine.InputSystem;

namespace ThousandFloors
{
    /// <summary>
    /// Debug component to test GridMotionManager using the F1-F4 keys defined in IA_Hero.
    /// GridMotionManager is now a singleton manager, so this component just needs to be on any GameObject.
    /// </summary>
    public class GridMotionTester : MonoBehaviour
    {
        private IA_Hero _inputActions;

        private void Awake()
        {
            _inputActions = new IA_Hero();
        }

        private void OnEnable()
        {
            _inputActions.Gameplay.Enable();
            _inputActions.Gameplay.Test1.performed += OnTest1;
            _inputActions.Gameplay.Test2.performed += OnTest2;
            _inputActions.Gameplay.Test3.performed += OnTest3;
            _inputActions.Gameplay.Test4.performed += OnTest4;
        }

        private void OnDisable()
        {
            if (_inputActions != null)
            {
                _inputActions.Gameplay.Test1.performed -= OnTest1;
                _inputActions.Gameplay.Test2.performed -= OnTest2;
                _inputActions.Gameplay.Test3.performed -= OnTest3;
                _inputActions.Gameplay.Test4.performed -= OnTest4;
                _inputActions.Gameplay.Disable();
            }
        }

        private void OnTest1(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced UP 1 level (Setback)");
            if (GridMotionManager.Instance != null)
                GridMotionManager.Instance.MoveLevels(1);
        }

        private void OnTest2(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced DOWN 5 levels (Angel)");
            if (GridMotionManager.Instance != null)
                GridMotionManager.Instance.MoveLevels(-5);
        }

        private void OnTest3(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced DOWN 10 levels (Super Slam)");
            if (GridMotionManager.Instance != null)
                GridMotionManager.Instance.MoveLevels(-10);
        }

        [ContextMenu("Super Slam (-10)")]
        public void SuperSlam()
        {
            if (GridMotionManager.Instance != null)
                GridMotionManager.Instance.MoveLevels(-10);
        }

        private void OnTest4(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced UP 5 levels (Large Setback)");
            if (GridMotionManager.Instance != null)
                GridMotionManager.Instance.MoveLevels(5);
        }
    }
}