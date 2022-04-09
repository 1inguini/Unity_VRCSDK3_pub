#if UNITY_EDITOR
using AnimatorAsCode.V0;
using Linguini.Aac.V0.AacUtils;
using System;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
using UnityEngine.Animations;
using VRC.SDK3.Avatars.Components;
using Util = Linguini.Script.Util;

namespace Linguini.Aac.V0
{
    public abstract class AacDefinition : EditorWindow, Util.IInvokable
    {
        [HideInInspector]
        public string assetKey = "";

        public VRCAvatarDescriptor avatar;

        public AnimatorController assetContainer;

        public bool writeDefaults;

        protected AacFlBase aac = null;

        public AacDefinition() { }

        private void OnGUI()
        {
            Editor.CreateEditor(this).OnInspectorGUI();
        }


        public void Init()
        {
            if (aac == null)
                aac = AacV0.Create(new AacConfiguration
                {
                    SystemName = GetType().ToString(),
                    AvatarDescriptor = avatar,
                    AnimatorRoot = avatar.transform,
                    DefaultValueRoot = avatar.transform,
                    AssetContainer = assetContainer,
                    AssetKey = assetKey,
                    DefaultsProvider = new AacDefaultsProvider(writeDefaults: writeDefaults)
                });
        }

        public abstract void Commit();

        public void Clean()
        {
            if (aac != null)
            {
                aac.RemovePreviousLayers();
                aac.RemovePreviousParameters();
                aac.ClearPreviousAssets();
            }
        }

        protected void ShaderFloats(string shaderFamily, params (string name, float min, float max)[] properties)
        {
            string methodName = MethodBase.GetCurrentMethod().Name;
            var lilToons =
                avatar.transform.GetComponentsInChildren<Renderer>()
                    .Where(renderer => renderer.sharedMaterials.Any(material => material.shader.name.Contains(shaderFamily)));

            foreach (var property in properties)
            {
                string uniqueName =
                    $"{methodName} {shaderFamily} {property.name}";
                AacFlLayer fx = aac.CreateSupportingFxLayer(uniqueName);

                fx.NewState(property.name)
                    .WithAnimation(aac.NewClip().Animating(clip =>
                    {
                        foreach (var renderer in lilToons)
                            clip.Animates(renderer, $"material.{property.name}")
                                .WithFrameCountUnit(keyframes =>
                                    keyframes
                                        .Linear(0, property.min)
                                        .Linear(100, property.max));
                    }))
                    .MotionTime(fx.FloatParameter(uniqueName));
            }
        }

        protected void
        SwapMaterial(
            Renderer renderer,
            int slot,
            Material[] alternativeMaterials
        )
        {
            var uniqueName =
                $"{MethodBase.GetCurrentMethod().Name} {renderer.name} {slot}";
            AacFlLayer fx = aac.CreateSupportingFxLayer(uniqueName);

            // // bool for each alternative material
            var parameters =
                alternativeMaterials
                    .Select(material =>
                        fx.BoolParameter($"{uniqueName} {material.name}"))
                    .ToArray();
            var parameterGroup = fx.BoolParameters(parameters);

            Material originalMaterial = renderer.sharedMaterials[slot];

            AacFlState newState(Material material) =>
                    fx
                        .NewState(material.name)
                        .Under()
                        .WithAnimation(aac
                            .NewClip()
                            .SwappingMaterial(renderer, slot, material));

            AacFlState entry = fx.Entry();

            AacFlState original = newState(originalMaterial).RightOf();
            entry.TransitionsTo(original).When(parameterGroup.AreFalse());
            original.Exits().When(parameterGroup.IsAnyTrue());

            var alternatives = alternativeMaterials.Select(newState);
            foreach (var (materials, i) in Util.Indexed(alternativeMaterials))
            {
                var state = alternatives.ElementAt(i);
                var parameter = parameters.ElementAt(i);

                entry.TransitionsTo(state).When(parameter.IsTrue());
                state.Exits().When(parameter.IsFalse());
            }
        }

        protected void Enable(Transform show)
        {
            var nameBase = MethodBase.GetCurrentMethod().Name;

            // Deactivate GameObject
            show.gameObject.SetActive(false);

            aac.CreateSupportingFxLayer($"{nameBase} {show.name}")
                .NewState(show.name)
                .WithAnimation(aac.NewClip().Toggling(show.gameObject, true));
        }

        // isActive does nothing for now
        protected void Toggle(params Component[] components)
        {
            var itemsName =
                string.Join(" ", components.Select(component => component.gameObject.name));
            var uniqueName = $"{MethodBase.GetCurrentMethod().Name} {itemsName}";
            var fx = aac.CreateSupportingFxLayer(uniqueName);

            var itemParam = fx.BoolParameter(uniqueName);

            AacFlState entry = fx.Entry();

            AacFlState Path(bool condition, string stateName)
            {
                var clip = aac.NewClip();
                foreach (var component in components)
                {
                    if (component is Transform)
                        clip.Toggling(component.gameObject, condition ^ component.gameObject);
                    else
                        clip.TogglingComponent(component, condition ^ component);
                }
                var state = fx.NewState(stateName).WithAnimation(clip);
                entry.TransitionsTo(state).When(itemParam.IsEqualTo(condition));
                state.Exits().When(itemParam.IsEqualTo(!condition));
                return state;
            }

            Path(false, "Hidden").Under(
                Path(true, "Shown").RightOf(entry));
        }

