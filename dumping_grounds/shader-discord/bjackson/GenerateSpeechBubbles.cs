#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using UnityEditor.Presets;
using UnityEditor.Animations;
using VRC.SDK3.Avatars.Components;
using static VRC.SDKBase.VRC_AvatarParameterDriver;
using System;
using System.Collections.Immutable;

public class GenerateSpeechBubbles : MonoBehaviour
{
    private static AnimationCurve FixedValue(float value)
    {
        Keyframe[] keyFrames = new Keyframe[2];

        for (int j = 0; j < 2; j++)
        {
            keyFrames[j] = new Keyframe();
            keyFrames[j].time = j / 60.0f;
            keyFrames[j].value = value;
        }

        return new AnimationCurve(keyFrames);
    }

    private static void SaveAnimationClip(AnimationClip clip)
    {
        AssetDatabase.CreateAsset(clip, $"Assets/Tests/Animations/{clip.name}.anim");
    }

    enum Viseme
    {
        sil =  0,
        pp  =  1,
        ff  =  2,
        th  =  3,
        dd  =  4,
        kk  =  5,
        ch  =  6,
        ss  =  7,
        nn  =  8,
        rr  =  9,
        aa  = 10,
        e   = 11,
        i   = 12,
        o   = 13,
        u   = 14
    }

    // These are one-way prohibited transitions. Same->same implied in code below.
    private static readonly ImmutableHashSet<Tuple<Viseme, Viseme>> BlockedVisemeTransitions = ImmutableHashSet.Create(
        Tuple.Create(Viseme.ff, Viseme.pp),
        Tuple.Create(Viseme.pp, Viseme.th), Tuple.Create(Viseme.th, Viseme.pp),
        Tuple.Create(Viseme.pp, Viseme.dd), Tuple.Create(Viseme.dd, Viseme.pp),
        Tuple.Create(Viseme.pp, Viseme.kk),
        Tuple.Create(Viseme.ff, Viseme.th), Tuple.Create(Viseme.th, Viseme.ff),
        Tuple.Create(Viseme.ff, Viseme.dd),
        Tuple.Create(Viseme.ff, Viseme.kk),
        Tuple.Create(Viseme.ff, Viseme.ch), Tuple.Create(Viseme.ch, Viseme.ff),
        Tuple.Create(Viseme.dd, Viseme.th),
        Tuple.Create(Viseme.dd, Viseme.kk), Tuple.Create(Viseme.kk, Viseme.dd),
        Tuple.Create(Viseme.ch, Viseme.kk), Tuple.Create(Viseme.kk, Viseme.ch),
        Tuple.Create(Viseme.ss, Viseme.th),
        Tuple.Create(Viseme.ss, Viseme.ch)
    );

    private const int COUNT = 10;
    private const int VISEME_COUNT = 15;
    private static readonly float[] VisemeWidths = { 0.0f, 0.5f, 0.5f, 1.0f, 0.5f, 0.5f, 1.0f, 0.5f, 0.5f, 0.5f, 0.5f, 1.0f, 0.25f, 1.0f, 0.5f };

    [MenuItem("Tools/Generate Speech Bubble Animations")]
    static void DoSomething()
    {
        AnimationClips? clips = null;

        foreach (var avatar in FindObjectsOfType<VRCAvatarDescriptor>())
        {
            if (avatar.customizeAnimationLayers)
            {
                VRCAvatarDescriptor.CustomAnimLayer fxLayer = avatar.baseAnimationLayers[4];
                if (fxLayer.animatorController != null && !fxLayer.isDefault && fxLayer.type == VRCAvatarDescriptor.AnimLayerType.FX)
                {
                    AnimatorController fxController = fxLayer.animatorController as AnimatorController;
                    Debug.Log($"found FX controller on {avatar.name}: {fxController.name}");
                    RemoveSpeechBubbleAnimations(fxController);
                    if (!clips.HasValue)
                        clips = MakeAnimationClips();
                    AddSpeechBubbleAnimations(clips.Value, fxController);
                }
            }
        }

        if (!clips.HasValue)
            clips = MakeAnimationClips();
        var controller = new AnimatorController();
        // Add to AssetDatabase early because helper functions creating child objects below will see that and
        // automatically HideInHierarchy+AddObjectToAsset because the controller is in the AssetDatabase. If you
        // try to do it after like "saving" then you will have to do all of that manually.
        AssetDatabase.CreateAsset(controller, "Assets/Tests/example.controller");
        AddSpeechBubbleAnimations(clips.Value, controller);
    }

    private struct AnimationClips
    {
        public AnimationClip[,] activateViseme;
        public AnimationClip disableAnimationClip;
        public AnimationClip hudEnableAnimationClip;
        public AnimationClip hudDisableAnimationClip;
    }

