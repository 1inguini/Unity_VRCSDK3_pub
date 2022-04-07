#if UNITY_EDITOR

using UnityEngine;
using System;
using System.Linq;
using EditAnimatorController;
using UnityEditor.Animations;
using UnityEditor;
using Mochineko.SimpleReorderableList;
using System.Collections.Generic;

/// <summary>
/// VRChat's hand gestures. convert to in by <c>(int)someHansdGestureVariable</c>
/// </summary>
[Serializable]
public enum HandGesture
{
    Neutral,
    Fist,
    HandOpen,
    FingerPoint,
    Victory,
    RockNRoll,
    HandGun,
    ThumbsUp,
}

/// <summary>
/// Definition of <c>GameObject</c>s constituting a pickup gimmick.
/// </summary>
[Serializable]
[CustomPropertyDrawer(typeof(PickupDefinition))]
public class PickupDefinition : PropertyDrawer
{
    public GameObject objectToPickup;

    [Serializable]
    public class HandDefinition
    {
        public bool enable;
        public GameObject pickupPoint;
        public int handGestureInt;
        public HandGesture handGesture;
    }

    public HandDefinition handL;
    public HandDefinition handR;


    private class SerializedHandDefinition
    {
        public SerializedProperty sHandDefinition;
        public SerializedProperty sEnable;
        public SerializedProperty sPickupPoint;
        public SerializedProperty sHandGestureInt;
        public SerializedProperty sHandGesture;

        public SerializedHandDefinition(SerializedProperty serializedHandDefiniton)
        {
            this.sHandDefinition = serializedHandDefiniton;
            sEnable = serializedHandDefiniton.FindPropertyRelative("enable");
            sPickupPoint = serializedHandDefiniton.FindPropertyRelative("pickupPoint");
            sHandGestureInt = serializedHandDefiniton.FindPropertyRelative("handGestureInt");
            sHandGesture = serializedHandDefiniton.FindPropertyRelative("handGesture");
        }

        public void ClampGestureInt()
        {
            sHandGestureInt.intValue = Mathf.Clamp(
                sHandGestureInt.intValue,
                Enum.GetValues(typeof(HandGesture)).Cast<int>().Min(),
                Enum.GetValues(typeof(HandGesture)).Cast<int>().Max()
                );
        }

        public void GestureIntUpdated()
        {
            ClampGestureInt();
            sHandGesture.enumValueIndex = sHandGestureInt.intValue;
            Debug.Log("GestureIntUpdated");
        }

        public void GestureUpdated()
        {
            sHandGestureInt.intValue = sHandGesture.enumValueIndex;
            Debug.Log("GestureUpdated");
        }

        public Rect DrawHandGesture(Rect position, GUIContent label)
        {
            void NewLine() => position.y += EditorGUIUtility.singleLineHeight;

            NewLine();
            if (sEnable.boolValue = EditorGUI.Toggle(
                position,
                label,
                sEnable.boolValue
                ))
            {
                EditorGUI.indentLevel++;
                NewLine();
                EditorGUI.PropertyField(
                    position,
                    sPickupPoint
                    );

                NewLine();
                EditorGUI.PropertyField(
                    new Rect(
                        position.x,
                        position.y,
                        EditorGUIUtility.labelWidth + EditorGUIUtility.fieldWidth,
                        position.height
                        ),
                    sHandGestureInt,
                    new GUIContent("Hand Gesture")
                    );
                GestureIntUpdated();

                EditorGUI.PropertyField(
                    new Rect(
                        position.x + EditorGUIUtility.labelWidth + EditorGUIUtility.fieldWidth,
                        position.y,
                        position.width - (EditorGUIUtility.labelWidth + EditorGUIUtility.fieldWidth),
                        position.height
                        ),
                    sHandGesture,
                    new GUIContent()
                    );
                GestureUpdated();

                EditorGUI.indentLevel--;

            }

            return position;
        }
    }
    private bool unfolded;

    private SerializedProperty sObjectToPickup;
    private SerializedProperty sEnableL;
    private SerializedHandDefinition sHandL;
    private SerializedHandDefinition sHandR;


    public override float GetPropertyHeight(SerializedProperty property, GUIContent label)
    {
        SerializedProperty sObjectToPickup = property.FindPropertyRelative("objectToPickup");

        SerializedHandDefinition sHandL =
            new SerializedHandDefinition(property.FindPropertyRelative("handL"));

        SerializedHandDefinition sHandR =
            new SerializedHandDefinition(property.FindPropertyRelative("handR"));

        int lines = 1;
        if (unfolded) lines += 3;
        if (sHandL.sEnable.boolValue) lines += 2;
        if (sHandR.sEnable.boolValue) lines += 2;
        return lines * EditorGUIUtility.singleLineHeight;
    }


    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        void NewLine() => position.y += EditorGUIUtility.singleLineHeight;

        SerializedProperty sObjectToPickup = property.FindPropertyRelative("objectToPickup");

