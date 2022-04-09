#if UNITY_EDITOR

using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
using static
    Linguini.GenerateAnimatorController.V0_1.Generator;
using VRC.SDK3.Avatars.Components;

namespace Linguini.GenerateAnimatorController.V0_1.Util
{
    using Util = Script.Util;

    public static class Misc
    {
        public static void
            AddCondition(
                this AnimatorTransitionBase transition,
                AnimatorCondition condition)
        {
            AnimatorCondition[] temp = transition.conditions;
            ArrayUtility.Add(ref temp, condition);
            transition.conditions = temp;
        }

        //public static ChildAnimatorState NewState(
        //    this AnimatorStateMachine scene,
        //    string name,
        //    Motion motion = null,
        //    bool writeDefaultValues = false)
        //{
        //    var state = new ChildAnimatorState
        //    {
        //        position = scene.entryPosition - new Vector3(0, -20, 0),
        //        state = New.State(name, motion, writeDefaultValues),
        //    };

        //    var states = scene.states;
        //    ArrayUtility.Add(ref states, state);
        //    scene.states = states;
        //    return state;
        //}
    }

    public class BoolParameter : AnimatorControllerParameter
    {
        public BoolParameter()
        {
            type = AnimatorControllerParameterType.Bool;
        }
    }

    public static class New
    {
        public static AnimatorControllerLayer Layer(string name) =>
            new AnimatorControllerLayer
            {
                name = name,
                defaultWeight = 1,
                stateMachine = new AnimatorStateMachine()
            };

        public static ChildAnimatorState
            State(
                string name,
                Motion motion = null,
                bool writeDefaultValues = false) =>
            new ChildAnimatorState
            {
                position = Vector3.zero,
                state = new AnimatorState
                {
                    name = name,
                    motion = motion,
                    writeDefaultValues = writeDefaultValues,
                }
            };

        // default destination is Exit
        public static AnimatorStateTransition
            Transition(
                AnimatorState destination = null,
                AnimatorCondition[] conditions = null,
                bool hasExitTime = false,
                bool canTransitToSelf = false,
                float duration = 0,
                float exitTime = 0,
                bool hasFixedDuration = true,
                float offset = 0,
                TransitionInterruptionSource interruptionSource =
                    TransitionInterruptionSource.None,
                bool orderedInterruption = true
                ) =>
            new AnimatorStateTransition
            {
                destinationState = destination,
                conditions = conditions,
                hasExitTime = hasExitTime
                        || conditions == null
                        || conditions.Length == 0,
                duration = duration,
                exitTime = exitTime,
                hasFixedDuration = hasFixedDuration,
                offset = offset,
                interruptionSource = interruptionSource,
                orderedInterruption = orderedInterruption,
                canTransitionToSelf = canTransitToSelf,
                isExit = destination == null
            };

        public static BoolParameter
            BoolParameter(string name)
        {
            var result = new BoolParameter();
            result.name = name;
            return result;
        }

        public static AnimatorCondition
            BoolCondition(BoolParameter parameter, bool transitWhen) =>
                new AnimatorCondition
                {
                    mode = transitWhen
                        ? AnimatorConditionMode.If
                        : AnimatorConditionMode.IfNot,
                    parameter = parameter.name,
                    threshold = 0,
                };

        public static AnimationClip Clip(string name) =>
            new AnimationClip
            {
                name = name,
                hideFlags = HideFlags.NotEditable,
            };
    }

    public static class Grid
    {
        //private readonly AnimatorStateMachine scene;

        public static readonly Vector3 unit = new Vector3(250, 70, 0);

        public static readonly Vector3 left = unit.x * Vector3.left;
        public static readonly Vector3 right = unit.x * Vector3.right;
        public static readonly Vector3 down = unit.y * Vector3.down;
        public static readonly Vector3 up = unit.y * Vector3.up;

        private static Vector3 GetSmallCorrectedPosition(Vector3 position) =>
            position + 20 * Vector3.left;

        public static Vector3
            GetEntryPosition(this AnimatorStateMachine scene) =>
            GetSmallCorrectedPosition(scene.entryPosition);

        public static Vector3
            GetExitPosition(this AnimatorStateMachine scene) =>
            GetSmallCorrectedPosition(scene.exitPosition);

        public static Vector3
            GetAnyStatePosition(this AnimatorStateMachine scene) =>
            GetSmallCorrectedPosition(scene.anyStatePosition);

