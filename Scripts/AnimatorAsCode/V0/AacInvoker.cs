//#if UNITY_EDITOR
//using AnimatorAsCode.V0;
//using UnityEditor;
//using UnityEditor.Animations;
//using VRC.SDK3.Avatars.Components;

//namespace Linguini.Aac.V0
//{
//    public class AacInvoker : EditorWindow
//    {
//        //private AacFlBase aac;

//        private VRCAvatarDescriptor _avatar;

//        private AnimatorController _assetContainer;

//        private bool _writeDefaults;

//        public AacDefinition[] definitions = new AacDefinition[1];

//        [MenuItem("AacDefinition/AacInvoker")]
//        public static void ShowWindow() => GetWindow<AacInvoker>();

//        public void Init()
//        {
//            foreach (var definition in definitions)
//                if (definition.aac == null
//                    || definition.avatar != _avatar
//                    || definition.assetContainer != _assetContainer
//                    || definition.writeDefaults != _writeDefaults)
//                {
//                    definition.avatar = _avatar;
//                    definition.assetContainer = _assetContainer;
//                    definition.writeDefaults = _writeDefaults;
//                    definition.aac = null;
//                    definition.Init();
//                }

//        }

//        public void Commit()
//        {
//            foreach (var definition in definitions)
//                definition.Commit();
//        }

//        public void Clean()
//        {
//            foreach (var definition in definitions)
//                definition.Clean();
//        }
//    }
//}
//#endif