    private static AnimationClips MakeAnimationClips()
    {
        AnimationClips clips = new AnimationClips();

        clips.activateViseme = new AnimationClip[COUNT,VISEME_COUNT];

        string speechBubbleContainerPath = "World Constraint";
        string speechBubblePath = $"{speechBubbleContainerPath}/SpeechBubble";

        for (int i = 0; i < COUNT; ++i)
        {
            for (int viseme = 0; viseme < VISEME_COUNT; ++viseme)
            {
                clips.activateViseme[i, viseme] = new AnimationClip();
                clips.activateViseme[i, viseme].name = $"zbub cell {i} viseme {viseme}";
                clips.activateViseme[i, viseme].frameRate = 120.0f;
                // blend shape removes space when on, so value seems backwards
                clips.activateViseme[i, viseme].SetCurve(speechBubblePath, typeof(SkinnedMeshRenderer), $"blendShape.Key {i + 1}", FixedValue((1.0f - VisemeWidths[viseme]) * 100.0f));
                clips.activateViseme[i, viseme].SetCurve(speechBubblePath, typeof(SkinnedMeshRenderer), $"material._cells{i}", FixedValue(viseme));
                // hud material update is separate
                clips.activateViseme[i, viseme].SetCurve("SpeechBubbleHud", typeof(MeshRenderer), $"material._cells{i}", FixedValue(viseme));
                // some animation needs to turn on the whole thing
                if (i == 0 && viseme != 0)
                {
                    clips.activateViseme[i, viseme].SetCurve(speechBubblePath, typeof(GameObject), "m_IsActive", FixedValue(1));
                    // oh you say you can't freeze rotation eh
                    //clips.activateViseme[i, viseme].SetCurve(speechBubbleContainerPath, typeof(Transform), "localEulerAngles.x", FixedValue(0));
                    //clips.activateViseme[i, viseme].SetCurve(speechBubbleContainerPath, typeof(Transform), "localEulerAngles.z", FixedValue(0));
                }
                SaveAnimationClip(clips.activateViseme[i, viseme]);
            }
        }

        clips.disableAnimationClip = new AnimationClip();
        clips.disableAnimationClip.name = "zbub disable";
        clips.disableAnimationClip.SetCurve(speechBubblePath, typeof(GameObject), "m_IsActive", FixedValue(0));
        for (int i = 0; i < COUNT; ++i)
        {
            // blend shape removes space when on, so value seems backwards
            clips.disableAnimationClip.SetCurve(speechBubblePath, typeof(SkinnedMeshRenderer), $"blendShape.Key {i + 1}", FixedValue(100.0f));
            clips.disableAnimationClip.SetCurve(speechBubblePath, typeof(SkinnedMeshRenderer), $"material._cells{i}", FixedValue(0));
            clips.disableAnimationClip.SetCurve("SpeechBubbleHud", typeof(MeshRenderer), $"material._cells{i}", FixedValue(0));
        }
        SaveAnimationClip(clips.disableAnimationClip);

        clips.hudEnableAnimationClip = new AnimationClip();
        clips.hudEnableAnimationClip.name = "zbub hudenable";
        clips.hudEnableAnimationClip.SetCurve("SpeechBubbleHud", typeof(GameObject), "m_IsActive", FixedValue(1));
        SaveAnimationClip(clips.hudEnableAnimationClip);

        clips.hudDisableAnimationClip = new AnimationClip();
        clips.hudDisableAnimationClip.name = "zbub huddisnable";
        clips.hudDisableAnimationClip.SetCurve("SpeechBubbleHud", typeof(GameObject), "m_IsActive", FixedValue(0));
        SaveAnimationClip(clips.hudDisableAnimationClip);

#if NEED_DUMMY_ANIMATION
        AnimationClip dummyAnimationClip = new AnimationClip();
        dummyAnimationClip.name = "zbub empty";
        dummyAnimationClip.SetCurve(speechBubblePath, typeof(GameObject), "m_IsActive", FixedValue(1)); // dummy
        SaveAnimationClip(dummyAnimationClip);
#endif

        return clips;
    }

    private static void RemoveSpeechBubbleAnimations(AnimatorController controller)
    {
        for (int i = controller.layers.Length; --i >= 0; )
        {
            if (controller.layers[i].name.StartsWith("Speech Bubble"))
            {
                Debug.Log($"removing layer #{i} - {controller.layers[i].name}");
                controller.RemoveLayer(i);
            }
        }
    }

    private static void AddSpeechBubbleAnimations(AnimationClips clips, AnimatorController controller)
    {
        EnsureAnimatorParameters(controller);
        //AddSpeechBubbleVisemeAnimations(clips, controller);
        AddTurboSpeechBubbleVisemeAnimations(clips, controller);
        AddSpeechBubbleHudAnimations(clips, controller);
    }