        private static Vector3 SmallPositionCorrection(Vector3 position) =>
            position - 20 * Vector3.left;

        public static Vector3
            SetEntryPosition(
                this AnimatorStateMachine scene,
                Vector3 position) =>
            scene.entryPosition = SmallPositionCorrection(position);

        public static Vector3
            SetExitPosition(
                this AnimatorStateMachine scene,
                Vector3 position) =>
            scene.exitPosition = SmallPositionCorrection(position);

        public static Vector3
            SetAnyStatePosition(
                this AnimatorStateMachine scene,
                Vector3 position) =>
            scene.anyStatePosition = SmallPositionCorrection(position);

        //public Vector3 previouse;
        //public Vector3 next;

        //public Grid(AnimatorStateMachine scene)
        //{
        //    this.scene = scene;
        //    previouse = Vector3.zero;
        //    scene.entryPosition = new Vector3(-80, -15, 0);
        //    scene.anyStatePosition = scene.entryPosition - new Vector3(0, -100, 0);
        //    Under();
        //}

        //public void Beside(float x, float y, float z)
        //{
        //    next = previouse -
        //        new Vector3(x * unit.x, y * unit.y, z * unit.z);
        //}

        //public void Under() => Beside(0, -1, 0);

        //public void Position(float x, float y, float z)
        //{
        //    next = new Vector3(x * unit.x, y * unit.y, z * unit.z);
        //}

        //public void MoveExit()
        //{
        //    scene.exitPosition =
        //        new Vector3(next.x + 20, next.y, next.z);
        //    previouse = next;
        //}

        //public AnimatorState NewState(
        //    string name,
        //    Motion motion,
        //    bool writeDefaultValues = false)
        //{
        //    var state = New.State(name, motion, writeDefaultValues);
        //    scene.AddState(state, next - new Vector3(100, 20, 0));
        //    previouse = next;
        //    Under();
        //    return state;
        //}
    }

    public class PlayableLayer : Generated
    {
        protected VRCAvatarDescriptor avatar;

        public string Path(Transform item) =>
            AnimationUtility.CalculateTransformPath(item, avatar.transform);

        public PlayableLayer(VRCAvatarDescriptor avatar)
        {
            this.avatar = avatar;
        }
    }

    public class FX : PlayableLayer
    {
        public FX(VRCAvatarDescriptor avatar) : base(avatar)
        {
        }

        public void Toggle(Transform[] items)
        {
            var itemsName = string.Join(" ", items.Select(item => item.name));

            var layer = NewLayer(
                $"{MethodBase.GetCurrentMethod().Name} {itemsName}");

            //var scene = new Grid(layer.stateMachine);

            var toggle = NewBoolParameter(layer.name);

            AnimationClip TogglingClip(bool active)
            {
                var clip = NewClip($"{layer.name}_{active}");
                foreach (var item in items)
                {
                    AnimationUtility.SetEditorCurve(
                        clip,
                        EditorCurveBinding.DiscreteCurve(
                            Path(item),
                            typeof(GameObject),
                            "m_IsActive"),
                        AnimationCurve.Constant(0, 1, active ? 1 : 0));
                }
                return clip;
            }

            // states
            ChildAnimatorState entry = New.State("Entry");
            ChildAnimatorState shown = New.State("Shown", TogglingClip(true));
            ChildAnimatorState hidden = New.State("Hidden", TogglingClip(false));

            // position states
            entry.position = layer.stateMachine.GetEntryPosition() - Grid.down;
            shown.position = entry.position - Grid.down - 0.5f * Grid.left;
            hidden.position = entry.position - Grid.down - 0.5f * Grid.right;
            layer.stateMachine.SetExitPosition(entry.position - 2 * Grid.down);

            layer.stateMachine.states = Util.Array(entry, shown, hidden);

            var showWhen = Util.Array(New.BoolCondition(toggle, true));
            var hideWhen = Util.Array(New.BoolCondition(toggle, false));
            // transitions
            entry.state.transitions = Util.Array(
                New.Transition(shown.state, showWhen),
                New.Transition(hidden.state, hideWhen));
            shown.state.transitions =
                Util.Array(New.Transition(conditions: hideWhen));
            hidden.state.transitions =
                Util.Array(New.Transition(conditions: showWhen));
        }
    }
}

#endif