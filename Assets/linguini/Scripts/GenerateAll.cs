using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using System;
using EditAnimatorController;

public class GenerateAll : EditAnimatorControllerBase
{
//    [Serializable]
//    public class PickupDefinition
//    {
//        public GameObject pickupObject;

//        [Serializable]
//        public class HandDefinition
//        {
//            public GameObject pickupPoint;
//            public int handGesture;
//        }
//        public HandDefinition handL;
//        public HandDefinition handR;
//    }

//    //  Array of a collection of an GameObject to be picked up, index of hand gesture,
//    public PickupDefinition[] objectsToPickup;

//    // Parameters
//    private void AddParameters()
//    {
//        AddParameterIfNotExists("GestureLeft", AnimatorControllerParameterType.Int);
//        AddParameterIfNotExists("GestureRight", AnimatorControllerParameterType.Int);
//        //controllor.AddParameter("Expression", AnimatorControllerParameterType.Int);
//        //controllor.AddParameter("HairMaterial", AnimatorControllerParameterType.Int);
//        //controllor.AddParameter("CubeToggle", AnimatorControllerParameterType.Int);
//        //controllor.AddParameter("MirrorToggle", AnimatorControllerParameterType.Int);
//        //controllor.AddParameter("PickupToggle", AnimatorControllerParameterType.Int);
//        //controllor.AddParameter("ShowConstraints", AnimatorControllerParameterType.Int);
//    }

//    //private void AddFacialExpressionLayer()
//    //{
//    //    // Layer FacialExpression
//    //        AddAnimatorControllerLayer(
//    //        new AnimatorStateMachine()
//    //        {
//    //            name = "FacialExpression",
//    //            states = new ChildAnimatorState[] {
//    //                    newChildAnimatorState("あ", null),
//    //                    newChildAnimatorState("い", null)
//    //                },
//    //        },
//    //        weight: 0
//    //        );
//    //}

//    private void AddPickupLayers(GameObject pickupObject)
//    {
//        // Add Layers for picking up "pickupObject" 
//        AddPickupEnable();
//    }

//    private void AddPickupEnable()
//    {
//        // Layer CubeEnable
//        AddAnimatorControllerLayer(
//            new AnimatorStateMachine()
//            {
//                name = "CubeEnable",
//                states = new ChildAnimatorState[]
//                {
//                }
//            }
//            );
//    }

//    public void Generate()
//    {
//        if (controllor.parameters.Length != 0
//            || controllor.layers.Length != 1
//            || controllor.layers[0].stateMachine.states.Length != 0)
//        {
//            Debug.LogError("AnimationController not empty");
//            return;
//        }

//        AddParameters();

//        //AddFacialExpressionLayer();
//        //AddCubeLayers();

//    }

//}

//[CustomEditor(typeof(GenerateHandPickAnimatorControllor))]
//public class GenerateAnimationControllerEditor : Editor
//{
//    public override void OnInspectorGUI()
//    {
//        base.OnInspectorGUI();
//        if (GUILayout.Button("generate"))
//        {
//            GenerateHandPickAnimatorControllor generateAnimationControllor = target as GenerateHandPickAnimatorControllor;
//            generateAnimationControllor.Generate();
//        }
//    }
}
