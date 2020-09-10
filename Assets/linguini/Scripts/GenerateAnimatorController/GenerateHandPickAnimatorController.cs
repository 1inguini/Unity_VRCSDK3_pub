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
public class PickupDefinition
{
    public GameObject pickupObject;

    [Serializable]
    public class HandDefinition
    {
        public bool enable;
        public GameObject pickupPoint;
        public HandGesture handGesture;
    }
    public HandDefinition handL;
    public HandDefinition handR;
}

//[CustomPropertyDrawer(typeof(PickupDefinition))]
class PickupDefinitionProprtyDrawer : PropertyDrawer
{
    //public override float GetPropertyHeight(SerializedProperty property, GUIContent label)
    //{
    //    return 1 * EditorGUIUtility.singleLineHeight;
    //}

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        SerializedProperty sPickupPoint = property.FindPropertyRelative("pickupObject");

        EditorGUI.BeginProperty(position, label, property);

        /// pickupObject
        EditorGUI.PropertyField(
            new Rect(
                position.x,
                position.y,
                position.width,
                EditorGUIUtility.singleLineHeight
                ),
            property.FindPropertyRelative("pickupObject"),
            new GUIContent(
                sPickupPoint.objectReferenceValue ?
                sPickupPoint.objectReferenceValue.name :
                "Select Object to Pickup"
                )
        );

        //EditorGUI.PropertyField(
        //    new Rect(
        //        position.x,
        //        position.y + EditorGUIUtility.singleLineHeight,
        //        position.width,
        //        EditorGUIUtility.singleLineHeight
        //        ),
        //    property.FindPropertyRelative("handL")
        //    );

        EditorGUI.EndProperty();
    }
}

public class GenerateHandPickAnimatorController : EditAnimatorControllerBase
{
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
    List<PickupDefinition> objectsToPickup;

    SerializedProperty controller;
    ReorderableList reorderableList;

    private GameObject PickupObjectAtIndex(int index)
    {
        return objectsToPickup.ElementAt(index).pickupObject;
    }

    private void OnEnable()
    {
        objectsToPickup = (target as GenerateHandPickAnimatorController).objectsToPickup;

        controller = serializedObject.FindProperty("controller");
        SerializedProperty sObjectsToPickup = serializedObject.FindProperty("objectsToPickup");

        reorderableList = new ReorderableList(sObjectsToPickup);

        reorderableList.Native.elementHeightCallback = (index) =>
        (objectsToPickup[index].pickupObject == null ?
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
                objectsToPickup[index].pickupObject = (GameObject)EditorGUI.ObjectField(
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
        // base.DrawDefaultInspector();

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
        serializedObject.ApplyModifiedProperties();
    }
}

#endif
