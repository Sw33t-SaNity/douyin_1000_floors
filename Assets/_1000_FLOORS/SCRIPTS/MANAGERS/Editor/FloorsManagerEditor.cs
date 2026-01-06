using UnityEngine;
using UnityEditor;

namespace ThousandFloors
{
    [CustomEditor(typeof(FloorsManager))]
    public class FloorsManagerEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            // 1. Draw the default Inspector (Variables, Sliders, etc.)
            DrawDefaultInspector();

            // 2. Get reference to the script
            FloorsManager generator = (FloorsManager)target;

            GUILayout.Space(20); 
            GUILayout.Label("Editor Preview Controls", EditorStyles.boldLabel);

            // 3. Create the Buttons
            if (GUILayout.Button("Generate Preview Level"))
            {
                // Register Undo so you can Ctrl+Z if you don't like the result
                Undo.RegisterFullObjectHierarchyUndo(generator.gameObject, "Generate Preview");
                generator.GeneratePreview();
            }

            if (GUILayout.Button("Clear Preview"))
            {
                Undo.RegisterFullObjectHierarchyUndo(generator.gameObject, "Clear Preview");
                generator.ClearAllChildPlatforms();
            }
        }
    }
}