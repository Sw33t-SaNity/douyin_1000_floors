using UnityEngine;
using UnityEngine.InputSystem;

namespace ThousandFloors
{
    /// <summary>
    /// Debug component to test HeroGridMotion using the F1-F4 keys defined in IA_Hero.
    /// </summary>
    [RequireComponent(typeof(HeroGridMotion))]
    public class HeroGridMotionTester : MonoBehaviour
    {
        private HeroGridMotion _gridMotion;
        private IA_Hero _inputActions;

        private void Awake()
        {
            _gridMotion = GetComponent<HeroGridMotion>();
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
            _gridMotion.MoveLevels(1); 
        }

        private void OnTest2(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced DOWN 5 levels (Angel)");
            _gridMotion.MoveLevels(-5); 
        }

        private void OnTest3(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced DOWN 10 levels (Super Slam)");
            _gridMotion.MoveLevels(-10); 
        }

        [ContextMenu("Super Slam (-10)")]
        public void SuperSlam()
        {
            _gridMotion.MoveLevels(-10);
        }

        private void OnTest4(InputAction.CallbackContext context) 
        {
            Debug.Log("[Test] Forced UP 5 levels (Large Setback)");
            _gridMotion.MoveLevels(5); 
        }
    }
}