    private static void EnsureAnimatorParameters(AnimatorController controller)
    {
        // Ensure all parameters available
        if (!Array.Exists(controller.parameters, p => p.name == "Viseme"))
            controller.AddParameter("Viseme", AnimatorControllerParameterType.Int);
        if (!Array.Exists(controller.parameters, p => p.name == "SpeechBubbleEnable"))
            controller.AddParameter("SpeechBubbleEnable", AnimatorControllerParameterType.Bool);
        if (!Array.Exists(controller.parameters, p => p.name == "SpeechBubbleHudEnable"))
            controller.AddParameter("SpeechBubbleHudEnable", AnimatorControllerParameterType.Bool);
        if (!Array.Exists(controller.parameters, p => p.name == "IsLocal"))
            controller.AddParameter("IsLocal", AnimatorControllerParameterType.Bool);
    }

    private static void AddSpeechBubbleVisemeAnimations(AnimationClips clips, AnimatorController controller)
    {
        var layer = new AnimatorControllerLayer();
        layer.name = $"Speech Bubble";
        layer.defaultWeight = 1.0f;

        var stateMachine = new AnimatorStateMachine();
        stateMachine.hideFlags = HideFlags.HideInHierarchy;
        AssetDatabase.AddObjectToAsset(stateMachine, controller);
        stateMachine.name = $"Speech Bubble SM";
        stateMachine.entryPosition = new Vector3(0, -50, 0);
        stateMachine.anyStatePosition = new Vector3(0, 10, 0);
        stateMachine.exitPosition = new Vector3(0, 150, 0);

        layer.stateMachine = stateMachine;
        controller.AddLayer(layer);

        // idle is first so it is default
        // idle state: everything invisible/off
        var idleState = stateMachine.AddState("Idle", new Vector3(250, -15 * 50, 0));
        idleState.motion = clips.disableAnimationClip;
        idleState.writeDefaultValues = false;

        // return to idle when disabled
        var stopTransition = stateMachine.AddAnyStateTransition(idleState);
        stopTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.IfNot, 0, "SpeechBubbleEnable");
        stopTransition.duration = 0;

        var prevState = idleState;

        for (int i = 0; i < COUNT; ++i)
        {
            // wait: hold state until timeout (create first because all visemes exit into it)
            var waitState = stateMachine.AddState("Wait", new Vector3(500 * i + 750, 0, 0));
            waitState.writeDefaultValues = false;
            //waitState.motion = dummyAnimationClip;  // note: changes meaning of exitTime below!

            // after time, wait -> idle
            var timeoutTransition = waitState.AddTransition(idleState);
            timeoutTransition.duration = 0;
            timeoutTransition.hasExitTime = true;
            timeoutTransition.exitTime = 2.0f;  // "n copies of the animation" IF THERE IS A .motion CLIP" else SECONDS

            // every viseme needs a separate state
            for (int viseme = 1; viseme < VISEME_COUNT; ++viseme)
            {
                var fullState = stateMachine.AddState($"Viseme {i}:{viseme}", new Vector3(500 * i + 500, 50 * viseme - 7 * 50, 0));
                fullState.motion = clips.activateViseme[i, viseme];
                fullState.writeDefaultValues = false;

                // become full if it's our viseme
                var speechTransition = prevState.AddTransition(fullState);
                speechTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.Equals, viseme, "Viseme");
                if (i == 0)
                {
                    speechTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, "SpeechBubbleEnable");
                }
                speechTransition.duration = 0;

