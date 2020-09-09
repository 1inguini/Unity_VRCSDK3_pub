using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using System;
using EditAnimatorController;

public class GenerateHandPickAnimatorControllor : EditAnimatorControllerBase
{
    [Serializable]
    public class PickupDefinition
    {
        public GameObject pickupObject;

        [Serializable]
        public class HandDefinition
        {
            public GameObject pickupPoint;
            public int handGesture;
        }
        public HandDefinition handL;
        public HandDefinition handR;
    }

    //  Array of a collection of an GameObject to be picked up, index of hand gesture,
    public PickupDefinition[] objectsToPickup;

    // Parameters
    private void AddParameters()
    {
        AddParameterIfNotExists("GestureLeft", AnimatorControllerParameterType.Int);
        AddParameterIfNotExists("GestureRight", AnimatorControllerParameterType.Int);
    }

    private void AddOLayersforObject(GameObject obj)
    {
        // Add Layers for picking up "pickupObject" 
        AddObjectEnable();
    }

    private void AddObjectEnable()
    {
        // Layer CubeEnable
        AddAnimatorControllerLayer(
            new AnimatorStateMachine()
            {
                name = "CubeEnable",
                states = new ChildAnimatorState[]
                {
                }
            }
            );
    }

    public void Generate()
    {
        if (controllor.parameters.Length != 0
            || controllor.layers.Length != 1
            || controllor.layers[0].stateMachine.states.Length != 0)
        {
            Debug.LogError("AnimationController not empty");
            return;
        }

        AddParameters();

        //AddFacialExpressionLayer();
        //AddCubeLayers();

    }

}

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
