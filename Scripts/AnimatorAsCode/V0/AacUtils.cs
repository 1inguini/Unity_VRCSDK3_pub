#if UNITY_EDITOR

using AnimatorAsCode.V0;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.Animations;
using VRC.SDK3.Avatars.Components;

namespace Linguini.Aac.V0.AacUtils
{
    public static class Misc
    {
        public static string ConstraintSourceWeight(int i) =>
            $"Sources.Array.data[{i}].weight";
    }

    public class Base
    {
        public readonly AacFlBase aac;

        public Base(AacFlBase _aac)
        {
            aac = _aac;
        }

        public Action
        ShaderFloats(
            VRCAvatarDescriptor root,
            string shaderFamily,
            (string name, float min, float max)[] properties
        )
        {
            string methodName = MethodBase.GetCurrentMethod().Name;
            var lilToons =
                root
                    .transform
                    .GetComponentsInChildren<Renderer>()
                    .Where(renderer =>
                        renderer
                            .sharedMaterials
                            .Any(material =>
                                material.shader.name.Contains(shaderFamily)));

            var layerNames =
                properties
                    .Select(property =>
                    {
                        string layerName =
                            $"{methodName} {shaderFamily} {property.name}";
                        AacFlLayer fx = aac.CreateSupportingFxLayer(layerName);

                        fx
                            .NewState(property.name)
                            .WithAnimation(aac
                                .NewClip()
                                .Animating(clip =>
                                {
                                    foreach (var renderer in lilToons)
                                    {
                                        clip
                                            .Animates(renderer,
                                            $"material.{property.name}")
                                            .WithFrameCountUnit(keyframes =>
                                                keyframes
                                                    .Linear(0, property.min)
                                                    .Linear(100, property.max));
                                    }
                                }))
                            .MotionTime(fx.FloatParameter(layerName));
                        return layerName;
                    }) // required for evaluating
                    .ToArray();

            return () =>
            {
                foreach (var layerName in layerNames)
                {
                    aac.RemoveAllSupportingLayers(layerName);
                }
            };
        }

        public Action
        SwapMaterial(
            Renderer renderer,
            int slot,
            Material[] alternativeMaterials
        )
        {
            string layerName =
                $"{MethodBase.GetCurrentMethod().Name} {renderer.name} {slot}";
            AacFlLayer fx = aac.CreateSupportingFxLayer(layerName);

            // // bool for each alternative material
            var parameters =
                alternativeMaterials
                    .Select(material =>
                        fx.BoolParameter($"{layerName} {material.name}"))
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

            AacFlState entry = new Layer(fx).Entry();

            AacFlState original = newState(originalMaterial).RightOf();
            entry.TransitionsTo(original).When(parameterGroup.AreFalse());
            original.Exits().When(parameterGroup.IsAnyTrue());

            var alternatives = alternativeMaterials.Select(newState);
            for (int i = 0; i < alternativeMaterials.Length; i++)
            {
                var state = alternatives.ElementAt(i);
                var parameter = parameters.ElementAt(i);

                entry.TransitionsTo(state).When(parameter.IsTrue());
                state.Exits().When(parameter.IsFalse());
            }

            // cleanup Action
            return () =>
            {
                aac.RemoveAllSupportingLayers(layerName);
            };
        }

        /// Deactivates GameObject and activates with animation
        public Action Enable(GameObject hidden)
        {
            hidden.SetActive(false);

            var layerName =
                $"{MethodBase.GetCurrentMethod().Name} {hidden.name}";

            var fx = aac.CreateSupportingFxLayer(layerName);

            fx
                .NewState(hidden.name)
                .WithAnimation(aac.NewClip().Toggling(hidden, true));

            return () =>
            {
                aac.RemoveAllSupportingLayers(layerName);
            };
        }

        public Action Toggle(GameObject[] items)
        {
            var itemsName = string.Join(" ", items.Select(item => item.name));
            var layerName = $"{MethodBase.GetCurrentMethod().Name} {itemsName}";
            var fx = aac.CreateSupportingFxLayer(layerName);

            var itemParam = fx.BoolParameter(layerName);

            AacFlState entry = new Layer(fx).Entry();

            AacFlClip newClip(bool active)
            {
                var clip = aac.NewClip();
                foreach (var item in items)
                {
                    clip.Toggling(item, active);
                }
                return clip;
            }
            AacFlState shown =
                fx
                    .NewState("Shown")
                    .RightOf(entry)
                    .WithAnimation(newClip(true));
            entry.TransitionsTo(shown).When(itemParam.IsTrue());
            shown.Exits().When(itemParam.IsFalse());

            AacFlState hidden =
                fx
                    .NewState("Hidden")
                    .Under(shown)
                    .WithAnimation(newClip(false));
            entry.TransitionsTo(hidden).When(itemParam.IsFalse());
            hidden.Exits().When(itemParam.IsTrue());

            return () =>
            {
                aac.RemoveAllSupportingLayers(layerName);
            };
        }

        public Action Toggle(GameObject item)
        {
            return Toggle(new GameObject[] { item });
        }

        public Action Toggle(Component[] components)
        {
            var itemsName =
                string
                    .Join(" ",
                    components.Select(component => component.transform.name));
            var layerName = $"{MethodBase.GetCurrentMethod().Name} {itemsName}";
            var fx = aac.CreateSupportingFxLayer(layerName);

            var itemParam = fx.BoolParameter(layerName);

            AacFlState entry = new Layer(fx).Entry();

            AacFlClip newClip(bool active)
            {
                var clip = aac.NewClip();
                foreach (var component in components)
                {
                    clip.TogglingComponent(component, active);
                }
                return clip;
            }
            var shown =
                fx
                    .NewState("Shown")
                    .RightOf(entry)
                    .WithAnimation(newClip(true));
            var hidden =
                fx
                    .NewState("Hidden")
                    .Under(shown)
                    .WithAnimation(newClip(false));

            entry.TransitionsTo(shown).When(itemParam.IsTrue());
            shown.Exits().When(itemParam.IsFalse());

            entry.TransitionsTo(hidden).When(itemParam.IsFalse());
            hidden.Exits().When(itemParam.IsTrue());

            return () =>
            {
                aac.RemoveAllSupportingLayers(layerName);
            };
        }

        public Action Toggle(Component item)
        {
            return Toggle(new Component[] { item });
        }

        public Action Pickup(GameObject item, float movementLength)
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

            AacFlState entry = new Layer(fx).Entry();

            AacFlState moveMeshFromConstraintToBoth =
                fx.NewState("MoveMesh Constraint¨Both")
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
                    "MoveMesh Constraint¨"
                    + mesh.GetSource(pickup).sourceTransform.name;

                AacFlState state = fx.NewState(stateName)
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
                            clip
                                .Animates(mesh,
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

            return () =>
            {
                aac.RemoveAllSupportingLayers(layerName);
            };
        }
    }

    public class Layer
    {
        public readonly AacFlLayer layer;

        public Layer(AacFlLayer _layer)
        {
            layer = _layer;
        }

        public AacFlState Entry()
        {
            return layer.NewState("Entry");
        }
    }
}

#endif