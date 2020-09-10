#if UNITY_EDITOR

using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using System;

/// <summary>
/// A Class to generate new position for each new <c>AnimatorState</c>
/// </summary>
class StatePosition
{
    private Vector3 pos = new Vector3(0, 60, 0);
    /// <summary>
    /// Generate a new position each time called.
    /// </summary>
    /// <returns>The new position.</returns>
    public Vector3 New()
    {
        pos = pos + (Vector3.up * 60);
        return pos;
    }
}
namespace EditAnimatorController
{
    /// <summary>
    /// Base Class for Class to Edit AnimatorControllers
    /// </summary>
    public class EditAnimatorControllerBase : MonoBehaviour
    {
        /// <summary>
        /// Check whether the <see cref="controllor"/> is empty or not.
        /// </summary>
        /// <returns><c>true</c> when <c>AnimatorControllor</c> is not empty.</returns>
        protected bool IsAnimatorControllorNotEmpty() =>
            controllor.parameters.Length != 0
            || controllor.layers.Length != 1
            || controllor.layers[0].stateMachine.states.Length != 0;

        /// <summary>
        /// Adds a new <c>AnimatorControllerLayer</c> from <c>AnimatorStateMachine</c>
        /// </summary>
        /// <param name="stateMachine"><c>AnimatorStateMachine</c> constituting the new layer. </param>
        /// <param name="weight">Weight of the new layer, defaulted to 1</param>
        protected void AddAnimatorControllerLayer(AnimatorStateMachine stateMachine, float weight = 1)
        {
            controllor.AddLayer(
                new AnimatorControllerLayer()
                {
                    defaultWeight = weight,
                    name = stateMachine.name,
                    stateMachine = stateMachine
                }
                );
        }

        private static StatePosition pos = new StatePosition();
        /// <summary>
        /// Creates <c>ChildAnimatorState</c> with automatically generated position.
        /// </summary>
        /// <param name="name">Name of the new <c>AnimatorState</c>.</param>
        /// <param name="motion"><c>Motion</c> of the new <c>AnimatorState</c>.</param>
        /// <returns><c>ChildAnimatorState</c> with automatically generated position.</returns>
        protected ChildAnimatorState NewChildAnimatorState(string name, Motion motion)
        {
            var childState = new ChildAnimatorState()
            {
                position = pos.New(),
                state = new AnimatorState()
                {
                    name = name,
                    motion = motion
                }
            };
            return childState;
        }


        private enum ParameterUniqueness
        {
            SameNameDifferentType,
            ExactMatch,
            Unique,
        }
        /// <summary>
        /// Judge if the name and type is redundant compared to <c>AnimatorControllerParameter</c> <paramref name="param"/>
        /// </summary>
        /// <param name="param"><c>AnimatorControllerParameter</c> to compare name and type with.</param>
        /// <param name="name">Planned name for the new <c>AnimatorControllerParameter</c>.</param>
        /// <param name="type">Planned type for the new <c>AnimatorControllerParameter</c>.</param>
        /// <returns>Uniqueness of the planned <c>AnimatorControllerParameter</c>.</returns>
        private ParameterUniqueness JudgeParameterUniqueness(AnimatorControllerParameter param, string name, AnimatorControllerParameterType type)
        {
            if (param.name != name)
                return ParameterUniqueness.Unique;
            if (param.type == type)
                return ParameterUniqueness.ExactMatch;
            return ParameterUniqueness.SameNameDifferentType;
        }

        /// <summary> 
        /// Adds new AnimatorControllerParameter to <see cref="controllor"/> if the intended parameter doesn't exist.
        /// Returns true when the intended <c>AnimatorControllerParameter</c> is existing after <c>AddParameterIfNotExists()</c> is called (Does not distinguish whether it Existed in the first place or added by this method), returns false when a <c>AnimatorControllerParameter</c> with intended name exists but has different type.
        /// </summary>
        /// <param name="name">Name of <c>AnimatorControllerParameter</c> to add.</param>
        /// <param name="type">Type of <c>AnimatorControllerParameter</c> to add.</param>
        /// <returns>Whether the <c>AnimatorControllerParameter</c> is existing in the <see cref="controllor"/></returns>
        protected bool AddParameterIfNotExists(string name, AnimatorControllerParameterType type)
        {
            foreach (AnimatorControllerParameter param in controllor.parameters)
            {
                switch (JudgeParameterUniqueness(param, name, type))
                {
                    case ParameterUniqueness.ExactMatch:
                        return true;
                    case ParameterUniqueness.SameNameDifferentType:
                        return false;
                }
            }
            controllor.AddParameter(name, type);
            return true;
        }

        /// <summary>
        /// AnimationController to edit.
        /// </summary>
        public AnimatorController controllor;

        /// <summary>
        /// Animation Clips in the same directory as the <see cref="controllor"/>.
        /// </summary>
        /// <returns>Animation Clips in the same directory as the <see cref="controllor"/> as <c>List<AnimationClip></c>.</returns>
        protected List<AnimationClip> AnimationClips()
        {
            return AssetDatabase.LoadAllAssetsAtPath(AssetDatabase.GetAssetPath(controllor))
                    .Where(a => a.GetType() == typeof(AnimationClip))
                    .Select(a => (AnimationClip)a)
                    .ToList();
        }
    }
}

#endif