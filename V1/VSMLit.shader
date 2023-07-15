Shader "VirtualShadowMap/VSMLit"
{
	Properties
	{
		// Specular vs Metallic workflow
		_WorkflowMode("WorkflowMode", Float) = 1.0

		[MainTexture] _BaseMap("Albedo", 2D) = "white" {}
		[MainColor] _BaseColor("Color", Color) = (1,1,1,1)

		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
		_SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

		_Metallic("Metallic", Range(0.0, 1.0)) = 0.0
		_MetallicGlossMap("Metallic", 2D) = "white" {}

		_SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
		_SpecGlossMap("Specular", 2D) = "white" {}

		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		_Parallax("Scale", Range(0.005, 0.08)) = 0.005
		_ParallaxMap("Height Map", 2D) = "black" {}

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}

		[HDR] _EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}

		_DetailMask("Detail Mask", 2D) = "white" {}
		_DetailAlbedoMapScale("Scale", Range(0.0, 2.0)) = 1.0
		_DetailAlbedoMap("Detail Albedo x2", 2D) = "linearGrey" {}
		_DetailNormalMapScale("Scale", Range(0.0, 2.0)) = 1.0
		[Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

		// SRP batching compatibility for Clear Coat (Not used in Lit)
		[HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
		[HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0

			// Blending state
			_Surface("__surface", Float) = 0.0
			_Blend("__blend", Float) = 0.0
			_Cull("__cull", Float) = 2.0
			[ToggleUI] _AlphaClip("__clip", Float) = 0.0
			[HideInInspector] _SrcBlend("__src", Float) = 1.0
			[HideInInspector] _DstBlend("__dst", Float) = 0.0
			[HideInInspector] _ZWrite("__zw", Float) = 1.0

			[ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
			// Editmode props
			_QueueOffset("Queue offset", Float) = 0.0

			// ObsoleteProperties
			[HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
			[HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)
			[HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
			[HideInInspector] _Glossiness("Smoothness", Float) = 0.0
			[HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0

			[HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
			[HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
			[HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
	}

		SubShader
	{
		// Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
		// this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
		// material work with both Universal Render Pipeline and Builtin Unity Pipeline
		Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "4.5"}
		LOD 300

		// ------------------------------------------------------------------
		//  Forward pass. Shades all light in a single pass. GI + emission + Fog
		Pass
		{
			// Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
			// no LightMode tag are also rendered by Universal Render Pipeline
			Name "ForwardLit"
			Tags{"LightMode" = "UniversalForward"}

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local _NORMALMAP
		#pragma shader_feature_local _PARALLAXMAP
		#pragma shader_feature_local _RECEIVE_SHADOWS_OFF
		#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
		#pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
		#pragma shader_feature_local_fragment _EMISSION
		#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
		#pragma shader_feature_local_fragment _OCCLUSIONMAP
		#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
		#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
		#pragma shader_feature_local_fragment _SPECULAR_SETUP

		// -------------------------------------
		// Universal Pipeline keywords
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
		#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
		#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
		#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
		#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
		#pragma multi_compile_fragment _ _SHADOWS_SOFT
		#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
		#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
		#pragma multi_compile_fragment _ _LIGHT_LAYERS
		#pragma multi_compile_fragment _ _LIGHT_COOKIES
		#pragma multi_compile _ _CLUSTERED_RENDERING

		// -------------------------------------
		// Unity defined keywords
		#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
		#pragma multi_compile _ SHADOWS_SHADOWMASK
		#pragma multi_compile _ DIRLIGHTMAP_COMBINED
		#pragma multi_compile _ LIGHTMAP_ON
		#pragma multi_compile _ DYNAMICLIGHTMAP_ON
		#pragma multi_compile_fog
		#pragma multi_compile_fragment _ DEBUG_DISPLAY

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing
		#pragma instancing_options renderinglayer
		#pragma multi_compile _ DOTS_INSTANCING_ON

		#pragma vertex LitPassVertex
		#pragma fragment LitPassFragmentVsm

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
		#include "VsmCommon.hlsl"
		ENDHLSL
	}

	Pass
	{
		Name "ShadowCaster"
		Tags{"LightMode" = "ShadowCaster"}

		ZWrite On
		ZTest LEqual
		ColorMask 0
		Cull[_Cull]

		HLSLPROGRAM
		#pragma exclude_renderers gles gles3 glcore
		#pragma target 4.5

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing
		#pragma multi_compile _ DOTS_INSTANCING_ON

		// -------------------------------------
		// Universal Pipeline keywords

		// This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
		#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

		#pragma vertex ShadowPassVertex
		#pragma fragment ShadowPassFragment

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
		ENDHLSL
	}

	Pass
	{
		Name "VSMDepth"
		Tags
		{
			"LightMode" = "VSMDepth"
		}

		ZTest LEqual
		ZWrite On
		Cull off
		ColorMask 0

		HLSLPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		// make fog work
		#pragma multi_compile_fog
		#pragma target 4.5

		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "../Resources/VirtualShadowMapAccess.hlsl"
		//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
		//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

		struct Attributes
		{
			float4 positionOS : POSITION;
		};

		struct Varings
		{
			float4 Position : SV_POSITION;
			float3 PositionWS : TEXCOORD0;
		};

		RWTexture2D<uint> _PhysicalPageDepth : register(u1);

		//StructuredBuffer<ClipmapData> _ClipmapData;
		int _ClipmapIndex;
		int _PageDim;
		StructuredBuffer<uint> _PhysicalPageAlloc;
		StructuredBuffer<uint> _Pages;
		int _PageSize;

		float4x4 _WorldToShadow;

		//int _ScreenWidth;
		//int _ScreenHeight;

		uint GetPhysicalPageAddress(float3 shadowUVz, out uint2 pageLocalAddress, out float shadowDepth)
		{
			if (any(shadowUVz.xy < 0.0f) || any(shadowUVz.xy >= 1.0f))
			{
				return -1;
			}
			shadowDepth = shadowUVz.z;
			float2 pageAddressFloat = shadowUVz.xy * float2(_PageDim, _PageDim);
			uint2 pageAddress = clamp(uint2(pageAddressFloat), 0, _PageDim);
			uint pageIndex = PageAddressToIndex(pageAddress, _PageDim, _ClipmapIndex);
			pageLocalAddress = shadowUVz.xy * _PageDim * _PageSize - pageAddress * _PageSize;
			if (any(pageLocalAddress >= _PageSize))
				return -1;
			return _PhysicalPageAlloc[pageIndex];
		}

		Varings vert(Attributes IN)
		{
			Varings OUT;
			VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
			OUT.Position = positionInputs.positionCS;
			OUT.PositionWS = positionInputs.positionWS.xyz;
#if defined(UNITY_REVERSED_Z)
			OUT.Position.z = 1.0f - OUT.Position.z;
#endif
			return OUT;
		}

		[earlydepthstencil]
		float4 frag(Varings IN) :SV_Target
		{
#if 1
			float vsmResolution = _PageDim * _PageSize;
			float2 uv = IN.Position.xy / float2(vsmResolution, vsmResolution);
			float depth = IN.Position.z;
			float3 shadowUVz = float3(uv, depth);
			uint2 pageLocalAddress = uint2(0, 0);
			float shadowDepth = 0.0f;
			uint physicalPageIndex = GetPhysicalPageAddress(shadowUVz, pageLocalAddress, shadowDepth);

			if (physicalPageIndex != -1)
			{
				float4 shadowNdc = mul(_WorldToShadow, float4(IN.PositionWS.xyz, 1));
				
				uint physicalPage = _Pages[physicalPageIndex];
				uint physicalPagePixelOffsetU = physicalPage >> 16;
				uint physicalPagePixelOffsetV = physicalPage & 0xFFFF;
				uint2 physicalOffset = uint2(physicalPagePixelOffsetU, physicalPagePixelOffsetV);
				uint2 physicalAddress = physicalOffset + pageLocalAddress;
				InterlockedMax(_PhysicalPageDepth[physicalAddress], asuint(shadowNdc.z));
			}
#endif
			return float4(1, 0, 0, 1);
		}
		ENDHLSL
	}

	Pass
	{
			// Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
			// no LightMode tag are also rendered by Universal Render Pipeline
			Name "GBuffer"
			Tags{"LightMode" = "UniversalGBuffer"}

			ZWrite[_ZWrite]
			ZTest LEqual
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local _NORMALMAP
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		//#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
		#pragma shader_feature_local_fragment _EMISSION
		#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
		#pragma shader_feature_local_fragment _OCCLUSIONMAP
		#pragma shader_feature_local _PARALLAXMAP
		#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

		#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
		#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
		#pragma shader_feature_local_fragment _SPECULAR_SETUP
		#pragma shader_feature_local _RECEIVE_SHADOWS_OFF

		// -------------------------------------
		// Universal Pipeline keywords
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
		//#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
		//#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
		#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
		#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
		#pragma multi_compile_fragment _ _SHADOWS_SOFT
		#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
		#pragma multi_compile_fragment _ _LIGHT_LAYERS
		#pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

		// -------------------------------------
		// Unity defined keywords
		#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
		#pragma multi_compile _ SHADOWS_SHADOWMASK
		#pragma multi_compile _ DIRLIGHTMAP_COMBINED
		#pragma multi_compile _ LIGHTMAP_ON
		#pragma multi_compile _ DYNAMICLIGHTMAP_ON
		#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing
		#pragma instancing_options renderinglayer
		#pragma multi_compile _ DOTS_INSTANCING_ON

		#pragma vertex LitGBufferPassVertex
		#pragma fragment LitGBufferPassFragment

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
		ENDHLSL
	}

	Pass
	{
		Name "DepthOnly"
		Tags{"LightMode" = "DepthOnly"}

		ZWrite On
		ColorMask 0
		Cull[_Cull]

		HLSLPROGRAM
		#pragma exclude_renderers gles gles3 glcore
		#pragma target 4.5

		#pragma vertex DepthOnlyVertex
		#pragma fragment DepthOnlyFragment

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing
		#pragma multi_compile _ DOTS_INSTANCING_ON

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
		ENDHLSL
	}

		// This pass is used when drawing to a _CameraNormalsTexture texture
		Pass
		{
			Name "DepthNormals"
			Tags{"LightMode" = "DepthNormals"}

			ZWrite On
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local _NORMALMAP
		#pragma shader_feature_local _PARALLAXMAP
		#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing
		#pragma multi_compile _ DOTS_INSTANCING_ON

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
		ENDHLSL
	}

		// This pass it not used during regular rendering, only for lightmap baking.
		Pass
		{
			Name "Meta"
			Tags{"LightMode" = "Meta"}

			Cull Off

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex UniversalVertexMeta
			#pragma fragment UniversalFragmentMetaLit

			#pragma shader_feature EDITOR_VISUALIZATION
			#pragma shader_feature_local_fragment _SPECULAR_SETUP
			#pragma shader_feature_local_fragment _EMISSION
			#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

			#pragma shader_feature_local_fragment _SPECGLOSSMAP

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

			ENDHLSL
		}

		Pass
		{
			Name "Universal2D"
			Tags{ "LightMode" = "Universal2D" }

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Universal2D.hlsl"
			ENDHLSL
		}
	}

		SubShader
	{
		// Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
		// this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
		// material work with both Universal Render Pipeline and Builtin Unity Pipeline
		Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "2.0"}
		LOD 300

		// ------------------------------------------------------------------
		//  Forward pass. Shades all light in a single pass. GI + emission + Fog
		Pass
		{
			// Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
			// no LightMode tag are also rendered by Universal Render Pipeline
			Name "ForwardLit"
			Tags{"LightMode" = "UniversalForward"}

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			#pragma only_renderers gles gles3 glcore d3d11
			#pragma target 2.0

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing
		#pragma instancing_options renderinglayer

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local _NORMALMAP
		#pragma shader_feature_local _PARALLAXMAP
		#pragma shader_feature_local _RECEIVE_SHADOWS_OFF
		#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
		#pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
		#pragma shader_feature_local_fragment _EMISSION
		#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
		#pragma shader_feature_local_fragment _OCCLUSIONMAP
		#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
		#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
		#pragma shader_feature_local_fragment _SPECULAR_SETUP

		// -------------------------------------
		// Universal Pipeline keywords
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
		#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
		#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
		#pragma multi_compile_fragment _ _SHADOWS_SOFT
		#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
		#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
		#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
		#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
		#pragma multi_compile_fragment _ _LIGHT_LAYERS
		#pragma multi_compile_fragment _ _LIGHT_COOKIES
		#pragma multi_compile _ _CLUSTERED_RENDERING

		// -------------------------------------
		// Unity defined keywords
		#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
		#pragma multi_compile _ SHADOWS_SHADOWMASK
		#pragma multi_compile _ DIRLIGHTMAP_COMBINED
		#pragma multi_compile _ LIGHTMAP_ON
		#pragma multi_compile_fog
		#pragma multi_compile_fragment _ DEBUG_DISPLAY

		#pragma vertex LitPassVertex
		#pragma fragment LitPassFragment

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
		ENDHLSL
	}

	Pass
	{
		Name "ShadowCaster"
		Tags{"LightMode" = "ShadowCaster"}

		ZWrite On
		ZTest LEqual
		ColorMask 0
		Cull[_Cull]

		HLSLPROGRAM
		#pragma only_renderers gles gles3 glcore d3d11
		#pragma target 2.0

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

		// -------------------------------------
		// Universal Pipeline keywords

		// This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
		#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

		#pragma vertex ShadowPassVertex
		#pragma fragment ShadowPassFragment

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
		ENDHLSL
	}

	Pass
	{
		Name "VSMDepth"
		Tags
		{
			"LightMode" = "VSMDepth"
		}

		ZTest On
		ZWrite On

		HLSLPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		// make fog work
		#pragma multi_compile_fog

		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
		//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

		struct Attributes
		{
			float4 positionOS : POSITION;
		};

		struct Varings
		{
			float4 Position : SV_POSITION;
		};

		float4x4 _ViewMat;
		float4x4 _ProjMat;

		Varings vert(Attributes IN)
		{
			Varings OUT;
			VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
			OUT.Position = positionInputs.positionCS;
			//OUT.Position = mul(UNITY_MATRIX_VP, float4(IN.positionOS.xyz, 1));
			float4 worldPos = mul(unity_ObjectToWorld, float4(IN.positionOS.xyz, 1));
			float4 viewPos = mul(_ViewMat, float4(worldPos.xyz, 1));
			float4 ndcPos = mul(_ProjMat, viewPos);
			OUT.Position = ndcPos;
			return OUT;
		}

		float4 frag(Varings IN) :SV_Target
		{
			return float4(1, 0, 0, 1);
		}
		ENDHLSL
	}

	Pass
	{
		Name "DepthOnly"
		Tags{"LightMode" = "DepthOnly"}

		ZWrite On
		ColorMask 0
		Cull[_Cull]

		HLSLPROGRAM
		#pragma only_renderers gles gles3 glcore d3d11
		#pragma target 2.0

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing

		#pragma vertex DepthOnlyVertex
		#pragma fragment DepthOnlyFragment

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
		ENDHLSL
	}

		// This pass is used when drawing to a _CameraNormalsTexture texture
		Pass
		{
			Name "DepthNormals"
			Tags{"LightMode" = "DepthNormals"}

			ZWrite On
			Cull[_Cull]

			HLSLPROGRAM
			#pragma only_renderers gles gles3 glcore d3d11
			#pragma target 2.0

			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

		// -------------------------------------
		// Material Keywords
		#pragma shader_feature_local _NORMALMAP
		#pragma shader_feature_local _PARALLAXMAP
		#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
		#pragma shader_feature_local_fragment _ALPHATEST_ON
		#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing

		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
		ENDHLSL
	}

		// This pass it not used during regular rendering, only for lightmap baking.
		Pass
		{
			Name "Meta"
			Tags{"LightMode" = "Meta"}

			Cull Off

			HLSLPROGRAM
			#pragma only_renderers gles gles3 glcore d3d11
			#pragma target 2.0

			#pragma vertex UniversalVertexMeta
			#pragma fragment UniversalFragmentMetaLit

			#pragma shader_feature EDITOR_VISUALIZATION
			#pragma shader_feature_local_fragment _SPECULAR_SETUP
			#pragma shader_feature_local_fragment _EMISSION
			#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

			#pragma shader_feature_local_fragment _SPECGLOSSMAP

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

			ENDHLSL
		}
		Pass
		{
			Name "Universal2D"
			Tags{ "LightMode" = "Universal2D" }

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			#pragma only_renderers gles gles3 glcore d3d11
			#pragma target 2.0

			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Universal2D.hlsl"
			ENDHLSL
		}
	}

	FallBack "Hidden/Universal Render Pipeline/FallbackError"
	CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
}
