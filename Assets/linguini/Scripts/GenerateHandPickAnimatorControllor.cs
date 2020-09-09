using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using System;
using EditAnimatorController;


/// <summary>
/// Definition of <c>GameObject</c>s constituting a pickup gimmick.
/// </summary>
[Serializable]
public class PickupDefinition
{
    public static GameObject pickupObject;

    [Serializable]
    public class HandDefinition
    {
        public static GameObject pickupPoint;
        public static int handGesture;
    }
    public static HandDefinition handL;
    public static HandDefinition handR;
}

public class GenerateHandPickAnimatorControllor : EditAnimatorControllerBase
{
    /// <summary>
    /// Array of a collection of an GameObject to be picked up, index of hand gesture,
    /// </summary>
    public PickupDefinition[] objectsToPickup;

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
        if (IsAnimatorControllorNotEmpty())
        {
            Debug.LogError("AnimatorControllor: " + controllor.name + " not empty.");
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
[CustomEditor(typeof(GenerateHandPickAnimatorControllor))]
public class GenerateAnimationControllerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("generate"))
        {
            GenerateHandPickAnimatorControllor generateAnimationControllor = target as GenerateHandPickAnimatorControllor;
            generateAnimationControllor.Generate();
        }
    }
}
