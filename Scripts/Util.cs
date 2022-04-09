#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using System.Linq;
using UnityEditor.Presets;

namespace Linguini.Script
{
    public static class Util
    {
        public static IEnumerable<(T item, int index)>
            Indexed<T>(this IEnumerable<T> source) =>
                source.Select((v, i) => (v, i));

        public static T[] Array<T>(params T[] array) => array;

        public static Transform FindOrAdd(this Transform self, string name)
        {
            var child = self.Find(name);
            if (!child)
            {
                child = new GameObject(name).transform;
                child.parent = self;
            }
            return child;
        }

        public interface IInvokable
        {
            void Init();
            void Commit();
            void Clean();
        }

        public class Invokable_Editor<Target> : Editor where Target: Object, IInvokable
        {
            public override void OnInspectorGUI()
            {
                DrawDefaultInspector();
                Additional();
            }

            public void Additional()
            {
                var my = (Target)target;

                if (GUILayout.Button("Commit"))
                {
                    my.Init();
                    my.Commit();
                }

                if (GUILayout.Button("Clean"))
                {
                    my.Clean();
                }
            }
        }
    }
}
#endif