        protected void Pickup(GameObject item, float movementLength)
        {
            var layerName = $"{MethodBase.GetCurrentMethod().Name} {item.name}";

            ParentConstraint constraint = item.transform.Find("Constraint")
                .GetComponent<ParentConstraint>();
            ParentConstraint mesh = item.transform.Find("Mesh")
                .GetComponent<ParentConstraint>();
            ConstraintSource meshOfConstraint = constraint.GetSource(0);
            ConstraintSource constraintOfMesh = mesh.GetSource(0);
            ConstraintSource[] pickupsOfMesh =
                new ConstraintSource[mesh.sourceCount - 1];
            for (int i = 0; i < mesh.sourceCount - 1; i++)
            {
                pickupsOfMesh[i] = mesh.GetSource(i + 1);
            }

            var fx = aac.CreateSupportingFxLayer(layerName);

            AacFlState entry = fx.Entry();

            AacFlState moveMeshFromConstraintToBoth =
                fx.NewState("MoveMesh Constraint→Both")
                   .WithAnimation(aac.NewClip().Animating(clip =>
                   {
                       clip
                            .Animates(constraint, "Active")
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Constant(0, 0)
                                    .Constant(movementLength, 0)
                                );

                       clip
                            .Animates(mesh, "Active")
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Constant(0, 1)
                                    .Constant(movementLength, 1)
                                );

                       clip
                            .Animates(mesh, Misc.ConstraintSourceWeight(0))
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Easing(0, 1)
                                    .Easing(movementLength, 0)
                                );

                       foreach (int pickup in pickupsOfMesh.Select((_, i) => i))
                       {
                           clip
                                .Animates(mesh,
                                    Misc.ConstraintSourceWeight(pickup))
                                .WithFrameCountUnit(keyframes =>
                                    keyframes
                                        .Easing(0, 0)
                                        .Easing(movementLength, 1)
                                    );
                       }
                   }
                   ));

            foreach (int pickup in pickupsOfMesh.Select((_, i) => i))
            {
                int[] others = new int[pickupsOfMesh.Length - 1];
                Array.Copy(pickupsOfMesh, 1, others, 0, others.Length);

                var stateName =
                    "MoveMesh Constraint→"
                    + mesh.GetSource(pickup).sourceTransform.name;

                AacFlState state = fx.NewState(stateName)
                    .WithAnimation(aac.NewClip().Animating(clip =>
                    {
                        clip.Animates(constraint, "Active")
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Constant(0, 0)
                                    .Constant(movementLength, 0)
                                );

                        clip.Animates(mesh, "Active")
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Constant(0, 1)
                                    .Constant(movementLength, 1)
                                );

                        clip.Animates(mesh, Misc.ConstraintSourceWeight(0))
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Easing(0, 1)
                                    .Easing(movementLength, 0)
                                );
                        clip.Animates(mesh,
                                Misc.ConstraintSourceWeight(pickup))
                            .WithFrameCountUnit(keyframes =>
                                keyframes
                                    .Easing(0, 0)
                                    .Easing(movementLength, 1)
                                );

                        foreach (int noPickup in others)
                        {
                            clip
                                .Animates(mesh,
                                    Misc.ConstraintSourceWeight(noPickup))
                                .WithFrameCountUnit(keyframes =>
                                    keyframes
                                        .Constant(0, 0)
                                        .Constant(movementLength, 0)
                                    );
                        }
                    }
                    ));
            }
        }
    }

    [CustomEditor(typeof(AacDefinition), true)]
    public class AacDefinition_Editor : Util.Invokable_Editor<AacDefinition> { }

    //public class AacDefinitionReciver : PresetSelectorReceiver
    //{

    //    private Preset initialValues;
    //    private AacDefinition current;

    //    public void Init(AacDefinition current)
    //    {
    //        this.current = current;
    //        initialValues = new Preset(current);
    //    }

    //    public override void OnSelectionChanged(Preset selection)
    //    {
    //        if (selection != null)
    //        {
    //            // Apply the selection to the temporary settings
    //            selection.ApplyTo(current);
    //        }
    //        else
    //        {
    //            // None have been selected. Apply the Initial values back to the temporary selection.
    //            initialValues.ApplyTo(current);
    //        }
    //    }

    //    public override void OnSelectionClosed(Preset selection)
    //    {
    //        // Call selection change one last time to make sure you have the last selection values.
    //        OnSelectionChanged(selection);
    //        // Destroy the receiver here, so you don't need to keep a reference to it.
    //        DestroyImmediate(this);
    //    }
    //}

    //[InitializeOnLoad]
    //internal static class AacDefinitionInitialize
    //{
    //    static AacDefinitionInitialize()
    //    {
    //        ObjectFactory.componentWasAdded -= OnComponentWasAdded;
    //        ObjectFactory.componentWasAdded += OnComponentWasAdded;
    //    }

    //    private static void OnComponentWasAdded(Component component)
    //    {
    //        var definition = (AacDefinition)component;
    //        if (definition.assetKey == "")
    //        {
    //            definition.assetKey = GUID.Generate().ToString();
    //        }
    //    }
    //}
}
#endif