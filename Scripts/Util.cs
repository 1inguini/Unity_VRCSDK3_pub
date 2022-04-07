using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using System.Linq;

namespace Linguini.Script
{
    public static class Util
    {
        public static IEnumerable<(T item, int index)>
            Indexed<T>(this IEnumerable<T> source) =>
                source.Select((v, i) => (v, i));

        public static T[]
                Array<T>(params T[] array) => array;
    }
}