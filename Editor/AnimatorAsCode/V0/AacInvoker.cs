#if UNITY_EDITOR
using AnimatorAsCode.V0;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
using VRC.SDK3.Avatars.Components;
using System;
using System.Reflection;

namespace Linguini.Aac.V0
{
    public class AacInvoker : EditorWindow
    {
        //private AacFlBase aac;
        public AacDefinition _definition = null;

        public MonoScript definitionScript;

        public VRCAvatarDescriptor _avatar;

        public AnimatorController _assetContainer;

        public bool _writeDefaults = false;

        public Editor editor;
        public Editor definitionEditor;

        public Type type;

        [MenuItem("Window/Animation/AacInvoker")]
        public static void ShowWindow() => GetWindow<AacInvoker>();

        private void OnEnable()
        {
            titleContent = new GUIContent("AacInvoker");

            Undo.undoRedoPerformed += OnUndoRedo;
            editor = Editor.CreateEditor(this);
            definitionEditor = Editor.CreateEditor(_definition);
            Repaint();
        }

        private void OnDisable()
        {
            Undo.undoRedoPerformed -= OnUndoRedo;
        }

        private void OnUndoRedo()
        {
            Repaint();
        }

        private void OnSelectionChange()
        {
            Repaint();
        }

        private void OnGUI()
        {
            //if (this) OnEnable();
            //editor.DrawHeader();
            //editor.DrawDefaultInspector();

            //EditorGUILayout.Space();

            //definitionScript =
            //    (MonoScript)EditorGUILayout.ObjectField(
            //        "Definition File",
            //        definitionScript, typeof(MonoScript), false);
            //if (definitionScript == null) return;
            //type = definitionScript.GetClass();

            ////if (_definition.GetType() == type) return;
            //_definition = (AacDefinition)CreateInstance(type);
            //_definition.avatar = _avatar;
            //_definition.assetContainer = _assetContainer;
            //_definition.writeDefaults = _writeDefaults;

            //EditorGUILayout.TextField(_definition.GetType().ToString());
            //definitionEditor = Editor.CreateEditor(_definition, null);
            //definitionEditor.DrawHeader();
            //definitionEditor.DrawDefaultInspector();
            //if (GUILayout.Button("Commit"))
            //{
            //    _definition.Init();
            //    _definition.Commit();
            //}

            //if (GUILayout.Button("Clean"))
            //{
            //    _definition.Clean();
            //}

        }
    }
}
#endif