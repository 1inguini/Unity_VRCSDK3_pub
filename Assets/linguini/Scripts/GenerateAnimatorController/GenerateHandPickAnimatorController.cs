#if UNITY_EDITOR

using UnityEngine;
using System;
using EditAnimatorController;
using UnityEditor.Animations;
using UnityEditor;
using Mochineko.SimpleReorderableList;

/// <summary>
/// Definition of <c>GameObject</c>s constituting a pickup gimmick.
/// </summary>
[Serializable]
[CustomPropertyDrawer(typeof(PickupDefinition))]
public class PickupDefinition : PropertyDrawer
{
    public GameObject pickupObject;

    [Serializable]
    public class HandDefinition
    {
        public GameObject pickupPoint;

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
        public HandGesture handGesture;
    }
    public HandDefinition handL;
    public HandDefinition handR;

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        //base.OnGUI(position, property, label);
        EditorGUI.BeginProperty(position, label, property);
        EditorGUI.PropertyField(position, property, new GUIContent(pickupObject ? pickupObject.name : "Please Select a GameObject"));
    }
}

public class GenerateHandPickAnimatorController : EditAnimatorControllerBase
{
    /// <summary>
    /// Array of a collection of an GameObject to be picked up, index of hand gesture,
    /// </summary>
    public PickupDefinition[] objectsToPickup;
    void DrawListItems(Rect rect, int index, bool isActive, bool isFocused)
    {

    }
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
    SerializedProperty controller;
    ReorderableList objectsToPickup;

    private void OnEnable()
    {
        controller = serializedObject.FindProperty("controller");
        objectsToPickup = new ReorderableList(serializedObject.FindProperty("objectsToPickup"));
    }

    public override void OnInspectorGUI()
    {
        GenerateHandPickAnimatorController generateAnimationController = target as GenerateHandPickAnimatorController;

        //base.DrawDefaultInspector();

        serializedObject.Update();

        EditorGUI.BeginChangeCheck();
        {
            if (controller != null)
                EditorGUILayout.PropertyField(controller);

            if (objectsToPickup != null)
                objectsToPickup.Layout();

            if (GUILayout.Button("generate"))
            {
                generateAnimationController.Generate();
            }

        }
        if (EditorGUI.EndChangeCheck())
            serializedObject.ApplyModifiedProperties();
        serializedObject.ApplyModifiedProperties();
    }
}

#endif
