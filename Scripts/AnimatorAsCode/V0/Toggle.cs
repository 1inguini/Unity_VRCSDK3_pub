//#if UNITY_EDITOR

//using UnityEngine;
//using VRC.SDK3.Avatars.Components;
//using UnityEditor;
//using UnityEditor.Animations;
//using AnimatorAsCode.V0;
//using Linguini.Aac.V0;
//using System;
//using System.Collections.Generic;

//namespace Linguini
//{
//    public class Toggle : AacDefinition
//    {
//        public GameObject[] items;

//        public override void Commit()
//        {
//            if (aac == null) return;

//            foreach (var item in items)
//            {
//                var fx = aac.CreateSupportingFxLayer(item.name);

//                var itemParam = fx.BoolParameter($"Toggle{item.name}");

//                var entry = fx.NewState("Entry");

//                var hidden =
//                    fx.NewState("Hidden")
//                        .WithAnimation(aac.NewClip().Toggling(item, false))
//                        .RightOf();

//                var shown =
//                    fx.NewState("Shown")
//                        .WithAnimation(aac.NewClip().Toggling(item, true))
//                        .Under();

//                void Path(bool condition, AacFlState state)
//                {
//                    entry.TransitionsTo(state).When(itemParam.IsEqualTo(condition));
//                    state.Exits().When(itemParam.IsEqualTo(!condition));
//                }

//                Path(true, shown);
//                Path(false, hidden);
//            }
//        }
//    }
//}

//#endif