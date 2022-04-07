#if UNITY_EDITOR
using AnimatorAsCode.V0;
using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace Linguini.Aac.V0
{
    public class Generated
    {
        public List<string> layerSuffixes = new List<string>();
        public List<string> parameterNames = new List<string>();
    }

    public abstract class AacDefinition : MonoBehaviour
    {
        [HideInInspector]
        public string assetKey = "";

        /// Create layers and return action to remove it
        public abstract Action Generate(AacFlBase aac);
    }

    [InitializeOnLoad]
    internal static class AacDefinitionInitialize
    {
        static AacDefinitionInitialize()
        {
            ObjectFactory.componentWasAdded -= OnComponentWasAdded;
            ObjectFactory.componentWasAdded += OnComponentWasAdded;
        }

        private static void OnComponentWasAdded(Component component)
        {
            var definition = (AacDefinition)component;
            if (definition.assetKey == "")
            {
                definition.assetKey = GUID.Generate().ToString();
            }
        }
    }
}
#endif