                // wait for viseme to change so we don't repeat
                var changedTransition = fullState.AddTransition(waitState);
                changedTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.NotEqual, viseme, "Viseme");
            }

            prevState = waitState; // chain together
        }
    }

    private static void AddTurboSpeechBubbleVisemeAnimations(AnimationClips clips, AnimatorController controller)
    {
        var layer = new AnimatorControllerLayer();
        layer.name = $"Speech Bubble";
        layer.defaultWeight = 1.0f;

        var stateMachine = new AnimatorStateMachine();
        stateMachine.hideFlags = HideFlags.HideInHierarchy;
        AssetDatabase.AddObjectToAsset(stateMachine, controller);
        stateMachine.name = $"Speech Bubble SM";
        stateMachine.entryPosition = new Vector3(0, -50, 0);
        stateMachine.anyStatePosition = new Vector3(0, 10, 0);
        stateMachine.exitPosition = new Vector3(0, 150, 0);

        layer.stateMachine = stateMachine;
        controller.AddLayer(layer);

        // idle is first so it is default
        // idle state: everything invisible/off
        var idleState = stateMachine.AddState("Idle", new Vector3(250, -15 * 50, 0));
        idleState.motion = clips.disableAnimationClip;
        idleState.writeDefaultValues = false;

        // return to idle when disabled
        var stopTransition = stateMachine.AddAnyStateTransition(idleState);
        stopTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.IfNot, 0, "SpeechBubbleEnable");
        stopTransition.duration = 0;

        AnimatorState[] prevStates = new AnimatorState[1];
        prevStates[0] = idleState;

        for (int i = 0; i < COUNT; ++i)
        {
            // every viseme needs a separate state
            AnimatorState[] newPrevStates = new AnimatorState[VISEME_COUNT - 1];
            for (int viseme = 1; viseme < VISEME_COUNT; ++viseme)
            {
                var fullState = stateMachine.AddState($"Viseme {i}:{viseme}", new Vector3(500 * i + 500, 50 * viseme - 7 * 50, 0));
                fullState.motion = clips.activateViseme[i, viseme];
                fullState.writeDefaultValues = false;

                // after time, wait -> idle
                var timeoutTransition = fullState.AddTransition(idleState);
                timeoutTransition.duration = 0;
                timeoutTransition.hasExitTime = true;
                timeoutTransition.exitTime = 120.0f;  // "n copies of the animation" IF THERE IS A .motion CLIP" else SECONDS

                for (int pred = 0; pred < prevStates.Length; ++pred)
                {
                    if (prevStates.Length > 1)  // not entry state
                    {
                        if (pred + 1 == viseme)  // don't record the same viseme twice in a row
                            continue;
                        if (BlockedVisemeTransitions.Contains(Tuple.Create((Viseme)(pred + 1), (Viseme)viseme)))
                            continue;
                    }
                    var speechTransition = prevStates[pred].AddTransition(fullState);
                    speechTransition.duration = 0;
                    speechTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.Equals, viseme, "Viseme");
                    if (i == 0)
                    {
                        speechTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, "SpeechBubbleEnable");
                    }
                }
                newPrevStates[viseme - 1] = fullState;
            }

            prevStates = newPrevStates; // chain together
        }
    }

    private static void AddSpeechBubbleHudAnimations(AnimationClips clips, AnimatorController controller)
    {
        // separate controller for hud so it can honor IsLocal
        var layer = new AnimatorControllerLayer();
        layer.name = $"Speech Bubble Hud";
        layer.defaultWeight = 1.0f;

        var stateMachine = new AnimatorStateMachine();
        stateMachine.hideFlags = HideFlags.HideInHierarchy;
        AssetDatabase.AddObjectToAsset(stateMachine, controller);
        stateMachine.name = $"Speech Bubble Hud SM";
        stateMachine.entryPosition = new Vector3(0, -50, 0);
        stateMachine.anyStatePosition = new Vector3(0, 10, 0);
        stateMachine.exitPosition = new Vector3(0, 150, 0);

        layer.stateMachine = stateMachine;
        controller.AddLayer(layer);

        var hudIdleState = stateMachine.AddState("Idle", new Vector3(250, 0, 0));
        hudIdleState.motion = clips.hudDisableAnimationClip;
        hudIdleState.writeDefaultValues = false;

        // return to idle when disabled
        var hudStopTransition = stateMachine.AddAnyStateTransition(hudIdleState);
        hudStopTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.IfNot, 0, "SpeechBubbleEnable");
        hudStopTransition.duration = 0;
        var hudStopHudTransition = stateMachine.AddAnyStateTransition(hudIdleState);
        hudStopHudTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.IfNot, 0, "SpeechBubbleHudEnable");
        hudStopHudTransition.duration = 0;

        var hudActiveState = stateMachine.AddState("Active", new Vector3(500, 0, 0));
        hudActiveState.motion = clips.hudEnableAnimationClip;
        hudActiveState.writeDefaultValues = false;

        var showHudTransition = hudIdleState.AddTransition(hudActiveState);
        showHudTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, "SpeechBubbleHudEnable");
        showHudTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, "SpeechBubbleEnable");
        showHudTransition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, "IsLocal");
    }
}
#endif


#if REMEMBER_THIS_CODE
            // side effect: activate next cell
            var nextBehavior = waitState.AddStateMachineBehaviour(typeof(VRCAvatarParameterDriver)) as VRCAvatarParameterDriver;
            nextBehavior.localOnly = false;
            var nextBehaviorParameter = new VRCAvatarParameterDriver.Parameter();
            nextBehaviorParameter.name = "SpeechBubbleIndex";
            nextBehaviorParameter.type = VRCAvatarParameterDriver.ChangeType.Set;
            nextBehaviorParameter.value = (i + 1) % COUNT;
			nextBehavior.parameters.Add(nextBehaviorParameter);
#endif