        SerializedHandDefinition sHandL =
            new SerializedHandDefinition(property.FindPropertyRelative("handL"));
        
        SerializedHandDefinition sHandR =
            new SerializedHandDefinition(property.FindPropertyRelative("handR"));

        position.height = EditorGUIUtility.singleLineHeight;
        EditorGUI.BeginProperty(position, label, property);

        if (unfolded = EditorGUI.Foldout(position, unfolded, label))
        {
            NewLine();
            EditorGUI.PropertyField(
                position,
                sObjectToPickup
                );

            position = sHandL.DrawHandGesture(position, new GUIContent("Left Hand"));
            position = sHandR.DrawHandGesture(position, new GUIContent("Right Hand"));

            //NewLine(position);
            //handL.handGesture = (HandGesture)EditorGUI.IntField(
            //    position,
            //    (int)handL.handGesture
            //    );


        }
        EditorGUI.EndProperty();
    }
}

public class GenerateHandPickAnimatorController : EditAnimatorControllerBase
{
    public PickupDefinition aaa;
    /// <summary>
    /// Array of a collection of an GameObject to be picked up, index of hand gesture,
    /// </summary>
    public List<PickupDefinition> objectsToPickup;


    /// <summary>
    /// Parameters to detect hand gesture.
    /// </summary>
    private void AddParameters()
    {
        AddParameterIfNotExists("GestureLeft", AnimatorControllerParameterType.Int);
        AddParameterIfNotExists("GestureRight", AnimatorControllerParameterType.Int);
    }

    private void AddObjectEnable(GameObject obj)
    {
        // Layer ObjectEnable
        AddAnimatorControllerLayer(
            new AnimatorStateMachine()
            {
                name = obj.name + "Enable",
                states = new ChildAnimatorState[]
                {
                }
            }
            );
    }

    /// <summary>
    /// Add Layers for picking up <paramref name="obj"/> 
    /// </summary>
    /// <param name="obj"><c>GameObject</c> to pick up</param>
    private void AddOLayersforObject(GameObject obj)
    {
        AddObjectEnable(obj);
    }


    public void Generate()
    {
        if (IsAnimatorControllerNotEmpty())
        {
            Debug.LogError("AnimatorController: " + controller.name + " not empty.");
            return;
        }
        AddParameters();

        //AddFacialExpressionLayer();
        //AddCubeLayers();

    }

}

/// <summary>
/// Custom Inspector GUI for adding a button to call <c>Generate()</c> method.
/// </summary>
[CustomEditor(typeof(GenerateHandPickAnimatorController))]
public class GenerateAnimationControllerEditor : Editor
{
    private List<PickupDefinition> objectsToPickup;

    private SerializedProperty controller;
    private ReorderableList reorderableList;

    private GameObject PickupObjectAtIndex(int index)
    {
        return objectsToPickup.ElementAt(index).objectToPickup;
    }

    private void OnEnable()
    {
        objectsToPickup = (target as GenerateHandPickAnimatorController).objectsToPickup;

        controller = serializedObject.FindProperty("controller");
        SerializedProperty sObjectsToPickup = serializedObject.FindProperty("objectsToPickup");

        reorderableList = new ReorderableList(sObjectsToPickup);

        reorderableList.Native.elementHeightCallback = (index) =>
        (objectsToPickup[index].objectToPickup == null ?
        EditorGUIUtility.singleLineHeight :
        EditorGUI.GetPropertyHeight(
            sObjectsToPickup.GetArrayElementAtIndex(index)
            )
            ) + 2f;

        reorderableList.Native.drawElementCallback = (rect, index, isActive, isFocused) =>
        {
            if (sObjectsToPickup.GetArrayElementAtIndex(index) == null)
                return;
            if (PickupObjectAtIndex(index) == null)
            {
                rect.height = EditorGUIUtility.singleLineHeight;
                objectsToPickup[index].objectToPickup = (GameObject)EditorGUI.ObjectField(
                    rect,
                    PickupObjectAtIndex(index),
                    typeof(GameObject),
                    true
                    );
            }
            else
            {
                rect.x += 12f;
                rect.width -= 12f;
                EditorGUI.PropertyField(
                    rect,
                    sObjectsToPickup.GetArrayElementAtIndex(index),
                    new GUIContent(PickupObjectAtIndex(index).name),
                    true);
            }
        };

    }

    public override void OnInspectorGUI()
    {
        // DrawDefaultInspector();

        GenerateHandPickAnimatorController generateAnimationController = target as GenerateHandPickAnimatorController;
        serializedObject.Update();

        EditorGUI.BeginChangeCheck();
        {

            if (controller == null && reorderableList == null)
                return;

            EditorGUILayout.PropertyField(controller);
            reorderableList.Native.DoLayoutList();

            if (GUILayout.Button("generate"))
            {
                // generateAnimationController.Generate();
            }

        }
        if (EditorGUI.EndChangeCheck())
            serializedObject.ApplyModifiedProperties();
    }
}

#endif
