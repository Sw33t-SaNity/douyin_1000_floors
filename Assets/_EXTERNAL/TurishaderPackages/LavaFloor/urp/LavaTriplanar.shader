// Made with Amplify Shader Editor v1.9.8.1
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "UMS/LavaTriplanar"
{
	Properties
	{
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)
		_OverallScale("OverallScale", Float) = 1
		_TurbulenceSpeed("TurbulenceSpeed", Float) = 0.1
		_ScrollSpeed("ScrollSpeed", Vector) = (0,0,0,0)
		[HDR][Header(Lava)]_LavaColor("LavaColor", Color) = (47.93726,1.209737,0,0)
		_Lavasmoothness("Lava smoothness", Range( 0 , 1)) = 0
		_LavaParallaxDepth("LavaParallaxDepth", Float) = 1
		_LavaLevel("LavaLevel", Range( 0 , 1)) = 0.085
		[Header(Crust)]_CrustLevel("CrustLevel", Range( 0 , 1)) = 0.2
		_CrustFadeDistance("CrustFadeDistance", Float) = 0
		[HDR]_CrustColor("CrustColor", Color) = (0.0472623,0.03809185,0.0754717,0)
		_Crustsmoothness("Crust smoothness", Range( 0 , 1)) = 0.4
		[Header(Vertex wave)]_Lavawaveoffset("Lava wave offset", Float) = 0
		_Lavawavetiling("Lava wave tiling", Float) = 0
		_Wavescrollspeed("Wave scroll speed", Vector) = (0,0,0,0)


		//_TransmissionShadow( "Transmission Shadow", Range( 0, 1 ) ) = 0.5
		//_TransStrength( "Trans Strength", Range( 0, 50 ) ) = 1
		//_TransNormal( "Trans Normal Distortion", Range( 0, 1 ) ) = 0.5
		//_TransScattering( "Trans Scattering", Range( 1, 50 ) ) = 2
		//_TransDirect( "Trans Direct", Range( 0, 1 ) ) = 0.9
		//_TransAmbient( "Trans Ambient", Range( 0, 1 ) ) = 0.1
		//_TransShadow( "Trans Shadow", Range( 0, 1 ) ) = 0.5
		//_TessPhongStrength( "Tess Phong Strength", Range( 0, 1 ) ) = 0.5
		//_TessValue( "Tess Max Tessellation", Range( 1, 32 ) ) = 16
		//_TessMin( "Tess Min Distance", Float ) = 10
		//_TessMax( "Tess Max Distance", Float ) = 25
		//_TessEdgeLength ( "Tess Edge length", Range( 2, 50 ) ) = 16
		//_TessMaxDisp( "Tess Max Displacement", Float ) = 25

		[HideInInspector][ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1
		[HideInInspector][ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1
		[HideInInspector][ToggleOff] _ReceiveShadows("Receive Shadows", Float) = 1.0

		[HideInInspector] _QueueOffset("_QueueOffset", Float) = 0
        [HideInInspector] _QueueControl("_QueueControl", Float) = -1

        [HideInInspector][NoScaleOffset] unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
	}

	SubShader
	{
		LOD 0

		

		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "UniversalMaterialType"="Lit" }

		Cull Back
		ZWrite Off
		ZTest LEqual
		Offset 0 , 0
		AlphaToMask Off

		

		HLSLINCLUDE
		#pragma target 4.5
		#pragma prefer_hlslcc gles
		// ensure rendering platforms toggle list is visible

		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

		#ifndef ASE_TESS_FUNCS
		#define ASE_TESS_FUNCS
		float4 FixedTess( float tessValue )
		{
			return tessValue;
		}

		float CalcDistanceTessFactor (float4 vertex, float minDist, float maxDist, float tess, float4x4 o2w, float3 cameraPos )
		{
			float3 wpos = mul(o2w,vertex).xyz;
			float dist = distance (wpos, cameraPos);
			float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
			return f;
		}

		float4 CalcTriEdgeTessFactors (float3 triVertexFactors)
		{
			float4 tess;
			tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
			tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
			tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
			tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
			return tess;
		}

		float CalcEdgeTessFactor (float3 wpos0, float3 wpos1, float edgeLen, float3 cameraPos, float4 scParams )
		{
			float dist = distance (0.5 * (wpos0+wpos1), cameraPos);
			float len = distance(wpos0, wpos1);
			float f = max(len * scParams.y / (edgeLen * dist), 1.0);
			return f;
		}

		float DistanceFromPlane (float3 pos, float4 plane)
		{
			float d = dot (float4(pos,1.0f), plane);
			return d;
		}

		bool WorldViewFrustumCull (float3 wpos0, float3 wpos1, float3 wpos2, float cullEps, float4 planes[6] )
		{
			float4 planeTest;
			planeTest.x = (( DistanceFromPlane(wpos0, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[0]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.y = (( DistanceFromPlane(wpos0, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[1]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.z = (( DistanceFromPlane(wpos0, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[2]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.w = (( DistanceFromPlane(wpos0, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[3]) > -cullEps) ? 1.0f : 0.0f );
			return !all (planeTest);
		}

		float4 DistanceBasedTess( float4 v0, float4 v1, float4 v2, float tess, float minDist, float maxDist, float4x4 o2w, float3 cameraPos )
		{
			float3 f;
			f.x = CalcDistanceTessFactor (v0,minDist,maxDist,tess,o2w,cameraPos);
			f.y = CalcDistanceTessFactor (v1,minDist,maxDist,tess,o2w,cameraPos);
			f.z = CalcDistanceTessFactor (v2,minDist,maxDist,tess,o2w,cameraPos);

			return CalcTriEdgeTessFactors (f);
		}

		float4 EdgeLengthBasedTess( float4 v0, float4 v1, float4 v2, float edgeLength, float4x4 o2w, float3 cameraPos, float4 scParams )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;
			tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
			tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
			tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
			tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			return tess;
		}

		float4 EdgeLengthBasedTessCull( float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement, float4x4 o2w, float3 cameraPos, float4 scParams, float4 planes[6] )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;

			if (WorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement, planes))
			{
				tess = 0.0f;
			}
			else
			{
				tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
				tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
				tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
				tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			}
			return tess;
		}
		#endif //ASE_TESS_FUNCS
		ENDHLSL

		
		Pass
		{
			
			Name "Forward"
			Tags { "LightMode"="UniversalForward" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite On
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

			

			HLSLPROGRAM

			
            #pragma multi_compile_fragment _ALPHATEST_ON
            #define _NORMAL_DROPOFF_TS 1
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma instancing_options renderinglayer
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011
            #define REQUIRE_DEPTH_TEXTURE 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

			

			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

			
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
           

			

			#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
			#pragma multi_compile _ _LIGHT_LAYERS
			#pragma multi_compile_fragment _ _LIGHT_COOKIES
			#pragma multi_compile _ _FORWARD_PLUS

			
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
		

			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ SHADOWS_SHADOWMASK
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DYNAMICLIGHTMAP_ON

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_FORWARD

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
				#define ENABLE_TERRAIN_PERPIXEL_NORMAL
			#endif

			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#define ASE_NEEDS_FRAG_SCREEN_POSITION
			#define ASE_NEEDS_FRAG_WORLD_TANGENT
			#define ASE_NEEDS_FRAG_WORLD_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_BITANGENT
			#pragma multi_compile_instancing


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				float4 lightmapUVOrVertexSH : TEXCOORD1;
				#if defined(ASE_FOG) || defined(_ADDITIONAL_LIGHTS_VERTEX)
					half4 fogFactorAndVertexLight : TEXCOORD2;
				#endif
				float4 tSpace0 : TEXCOORD3;
				float4 tSpace1 : TEXCOORD4;
				float4 tSpace2 : TEXCOORD5;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					float4 shadowCoord : TEXCOORD6;
				#endif
				#if defined(DYNAMICLIGHTMAP_ON)
					float2 dynamicLightmapUV : TEXCOORD7;
				#endif
				float4 ase_texcoord8 : TEXCOORD8;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
				UNITY_DEFINE_INSTANCED_PROP(float4, _CrustColor)
				UNITY_DEFINE_INSTANCED_PROP(float4, _LavaColor)
				UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash47_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			inline float2 ParallaxOffset( half h, half height, half3 viewDir )
			{
				h = h * height - height/2.0;
				float3 v = normalize( viewDir );
				v.z += 0.42;
				return h* (v.xy / v.z);
			}
			
					float2 voronoihash47_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash47_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash18_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
			float3 PerturbNormal107_g55( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			
					float2 voronoihash18_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
			float3 PerturbNormal107_g60( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			
					float2 voronoihash18_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
			float3 PerturbNormal107_g65( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				output.ase_texcoord8.xy = input.texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord8.zw = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif
				input.normalOS = input.normalOS;
				input.tangentOS = input.tangentOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );
				VertexNormalInputs normalInput = GetVertexNormalInputs( input.normalOS, input.tangentOS );

				output.tSpace0 = float4( normalInput.normalWS, vertexInput.positionWS.x );
				output.tSpace1 = float4( normalInput.tangentWS, vertexInput.positionWS.y );
				output.tSpace2 = float4( normalInput.bitangentWS, vertexInput.positionWS.z );

				#if defined(LIGHTMAP_ON)
					OUTPUT_LIGHTMAP_UV(input.texcoord1, unity_LightmapST, output.lightmapUVOrVertexSH.xy);
				#else
					OUTPUT_SH(normalInput.normalWS.xyz, output.lightmapUVOrVertexSH.xyz);
				#endif
				#if defined(DYNAMICLIGHTMAP_ON)
					output.dynamicLightmapUV.xy = input.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				#endif

				#if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					output.lightmapUVOrVertexSH.zw = input.texcoord.xy;
					output.lightmapUVOrVertexSH.xy = input.texcoord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif

				#if defined(ASE_FOG) || defined(_ADDITIONAL_LIGHTS_VERTEX)
					output.fogFactorAndVertexLight = 0;
					#if defined(ASE_FOG) && !defined(_FOG_FRAGMENT)
						output.fogFactorAndVertexLight.x = ComputeFogFactor(vertexInput.positionCS.z);
					#endif
					#ifdef _ADDITIONAL_LIGHTS_VERTEX
						half3 vertexLight = VertexLighting( vertexInput.positionWS, normalInput.normalWS );
						output.fogFactorAndVertexLight.yzw = vertexLight;
					#endif
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				output.positionCS = vertexInput.positionCS;
				output.clipPosV = vertexInput.positionCS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				output.tangentOS = input.tangentOS;
				output.texcoord = input.texcoord;
				output.texcoord1 = input.texcoord1;
				output.texcoord2 = input.texcoord2;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				output.tangentOS = patch[0].tangentOS * bary.x + patch[1].tangentOS * bary.y + patch[2].tangentOS * bary.z;
				output.texcoord = patch[0].texcoord * bary.x + patch[1].texcoord * bary.y + patch[2].texcoord * bary.z;
				output.texcoord1 = patch[0].texcoord1 * bary.x + patch[1].texcoord1 * bary.y + patch[2].texcoord1 * bary.z;
				output.texcoord2 = patch[0].texcoord2 * bary.x + patch[1].texcoord2 * bary.y + patch[2].texcoord2 * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag ( PackedVaryings input
						#ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						#ifdef _WRITE_RENDERING_LAYERS
						, out float4 outRenderingLayers : SV_Target1
						#endif
						 ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float2 sampleCoords = (input.lightmapUVOrVertexSH.zw / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
					float3 WorldNormal = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
					float3 WorldTangent = -cross(GetObjectToWorldMatrix()._13_23_33, WorldNormal);
					float3 WorldBiTangent = cross(WorldNormal, -WorldTangent);
				#else
					float3 WorldNormal = normalize( input.tSpace0.xyz );
					float3 WorldTangent = input.tSpace1.xyz;
					float3 WorldBiTangent = input.tSpace2.xyz;
				#endif

				float3 WorldPosition = float3(input.tSpace0.w,input.tSpace1.w,input.tSpace2.w);
				float3 WorldViewDirection = GetWorldSpaceNormalizeViewDir( WorldPosition );
				float4 ShadowCoords = float4( 0, 0, 0, 0 );
				float4 ClipPos = input.clipPosV;
				float4 ScreenPos = ComputeScreenPos( input.clipPosV );

				float2 NormalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					ShadowCoords = input.shadowCoord;
				#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
				#endif

				float4 _CrustColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_CrustColor);
				float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_TurbulenceSpeed);
				float mulTime3_g51 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g51 = mulTime3_g51;
				float2 voronoiSmoothId47_g51 = 0;
				float3 break154 = ( WorldPosition * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner53_g51 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g51);
				float2 panner1_g53 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g51);
				float temp_output_13_0_g53 = 2.0;
				float simplePerlin2D7_g53 = snoise( ( panner1_g53 + float2( 0.01,0 ) )*temp_output_13_0_g53 );
				simplePerlin2D7_g53 = simplePerlin2D7_g53*0.5 + 0.5;
				float simplePerlin2D2_g53 = snoise( panner1_g53*temp_output_13_0_g53 );
				simplePerlin2D2_g53 = simplePerlin2D2_g53*0.5 + 0.5;
				float simplePerlin2D8_g53 = snoise( ( panner1_g53 + float2( 0,0.01 ) )*temp_output_13_0_g53 );
				simplePerlin2D8_g53 = simplePerlin2D8_g53*0.5 + 0.5;
				float4 appendResult9_g53 = (float4(( simplePerlin2D7_g53 - simplePerlin2D2_g53 ) , ( simplePerlin2D8_g53 - simplePerlin2D2_g53 ) , 0.0 , 0.0));
				float2 coords47_g51 = ( ( appendResult9_g53 * 2.0 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g51 = 0;
				float2 uv47_g51 = 0;
				float fade47_g51 = 0.5;
				float voroi47_g51 = 0;
				float rest47_g51 = 0;
				for( int it47_g51 = 0; it47_g51 <2; it47_g51++ ){
				voroi47_g51 += fade47_g51 * voronoi47_g51( coords47_g51, time47_g51, id47_g51, uv47_g51, 0,voronoiSmoothId47_g51 );
				rest47_g51 += fade47_g51;
				coords47_g51 *= 2;
				fade47_g51 *= 0.5;
				}//Voronoi47_g51
				voroi47_g51 /= rest47_g51;
				float4 ase_positionSSNorm = ScreenPos / ScreenPos.w;
				ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
				float screenDepth50_g51 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g51 = saturate( abs( ( screenDepth50_g51 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g51 = lerp( 1.0 , voroi47_g51 , pow( distanceDepth50_g51 , 0.1 ));
				float smoothstepResult44_g51 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g51);
				float CrustLevel45_g51 = saturate( smoothstepResult44_g51 );
				float4 _LavaColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_LavaColor);
				float time39_g51 = _TimeParameters.x;
				float2 voronoiSmoothId39_g51 = 0;
				float3 tanToWorld0 = float3( WorldTangent.x, WorldBiTangent.x, WorldNormal.x );
				float3 tanToWorld1 = float3( WorldTangent.y, WorldBiTangent.y, WorldNormal.y );
				float3 tanToWorld2 = float3( WorldTangent.z, WorldBiTangent.z, WorldNormal.z );
				float3 ase_viewVectorTS =  tanToWorld0 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).x + tanToWorld1 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).y  + tanToWorld2 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).z;
				float3 ase_viewDirTS = normalize( ase_viewVectorTS );
				float2 paralaxOffset34_g51 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g51 = ( panner53_g51 + paralaxOffset34_g51 );
				float2 panner1_g54 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g51);
				float temp_output_13_0_g54 = 2.0;
				float simplePerlin2D7_g54 = snoise( ( panner1_g54 + float2( 0.01,0 ) )*temp_output_13_0_g54 );
				simplePerlin2D7_g54 = simplePerlin2D7_g54*0.5 + 0.5;
				float simplePerlin2D2_g54 = snoise( panner1_g54*temp_output_13_0_g54 );
				simplePerlin2D2_g54 = simplePerlin2D2_g54*0.5 + 0.5;
				float simplePerlin2D8_g54 = snoise( ( panner1_g54 + float2( 0,0.01 ) )*temp_output_13_0_g54 );
				simplePerlin2D8_g54 = simplePerlin2D8_g54*0.5 + 0.5;
				float4 appendResult9_g54 = (float4(( simplePerlin2D7_g54 - simplePerlin2D2_g54 ) , ( simplePerlin2D8_g54 - simplePerlin2D2_g54 ) , 0.0 , 0.0));
				float2 coords39_g51 = ( ( appendResult9_g54 * 4.0 ) + float4( temp_output_54_0_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g51 = 0;
				float2 uv39_g51 = 0;
				float fade39_g51 = 0.5;
				float voroi39_g51 = 0;
				float rest39_g51 = 0;
				for( int it39_g51 = 0; it39_g51 <5; it39_g51++ ){
				voroi39_g51 += fade39_g51 * voronoi39_g51( coords39_g51, time39_g51, id39_g51, uv39_g51, 0,voronoiSmoothId39_g51 );
				rest39_g51 += fade39_g51;
				coords39_g51 *= 2;
				fade39_g51 *= 0.5;
				}//Voronoi39_g51
				voroi39_g51 /= rest39_g51;
				float4 lerpResult10_g51 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g51 ) * (0.5 + (pow( saturate( ( voroi47_g51 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g51 ) , CrustLevel45_g51);
				float dotResult113 = dot( WorldNormal , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float mulTime3_g56 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g56 = mulTime3_g56;
				float2 voronoiSmoothId47_g56 = 0;
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner53_g56 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g56);
				float2 panner1_g58 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g56);
				float temp_output_13_0_g58 = 2.0;
				float simplePerlin2D7_g58 = snoise( ( panner1_g58 + float2( 0.01,0 ) )*temp_output_13_0_g58 );
				simplePerlin2D7_g58 = simplePerlin2D7_g58*0.5 + 0.5;
				float simplePerlin2D2_g58 = snoise( panner1_g58*temp_output_13_0_g58 );
				simplePerlin2D2_g58 = simplePerlin2D2_g58*0.5 + 0.5;
				float simplePerlin2D8_g58 = snoise( ( panner1_g58 + float2( 0,0.01 ) )*temp_output_13_0_g58 );
				simplePerlin2D8_g58 = simplePerlin2D8_g58*0.5 + 0.5;
				float4 appendResult9_g58 = (float4(( simplePerlin2D7_g58 - simplePerlin2D2_g58 ) , ( simplePerlin2D8_g58 - simplePerlin2D2_g58 ) , 0.0 , 0.0));
				float2 coords47_g56 = ( ( appendResult9_g58 * 2.0 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g56 = 0;
				float2 uv47_g56 = 0;
				float fade47_g56 = 0.5;
				float voroi47_g56 = 0;
				float rest47_g56 = 0;
				for( int it47_g56 = 0; it47_g56 <2; it47_g56++ ){
				voroi47_g56 += fade47_g56 * voronoi47_g56( coords47_g56, time47_g56, id47_g56, uv47_g56, 0,voronoiSmoothId47_g56 );
				rest47_g56 += fade47_g56;
				coords47_g56 *= 2;
				fade47_g56 *= 0.5;
				}//Voronoi47_g56
				voroi47_g56 /= rest47_g56;
				float screenDepth50_g56 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g56 = saturate( abs( ( screenDepth50_g56 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g56 = lerp( 1.0 , voroi47_g56 , pow( distanceDepth50_g56 , 0.1 ));
				float smoothstepResult44_g56 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g56);
				float CrustLevel45_g56 = saturate( smoothstepResult44_g56 );
				float time39_g56 = _TimeParameters.x;
				float2 voronoiSmoothId39_g56 = 0;
				float2 paralaxOffset34_g56 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g56 = ( panner53_g56 + paralaxOffset34_g56 );
				float2 panner1_g59 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g56);
				float temp_output_13_0_g59 = 2.0;
				float simplePerlin2D7_g59 = snoise( ( panner1_g59 + float2( 0.01,0 ) )*temp_output_13_0_g59 );
				simplePerlin2D7_g59 = simplePerlin2D7_g59*0.5 + 0.5;
				float simplePerlin2D2_g59 = snoise( panner1_g59*temp_output_13_0_g59 );
				simplePerlin2D2_g59 = simplePerlin2D2_g59*0.5 + 0.5;
				float simplePerlin2D8_g59 = snoise( ( panner1_g59 + float2( 0,0.01 ) )*temp_output_13_0_g59 );
				simplePerlin2D8_g59 = simplePerlin2D8_g59*0.5 + 0.5;
				float4 appendResult9_g59 = (float4(( simplePerlin2D7_g59 - simplePerlin2D2_g59 ) , ( simplePerlin2D8_g59 - simplePerlin2D2_g59 ) , 0.0 , 0.0));
				float2 coords39_g56 = ( ( appendResult9_g59 * 4.0 ) + float4( temp_output_54_0_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g56 = 0;
				float2 uv39_g56 = 0;
				float fade39_g56 = 0.5;
				float voroi39_g56 = 0;
				float rest39_g56 = 0;
				for( int it39_g56 = 0; it39_g56 <5; it39_g56++ ){
				voroi39_g56 += fade39_g56 * voronoi39_g56( coords39_g56, time39_g56, id39_g56, uv39_g56, 0,voronoiSmoothId39_g56 );
				rest39_g56 += fade39_g56;
				coords39_g56 *= 2;
				fade39_g56 *= 0.5;
				}//Voronoi39_g56
				voroi39_g56 /= rest39_g56;
				float4 lerpResult10_g56 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g56 ) * (0.5 + (pow( saturate( ( voroi47_g56 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g56 ) , CrustLevel45_g56);
				float dotResult119 = dot( WorldNormal , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float mulTime3_g61 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g61 = mulTime3_g61;
				float2 voronoiSmoothId47_g61 = 0;
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner53_g61 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g61);
				float2 panner1_g63 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g61);
				float temp_output_13_0_g63 = 2.0;
				float simplePerlin2D7_g63 = snoise( ( panner1_g63 + float2( 0.01,0 ) )*temp_output_13_0_g63 );
				simplePerlin2D7_g63 = simplePerlin2D7_g63*0.5 + 0.5;
				float simplePerlin2D2_g63 = snoise( panner1_g63*temp_output_13_0_g63 );
				simplePerlin2D2_g63 = simplePerlin2D2_g63*0.5 + 0.5;
				float simplePerlin2D8_g63 = snoise( ( panner1_g63 + float2( 0,0.01 ) )*temp_output_13_0_g63 );
				simplePerlin2D8_g63 = simplePerlin2D8_g63*0.5 + 0.5;
				float4 appendResult9_g63 = (float4(( simplePerlin2D7_g63 - simplePerlin2D2_g63 ) , ( simplePerlin2D8_g63 - simplePerlin2D2_g63 ) , 0.0 , 0.0));
				float2 coords47_g61 = ( ( appendResult9_g63 * 2.0 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g61 = 0;
				float2 uv47_g61 = 0;
				float fade47_g61 = 0.5;
				float voroi47_g61 = 0;
				float rest47_g61 = 0;
				for( int it47_g61 = 0; it47_g61 <2; it47_g61++ ){
				voroi47_g61 += fade47_g61 * voronoi47_g61( coords47_g61, time47_g61, id47_g61, uv47_g61, 0,voronoiSmoothId47_g61 );
				rest47_g61 += fade47_g61;
				coords47_g61 *= 2;
				fade47_g61 *= 0.5;
				}//Voronoi47_g61
				voroi47_g61 /= rest47_g61;
				float screenDepth50_g61 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g61 = saturate( abs( ( screenDepth50_g61 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g61 = lerp( 1.0 , voroi47_g61 , pow( distanceDepth50_g61 , 0.1 ));
				float smoothstepResult44_g61 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g61);
				float CrustLevel45_g61 = saturate( smoothstepResult44_g61 );
				float time39_g61 = _TimeParameters.x;
				float2 voronoiSmoothId39_g61 = 0;
				float2 paralaxOffset34_g61 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g61 = ( panner53_g61 + paralaxOffset34_g61 );
				float2 panner1_g64 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g61);
				float temp_output_13_0_g64 = 2.0;
				float simplePerlin2D7_g64 = snoise( ( panner1_g64 + float2( 0.01,0 ) )*temp_output_13_0_g64 );
				simplePerlin2D7_g64 = simplePerlin2D7_g64*0.5 + 0.5;
				float simplePerlin2D2_g64 = snoise( panner1_g64*temp_output_13_0_g64 );
				simplePerlin2D2_g64 = simplePerlin2D2_g64*0.5 + 0.5;
				float simplePerlin2D8_g64 = snoise( ( panner1_g64 + float2( 0,0.01 ) )*temp_output_13_0_g64 );
				simplePerlin2D8_g64 = simplePerlin2D8_g64*0.5 + 0.5;
				float4 appendResult9_g64 = (float4(( simplePerlin2D7_g64 - simplePerlin2D2_g64 ) , ( simplePerlin2D8_g64 - simplePerlin2D2_g64 ) , 0.0 , 0.0));
				float2 coords39_g61 = ( ( appendResult9_g64 * 4.0 ) + float4( temp_output_54_0_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g61 = 0;
				float2 uv39_g61 = 0;
				float fade39_g61 = 0.5;
				float voroi39_g61 = 0;
				float rest39_g61 = 0;
				for( int it39_g61 = 0; it39_g61 <5; it39_g61++ ){
				voroi39_g61 += fade39_g61 * voronoi39_g61( coords39_g61, time39_g61, id39_g61, uv39_g61, 0,voronoiSmoothId39_g61 );
				rest39_g61 += fade39_g61;
				coords39_g61 *= 2;
				fade39_g61 *= 0.5;
				}//Voronoi39_g61
				voroi39_g61 /= rest39_g61;
				float4 lerpResult10_g61 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g61 ) * (0.5 + (pow( saturate( ( voroi47_g61 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g61 ) , CrustLevel45_g61);
				float dotResult124 = dot( WorldNormal , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				float3 surf_pos107_g55 = WorldPosition;
				float3 surf_norm107_g55 = WorldNormal;
				float time18_g51 = 0.0;
				float2 voronoiSmoothId18_g51 = 0;
				float2 texCoord3_g52 = input.ase_texcoord8.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g52 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g52);
				float temp_output_13_0_g52 = 30.0;
				float simplePerlin2D7_g52 = snoise( ( panner1_g52 + float2( 0.01,0 ) )*temp_output_13_0_g52 );
				simplePerlin2D7_g52 = simplePerlin2D7_g52*0.5 + 0.5;
				float simplePerlin2D2_g52 = snoise( panner1_g52*temp_output_13_0_g52 );
				simplePerlin2D2_g52 = simplePerlin2D2_g52*0.5 + 0.5;
				float simplePerlin2D8_g52 = snoise( ( panner1_g52 + float2( 0,0.01 ) )*temp_output_13_0_g52 );
				simplePerlin2D8_g52 = simplePerlin2D8_g52*0.5 + 0.5;
				float4 appendResult9_g52 = (float4(( simplePerlin2D7_g52 - simplePerlin2D2_g52 ) , ( simplePerlin2D8_g52 - simplePerlin2D2_g52 ) , 0.0 , 0.0));
				float2 coords18_g51 = ( ( appendResult9_g52 * 0.1 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g51 = 0;
				float2 uv18_g51 = 0;
				float fade18_g51 = 0.5;
				float voroi18_g51 = 0;
				float rest18_g51 = 0;
				for( int it18_g51 = 0; it18_g51 <2; it18_g51++ ){
				voroi18_g51 += fade18_g51 * voronoi18_g51( coords18_g51, time18_g51, id18_g51, uv18_g51, 0,voronoiSmoothId18_g51 );
				rest18_g51 += fade18_g51;
				coords18_g51 *= 2;
				fade18_g51 *= 0.5;
				}//Voronoi18_g51
				voroi18_g51 /= rest18_g51;
				float temp_output_8_0_g51 = ( voroi18_g51 * pow( ( 1.0 - CrustLevel45_g51 ) , 100.0 ) );
				float height107_g55 = temp_output_8_0_g51;
				float scale107_g55 = 1.0;
				float3 localPerturbNormal107_g55 = PerturbNormal107_g55( surf_pos107_g55 , surf_norm107_g55 , height107_g55 , scale107_g55 );
				float3x3 ase_worldToTangent = float3x3( WorldTangent, WorldBiTangent, WorldNormal );
				float3 worldToTangentDir42_g55 = mul( ase_worldToTangent, localPerturbNormal107_g55 );
				float3 CrustNormal65_g51 = worldToTangentDir42_g55;
				float3 surf_pos107_g60 = WorldPosition;
				float3 surf_norm107_g60 = WorldNormal;
				float time18_g56 = 0.0;
				float2 voronoiSmoothId18_g56 = 0;
				float2 texCoord3_g57 = input.ase_texcoord8.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g57 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g57);
				float temp_output_13_0_g57 = 30.0;
				float simplePerlin2D7_g57 = snoise( ( panner1_g57 + float2( 0.01,0 ) )*temp_output_13_0_g57 );
				simplePerlin2D7_g57 = simplePerlin2D7_g57*0.5 + 0.5;
				float simplePerlin2D2_g57 = snoise( panner1_g57*temp_output_13_0_g57 );
				simplePerlin2D2_g57 = simplePerlin2D2_g57*0.5 + 0.5;
				float simplePerlin2D8_g57 = snoise( ( panner1_g57 + float2( 0,0.01 ) )*temp_output_13_0_g57 );
				simplePerlin2D8_g57 = simplePerlin2D8_g57*0.5 + 0.5;
				float4 appendResult9_g57 = (float4(( simplePerlin2D7_g57 - simplePerlin2D2_g57 ) , ( simplePerlin2D8_g57 - simplePerlin2D2_g57 ) , 0.0 , 0.0));
				float2 coords18_g56 = ( ( appendResult9_g57 * 0.1 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g56 = 0;
				float2 uv18_g56 = 0;
				float fade18_g56 = 0.5;
				float voroi18_g56 = 0;
				float rest18_g56 = 0;
				for( int it18_g56 = 0; it18_g56 <2; it18_g56++ ){
				voroi18_g56 += fade18_g56 * voronoi18_g56( coords18_g56, time18_g56, id18_g56, uv18_g56, 0,voronoiSmoothId18_g56 );
				rest18_g56 += fade18_g56;
				coords18_g56 *= 2;
				fade18_g56 *= 0.5;
				}//Voronoi18_g56
				voroi18_g56 /= rest18_g56;
				float temp_output_8_0_g56 = ( voroi18_g56 * pow( ( 1.0 - CrustLevel45_g56 ) , 100.0 ) );
				float height107_g60 = temp_output_8_0_g56;
				float scale107_g60 = 1.0;
				float3 localPerturbNormal107_g60 = PerturbNormal107_g60( surf_pos107_g60 , surf_norm107_g60 , height107_g60 , scale107_g60 );
				float3 worldToTangentDir42_g60 = mul( ase_worldToTangent, localPerturbNormal107_g60 );
				float3 CrustNormal65_g56 = worldToTangentDir42_g60;
				float3 surf_pos107_g65 = WorldPosition;
				float3 surf_norm107_g65 = WorldNormal;
				float time18_g61 = 0.0;
				float2 voronoiSmoothId18_g61 = 0;
				float2 texCoord3_g62 = input.ase_texcoord8.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g62 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g62);
				float temp_output_13_0_g62 = 30.0;
				float simplePerlin2D7_g62 = snoise( ( panner1_g62 + float2( 0.01,0 ) )*temp_output_13_0_g62 );
				simplePerlin2D7_g62 = simplePerlin2D7_g62*0.5 + 0.5;
				float simplePerlin2D2_g62 = snoise( panner1_g62*temp_output_13_0_g62 );
				simplePerlin2D2_g62 = simplePerlin2D2_g62*0.5 + 0.5;
				float simplePerlin2D8_g62 = snoise( ( panner1_g62 + float2( 0,0.01 ) )*temp_output_13_0_g62 );
				simplePerlin2D8_g62 = simplePerlin2D8_g62*0.5 + 0.5;
				float4 appendResult9_g62 = (float4(( simplePerlin2D7_g62 - simplePerlin2D2_g62 ) , ( simplePerlin2D8_g62 - simplePerlin2D2_g62 ) , 0.0 , 0.0));
				float2 coords18_g61 = ( ( appendResult9_g62 * 0.1 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g61 = 0;
				float2 uv18_g61 = 0;
				float fade18_g61 = 0.5;
				float voroi18_g61 = 0;
				float rest18_g61 = 0;
				for( int it18_g61 = 0; it18_g61 <2; it18_g61++ ){
				voroi18_g61 += fade18_g61 * voronoi18_g61( coords18_g61, time18_g61, id18_g61, uv18_g61, 0,voronoiSmoothId18_g61 );
				rest18_g61 += fade18_g61;
				coords18_g61 *= 2;
				fade18_g61 *= 0.5;
				}//Voronoi18_g61
				voroi18_g61 /= rest18_g61;
				float temp_output_8_0_g61 = ( voroi18_g61 * pow( ( 1.0 - CrustLevel45_g61 ) , 100.0 ) );
				float height107_g65 = temp_output_8_0_g61;
				float scale107_g65 = 1.0;
				float3 localPerturbNormal107_g65 = PerturbNormal107_g65( surf_pos107_g65 , surf_norm107_g65 , height107_g65 , scale107_g65 );
				float3 worldToTangentDir42_g65 = mul( ase_worldToTangent, localPerturbNormal107_g65 );
				float3 CrustNormal65_g61 = worldToTangentDir42_g65;
				float3 normalizeResult148 = normalize( ( ( CrustNormal65_g51 * temp_output_128_0 ) + ( CrustNormal65_g56 * temp_output_129_0 ) + ( CrustNormal65_g61 * temp_output_130_0 ) ) );
				
				float4 LavaEmission7_g51 = ( _LavaColor_Instance * voroi39_g51 * smoothstepResult44_g51 );
				float4 LavaEmission7_g56 = ( _LavaColor_Instance * voroi39_g56 * smoothstepResult44_g56 );
				float4 LavaEmission7_g61 = ( _LavaColor_Instance * voroi39_g61 * smoothstepResult44_g61 );
				
				float lerpResult42_g51 = lerp( ( pow( temp_output_8_0_g51 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g51);
				float lerpResult42_g56 = lerp( ( pow( temp_output_8_0_g56 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g56);
				float lerpResult42_g61 = lerp( ( pow( temp_output_8_0_g61 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g61);
				

				float3 BaseColor = ( ( lerpResult10_g51 * temp_output_128_0 ) + ( lerpResult10_g56 * temp_output_129_0 ) + ( lerpResult10_g61 * temp_output_130_0 ) ).rgb;
				float3 Normal = normalizeResult148;
				float3 Emission = ( ( LavaEmission7_g51 * temp_output_128_0 ) + ( LavaEmission7_g56 * temp_output_129_0 ) + ( LavaEmission7_g61 * temp_output_130_0 ) ).rgb;
				float3 Specular = 0.5;
				float Metallic = 0;
				float Smoothness = ( ( lerpResult42_g51 * temp_output_128_0 ) + ( lerpResult42_g56 * temp_output_129_0 ) + ( lerpResult42_g61 * temp_output_130_0 ) );
				float Occlusion = 1;
				float Alpha = 1;
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;
				float3 BakedGI = 0;
				float3 RefractionColor = 1;
				float RefractionIndex = 1;
				float3 Transmission = 1;
				float3 Translucency = 1;

				#ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = input.positionCS.z;
				#endif

				#ifdef _CLEARCOAT
					float CoatMask = 0;
					float CoatSmoothness = 0;
				#endif

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				InputData inputData = (InputData)0;
				inputData.positionWS = WorldPosition;
				inputData.positionCS = input.positionCS;
				inputData.viewDirectionWS = WorldViewDirection;

				#ifdef _NORMALMAP
						#if _NORMAL_DROPOFF_TS
							inputData.normalWS = TransformTangentToWorld(Normal, half3x3(WorldTangent, WorldBiTangent, WorldNormal));
						#elif _NORMAL_DROPOFF_OS
							inputData.normalWS = TransformObjectToWorldNormal(Normal);
						#elif _NORMAL_DROPOFF_WS
							inputData.normalWS = Normal;
						#endif
					inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
				#else
					inputData.normalWS = WorldNormal;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					inputData.shadowCoord = ShadowCoords;
				#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
				#else
					inputData.shadowCoord = float4(0, 0, 0, 0);
				#endif

				#ifdef ASE_FOG
					inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), input.fogFactorAndVertexLight.x);
				#endif
				#ifdef _ADDITIONAL_LIGHTS_VERTEX
					inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
				#endif

				#if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float3 SH = SampleSH(inputData.normalWS.xyz);
				#else
					float3 SH = input.lightmapUVOrVertexSH.xyz;
				#endif

				#if defined(DYNAMICLIGHTMAP_ON)
					inputData.bakedGI = SAMPLE_GI(input.lightmapUVOrVertexSH.xy, input.dynamicLightmapUV.xy, SH, inputData.normalWS);
				#else
					inputData.bakedGI = SAMPLE_GI(input.lightmapUVOrVertexSH.xy, SH, inputData.normalWS);
				#endif

				#ifdef ASE_BAKEDGI
					inputData.bakedGI = BakedGI;
				#endif

				inputData.normalizedScreenSpaceUV = NormalizedScreenSpaceUV;
				inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUVOrVertexSH.xy);

				#if defined(DEBUG_DISPLAY)
					#if defined(DYNAMICLIGHTMAP_ON)
						inputData.dynamicLightmapUV = input.dynamicLightmapUV.xy;
					#endif
					#if defined(LIGHTMAP_ON)
						inputData.staticLightmapUV = input.lightmapUVOrVertexSH.xy;
					#else
						inputData.vertexSH = SH;
					#endif
				#endif

				SurfaceData surfaceData;
				surfaceData.albedo              = BaseColor;
				surfaceData.metallic            = saturate(Metallic);
				surfaceData.specular            = Specular;
				surfaceData.smoothness          = saturate(Smoothness),
				surfaceData.occlusion           = Occlusion,
				surfaceData.emission            = Emission,
				surfaceData.alpha               = saturate(Alpha);
				surfaceData.normalTS            = Normal;
				surfaceData.clearCoatMask       = 0;
				surfaceData.clearCoatSmoothness = 1;

				#ifdef _CLEARCOAT
					surfaceData.clearCoatMask       = saturate(CoatMask);
					surfaceData.clearCoatSmoothness = saturate(CoatSmoothness);
				#endif

				#ifdef _DBUFFER
					ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
				#endif

				#ifdef _ASE_LIGHTING_SIMPLE
					half4 color = UniversalFragmentBlinnPhong( inputData, surfaceData);
				#else
					half4 color = UniversalFragmentPBR( inputData, surfaceData);
				#endif

				#ifdef ASE_TRANSMISSION
				{
					float shadow = _TransmissionShadow;

					#define SUM_LIGHT_TRANSMISSION(Light)\
						float3 atten = Light.color * Light.distanceAttenuation;\
						atten = lerp( atten, atten * Light.shadowAttenuation, shadow );\
						half3 transmission = max( 0, -dot( inputData.normalWS, Light.direction ) ) * atten * Transmission;\
						color.rgb += BaseColor * transmission;

					SUM_LIGHT_TRANSMISSION( GetMainLight( inputData.shadowCoord ) );

					#if defined(_ADDITIONAL_LIGHTS)
						uint meshRenderingLayers = GetMeshRenderingLayer();
						uint pixelLightCount = GetAdditionalLightsCount();
						#if USE_FORWARD_PLUS
							for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
							{
								FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

								Light light = GetAdditionalLight(lightIndex, inputData.positionWS, inputData.shadowMask);
								#ifdef _LIGHT_LAYERS
								if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
								#endif
								{
									SUM_LIGHT_TRANSMISSION( light );
								}
							}
						#endif
						LIGHT_LOOP_BEGIN( pixelLightCount )
							Light light = GetAdditionalLight(lightIndex, inputData.positionWS, inputData.shadowMask);
							#ifdef _LIGHT_LAYERS
							if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
							#endif
							{
								SUM_LIGHT_TRANSMISSION( light );
							}
						LIGHT_LOOP_END
					#endif
				}
				#endif

				#ifdef ASE_TRANSLUCENCY
				{
					float shadow = _TransShadow;
					float normal = _TransNormal;
					float scattering = _TransScattering;
					float direct = _TransDirect;
					float ambient = _TransAmbient;
					float strength = _TransStrength;

					#define SUM_LIGHT_TRANSLUCENCY(Light)\
						float3 atten = Light.color * Light.distanceAttenuation;\
						atten = lerp( atten, atten * Light.shadowAttenuation, shadow );\
						half3 lightDir = Light.direction + inputData.normalWS * normal;\
						half VdotL = pow( saturate( dot( inputData.viewDirectionWS, -lightDir ) ), scattering );\
						half3 translucency = atten * ( VdotL * direct + inputData.bakedGI * ambient ) * Translucency;\
						color.rgb += BaseColor * translucency * strength;

					SUM_LIGHT_TRANSLUCENCY( GetMainLight( inputData.shadowCoord ) );

					#if defined(_ADDITIONAL_LIGHTS)
						uint meshRenderingLayers = GetMeshRenderingLayer();
						uint pixelLightCount = GetAdditionalLightsCount();
						#if USE_FORWARD_PLUS
							for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
							{
								FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

								Light light = GetAdditionalLight(lightIndex, inputData.positionWS, inputData.shadowMask);
								#ifdef _LIGHT_LAYERS
								if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
								#endif
								{
									SUM_LIGHT_TRANSLUCENCY( light );
								}
							}
						#endif
						LIGHT_LOOP_BEGIN( pixelLightCount )
							Light light = GetAdditionalLight(lightIndex, inputData.positionWS, inputData.shadowMask);
							#ifdef _LIGHT_LAYERS
							if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
							#endif
							{
								SUM_LIGHT_TRANSLUCENCY( light );
							}
						LIGHT_LOOP_END
					#endif
				}
				#endif

				#ifdef ASE_REFRACTION
					float4 projScreenPos = ScreenPos / ScreenPos.w;
					float3 refractionOffset = ( RefractionIndex - 1.0 ) * mul( UNITY_MATRIX_V, float4( WorldNormal,0 ) ).xyz * ( 1.0 - dot( WorldNormal, WorldViewDirection ) );
					projScreenPos.xy += refractionOffset.xy;
					float3 refraction = SHADERGRAPH_SAMPLE_SCENE_COLOR( projScreenPos.xy ) * RefractionColor;
					color.rgb = lerp( refraction, color.rgb, color.a );
					color.a = 1;
				#endif

				#ifdef ASE_FINAL_COLOR_ALPHA_MULTIPLY
					color.rgb *= color.a;
				#endif

				#ifdef ASE_FOG
					#ifdef TERRAIN_SPLAT_ADDPASS
						color.rgb = MixFogColor(color.rgb, half3(0,0,0), inputData.fogCoord);
					#else
						color.rgb = MixFog(color.rgb, inputData.fogCoord);
					#endif
				#endif

				#ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
				#endif

				#ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4( EncodeMeshRenderingLayer( renderingLayers ), 0, 0, 0 );
				#endif

				return color;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }

			ZWrite On
			ZTest LEqual
			AlphaToMask Off
			ColorMask 0

			HLSLPROGRAM

			
            #pragma multi_compile _ALPHATEST_ON
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_SHADOWCASTER

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_VERT_NORMAL


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD2;
				#endif
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			

			float3 _LightDirection;
			float3 _LightPosition;

			PackedVaryings VertexFunction( Attributes input )
			{
				PackedVaryings output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( output );

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				float3 positionWS = TransformObjectToWorld( input.positionOS.xyz );
				float3 normalWS = TransformObjectToWorldDir(input.normalOS);

				#if _CASTING_PUNCTUAL_LIGHT_SHADOW
					float3 lightDirectionWS = normalize(_LightPosition - positionWS);
				#else
					float3 lightDirectionWS = _LightDirection;
				#endif

				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

				#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
				#else
					positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				output.positionCS = positionCS;
				output.clipPosV = positionCS;
				output.positionWS = positionWS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(	PackedVaryings input
						#ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						 ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( input );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				float3 WorldPosition = input.positionWS;
				float4 ShadowCoords = float4( 0, 0, 0, 0 );
				float4 ClipPos = input.clipPosV;
				float4 ScreenPos = ComputeScreenPos( input.clipPosV );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = input.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				

				float Alpha = 1;
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;

				#ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = input.positionCS.z;
				#endif

				#ifdef _ALPHATEST_ON
					#ifdef _ALPHATEST_SHADOW_ON
						clip(Alpha - AlphaClipThresholdShadow);
					#else
						clip(Alpha - AlphaClipThreshold);
					#endif
				#endif

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
				#endif

				return 0;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask R
			AlphaToMask Off

			HLSLPROGRAM

			
            #pragma multi_compile _ALPHATEST_ON
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_DEPTHONLY

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_VERT_NORMAL


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD2;
				#endif
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				output.positionCS = vertexInput.positionCS;
				output.clipPosV = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(	PackedVaryings input
						#ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						 ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				float3 WorldPosition = input.positionWS;
				float4 ShadowCoords = float4( 0, 0, 0, 0 );
				float4 ClipPos = input.clipPosV;
				float4 ScreenPos = ComputeScreenPos( input.clipPosV );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = input.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				

				float Alpha = 1;
				float AlphaClipThreshold = 0.5;

				#ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = input.positionCS.z;
				#endif

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
				#endif

				return 0;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "Meta"
			Tags { "LightMode"="Meta" }

			Cull Off

			HLSLPROGRAM
			#pragma multi_compile_fragment _ALPHATEST_ON
			#define _NORMAL_DROPOFF_TS 1
			#define ASE_FOG 1
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _EMISSION
			#define _NORMALMAP 1
			#define ASE_VERSION 19801
			#define ASE_SRP_VERSION 140011
			#define REQUIRE_DEPTH_TEXTURE 1

			#pragma shader_feature EDITOR_VISUALIZATION

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_META

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#pragma multi_compile_instancing


			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 texcoord0 : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 ase_tangent : TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 positionWS : TEXCOORD0;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
				#endif
				#ifdef EDITOR_VISUALIZATION
					float4 VizUV : TEXCOORD2;
					float4 LightCoord : TEXCOORD3;
				#endif
				float4 ase_texcoord4 : TEXCOORD4;
				float4 ase_texcoord5 : TEXCOORD5;
				float4 ase_texcoord6 : TEXCOORD6;
				float4 ase_texcoord7 : TEXCOORD7;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
				UNITY_DEFINE_INSTANCED_PROP(float4, _CrustColor)
				UNITY_DEFINE_INSTANCED_PROP(float4, _LavaColor)
				UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash47_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			inline float2 ParallaxOffset( half h, half height, half3 viewDir )
			{
				h = h * height - height/2.0;
				float3 v = normalize( viewDir );
				v.z += 0.42;
				return h* (v.xy / v.z);
			}
			
					float2 voronoihash47_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash47_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				float4 ase_positionCS = TransformObjectToHClip( ( input.positionOS ).xyz );
				float4 screenPos = ComputeScreenPos( ase_positionCS );
				output.ase_texcoord4 = screenPos;
				float3 ase_tangentWS = TransformObjectToWorldDir( input.ase_tangent.xyz );
				output.ase_texcoord5.xyz = ase_tangentWS;
				output.ase_texcoord6.xyz = ase_normalWS;
				float ase_tangentSign = input.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_bitangentWS = cross( ase_normalWS, ase_tangentWS ) * ase_tangentSign;
				output.ase_texcoord7.xyz = ase_bitangentWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord5.w = 0;
				output.ase_texcoord6.w = 0;
				output.ase_texcoord7.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				float3 positionWS = TransformObjectToWorld( input.positionOS.xyz );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					output.positionWS = positionWS;
				#endif

				output.positionCS = MetaVertexPosition( input.positionOS, input.texcoord1.xy, input.texcoord1.xy, unity_LightmapST, unity_DynamicLightmapST );

				#ifdef EDITOR_VISUALIZATION
					float2 VizUV = 0;
					float4 LightCoord = 0;
					UnityEditorVizData(input.positionOS.xyz, input.texcoord0.xy, input.texcoord1.xy, input.texcoord2.xy, VizUV, LightCoord);
					output.VizUV = float4(VizUV, 0, 0);
					output.LightCoord = LightCoord;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = output.positionCS;
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 texcoord0 : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 ase_tangent : TANGENT;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				output.texcoord0 = input.texcoord0;
				output.texcoord1 = input.texcoord1;
				output.texcoord2 = input.texcoord2;
				output.ase_tangent = input.ase_tangent;
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				output.texcoord0 = patch[0].texcoord0 * bary.x + patch[1].texcoord0 * bary.y + patch[2].texcoord0 * bary.z;
				output.texcoord1 = patch[0].texcoord1 * bary.x + patch[1].texcoord1 * bary.y + patch[2].texcoord1 * bary.z;
				output.texcoord2 = patch[0].texcoord2 * bary.x + patch[1].texcoord2 * bary.y + patch[2].texcoord2 * bary.z;
				output.ase_tangent = patch[0].ase_tangent * bary.x + patch[1].ase_tangent * bary.y + patch[2].ase_tangent * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input  ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 WorldPosition = input.positionWS;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = input.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float4 _CrustColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_CrustColor);
				float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_TurbulenceSpeed);
				float mulTime3_g51 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g51 = mulTime3_g51;
				float2 voronoiSmoothId47_g51 = 0;
				float3 break154 = ( WorldPosition * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner53_g51 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g51);
				float2 panner1_g53 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g51);
				float temp_output_13_0_g53 = 2.0;
				float simplePerlin2D7_g53 = snoise( ( panner1_g53 + float2( 0.01,0 ) )*temp_output_13_0_g53 );
				simplePerlin2D7_g53 = simplePerlin2D7_g53*0.5 + 0.5;
				float simplePerlin2D2_g53 = snoise( panner1_g53*temp_output_13_0_g53 );
				simplePerlin2D2_g53 = simplePerlin2D2_g53*0.5 + 0.5;
				float simplePerlin2D8_g53 = snoise( ( panner1_g53 + float2( 0,0.01 ) )*temp_output_13_0_g53 );
				simplePerlin2D8_g53 = simplePerlin2D8_g53*0.5 + 0.5;
				float4 appendResult9_g53 = (float4(( simplePerlin2D7_g53 - simplePerlin2D2_g53 ) , ( simplePerlin2D8_g53 - simplePerlin2D2_g53 ) , 0.0 , 0.0));
				float2 coords47_g51 = ( ( appendResult9_g53 * 2.0 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g51 = 0;
				float2 uv47_g51 = 0;
				float fade47_g51 = 0.5;
				float voroi47_g51 = 0;
				float rest47_g51 = 0;
				for( int it47_g51 = 0; it47_g51 <2; it47_g51++ ){
				voroi47_g51 += fade47_g51 * voronoi47_g51( coords47_g51, time47_g51, id47_g51, uv47_g51, 0,voronoiSmoothId47_g51 );
				rest47_g51 += fade47_g51;
				coords47_g51 *= 2;
				fade47_g51 *= 0.5;
				}//Voronoi47_g51
				voroi47_g51 /= rest47_g51;
				float4 screenPos = input.ase_texcoord4;
				float4 ase_positionSSNorm = screenPos / screenPos.w;
				ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
				float screenDepth50_g51 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g51 = saturate( abs( ( screenDepth50_g51 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g51 = lerp( 1.0 , voroi47_g51 , pow( distanceDepth50_g51 , 0.1 ));
				float smoothstepResult44_g51 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g51);
				float CrustLevel45_g51 = saturate( smoothstepResult44_g51 );
				float4 _LavaColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_LavaColor);
				float time39_g51 = _TimeParameters.x;
				float2 voronoiSmoothId39_g51 = 0;
				float3 ase_tangentWS = input.ase_texcoord5.xyz;
				float3 ase_normalWS = input.ase_texcoord6.xyz;
				float3 ase_bitangentWS = input.ase_texcoord7.xyz;
				float3 tanToWorld0 = float3( ase_tangentWS.x, ase_bitangentWS.x, ase_normalWS.x );
				float3 tanToWorld1 = float3( ase_tangentWS.y, ase_bitangentWS.y, ase_normalWS.y );
				float3 tanToWorld2 = float3( ase_tangentWS.z, ase_bitangentWS.z, ase_normalWS.z );
				float3 ase_viewVectorTS =  tanToWorld0 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).x + tanToWorld1 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).y  + tanToWorld2 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).z;
				float3 ase_viewDirTS = normalize( ase_viewVectorTS );
				float2 paralaxOffset34_g51 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g51 = ( panner53_g51 + paralaxOffset34_g51 );
				float2 panner1_g54 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g51);
				float temp_output_13_0_g54 = 2.0;
				float simplePerlin2D7_g54 = snoise( ( panner1_g54 + float2( 0.01,0 ) )*temp_output_13_0_g54 );
				simplePerlin2D7_g54 = simplePerlin2D7_g54*0.5 + 0.5;
				float simplePerlin2D2_g54 = snoise( panner1_g54*temp_output_13_0_g54 );
				simplePerlin2D2_g54 = simplePerlin2D2_g54*0.5 + 0.5;
				float simplePerlin2D8_g54 = snoise( ( panner1_g54 + float2( 0,0.01 ) )*temp_output_13_0_g54 );
				simplePerlin2D8_g54 = simplePerlin2D8_g54*0.5 + 0.5;
				float4 appendResult9_g54 = (float4(( simplePerlin2D7_g54 - simplePerlin2D2_g54 ) , ( simplePerlin2D8_g54 - simplePerlin2D2_g54 ) , 0.0 , 0.0));
				float2 coords39_g51 = ( ( appendResult9_g54 * 4.0 ) + float4( temp_output_54_0_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g51 = 0;
				float2 uv39_g51 = 0;
				float fade39_g51 = 0.5;
				float voroi39_g51 = 0;
				float rest39_g51 = 0;
				for( int it39_g51 = 0; it39_g51 <5; it39_g51++ ){
				voroi39_g51 += fade39_g51 * voronoi39_g51( coords39_g51, time39_g51, id39_g51, uv39_g51, 0,voronoiSmoothId39_g51 );
				rest39_g51 += fade39_g51;
				coords39_g51 *= 2;
				fade39_g51 *= 0.5;
				}//Voronoi39_g51
				voroi39_g51 /= rest39_g51;
				float4 lerpResult10_g51 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g51 ) * (0.5 + (pow( saturate( ( voroi47_g51 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g51 ) , CrustLevel45_g51);
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float mulTime3_g56 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g56 = mulTime3_g56;
				float2 voronoiSmoothId47_g56 = 0;
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner53_g56 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g56);
				float2 panner1_g58 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g56);
				float temp_output_13_0_g58 = 2.0;
				float simplePerlin2D7_g58 = snoise( ( panner1_g58 + float2( 0.01,0 ) )*temp_output_13_0_g58 );
				simplePerlin2D7_g58 = simplePerlin2D7_g58*0.5 + 0.5;
				float simplePerlin2D2_g58 = snoise( panner1_g58*temp_output_13_0_g58 );
				simplePerlin2D2_g58 = simplePerlin2D2_g58*0.5 + 0.5;
				float simplePerlin2D8_g58 = snoise( ( panner1_g58 + float2( 0,0.01 ) )*temp_output_13_0_g58 );
				simplePerlin2D8_g58 = simplePerlin2D8_g58*0.5 + 0.5;
				float4 appendResult9_g58 = (float4(( simplePerlin2D7_g58 - simplePerlin2D2_g58 ) , ( simplePerlin2D8_g58 - simplePerlin2D2_g58 ) , 0.0 , 0.0));
				float2 coords47_g56 = ( ( appendResult9_g58 * 2.0 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g56 = 0;
				float2 uv47_g56 = 0;
				float fade47_g56 = 0.5;
				float voroi47_g56 = 0;
				float rest47_g56 = 0;
				for( int it47_g56 = 0; it47_g56 <2; it47_g56++ ){
				voroi47_g56 += fade47_g56 * voronoi47_g56( coords47_g56, time47_g56, id47_g56, uv47_g56, 0,voronoiSmoothId47_g56 );
				rest47_g56 += fade47_g56;
				coords47_g56 *= 2;
				fade47_g56 *= 0.5;
				}//Voronoi47_g56
				voroi47_g56 /= rest47_g56;
				float screenDepth50_g56 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g56 = saturate( abs( ( screenDepth50_g56 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g56 = lerp( 1.0 , voroi47_g56 , pow( distanceDepth50_g56 , 0.1 ));
				float smoothstepResult44_g56 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g56);
				float CrustLevel45_g56 = saturate( smoothstepResult44_g56 );
				float time39_g56 = _TimeParameters.x;
				float2 voronoiSmoothId39_g56 = 0;
				float2 paralaxOffset34_g56 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g56 = ( panner53_g56 + paralaxOffset34_g56 );
				float2 panner1_g59 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g56);
				float temp_output_13_0_g59 = 2.0;
				float simplePerlin2D7_g59 = snoise( ( panner1_g59 + float2( 0.01,0 ) )*temp_output_13_0_g59 );
				simplePerlin2D7_g59 = simplePerlin2D7_g59*0.5 + 0.5;
				float simplePerlin2D2_g59 = snoise( panner1_g59*temp_output_13_0_g59 );
				simplePerlin2D2_g59 = simplePerlin2D2_g59*0.5 + 0.5;
				float simplePerlin2D8_g59 = snoise( ( panner1_g59 + float2( 0,0.01 ) )*temp_output_13_0_g59 );
				simplePerlin2D8_g59 = simplePerlin2D8_g59*0.5 + 0.5;
				float4 appendResult9_g59 = (float4(( simplePerlin2D7_g59 - simplePerlin2D2_g59 ) , ( simplePerlin2D8_g59 - simplePerlin2D2_g59 ) , 0.0 , 0.0));
				float2 coords39_g56 = ( ( appendResult9_g59 * 4.0 ) + float4( temp_output_54_0_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g56 = 0;
				float2 uv39_g56 = 0;
				float fade39_g56 = 0.5;
				float voroi39_g56 = 0;
				float rest39_g56 = 0;
				for( int it39_g56 = 0; it39_g56 <5; it39_g56++ ){
				voroi39_g56 += fade39_g56 * voronoi39_g56( coords39_g56, time39_g56, id39_g56, uv39_g56, 0,voronoiSmoothId39_g56 );
				rest39_g56 += fade39_g56;
				coords39_g56 *= 2;
				fade39_g56 *= 0.5;
				}//Voronoi39_g56
				voroi39_g56 /= rest39_g56;
				float4 lerpResult10_g56 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g56 ) * (0.5 + (pow( saturate( ( voroi47_g56 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g56 ) , CrustLevel45_g56);
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float mulTime3_g61 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g61 = mulTime3_g61;
				float2 voronoiSmoothId47_g61 = 0;
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner53_g61 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g61);
				float2 panner1_g63 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g61);
				float temp_output_13_0_g63 = 2.0;
				float simplePerlin2D7_g63 = snoise( ( panner1_g63 + float2( 0.01,0 ) )*temp_output_13_0_g63 );
				simplePerlin2D7_g63 = simplePerlin2D7_g63*0.5 + 0.5;
				float simplePerlin2D2_g63 = snoise( panner1_g63*temp_output_13_0_g63 );
				simplePerlin2D2_g63 = simplePerlin2D2_g63*0.5 + 0.5;
				float simplePerlin2D8_g63 = snoise( ( panner1_g63 + float2( 0,0.01 ) )*temp_output_13_0_g63 );
				simplePerlin2D8_g63 = simplePerlin2D8_g63*0.5 + 0.5;
				float4 appendResult9_g63 = (float4(( simplePerlin2D7_g63 - simplePerlin2D2_g63 ) , ( simplePerlin2D8_g63 - simplePerlin2D2_g63 ) , 0.0 , 0.0));
				float2 coords47_g61 = ( ( appendResult9_g63 * 2.0 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g61 = 0;
				float2 uv47_g61 = 0;
				float fade47_g61 = 0.5;
				float voroi47_g61 = 0;
				float rest47_g61 = 0;
				for( int it47_g61 = 0; it47_g61 <2; it47_g61++ ){
				voroi47_g61 += fade47_g61 * voronoi47_g61( coords47_g61, time47_g61, id47_g61, uv47_g61, 0,voronoiSmoothId47_g61 );
				rest47_g61 += fade47_g61;
				coords47_g61 *= 2;
				fade47_g61 *= 0.5;
				}//Voronoi47_g61
				voroi47_g61 /= rest47_g61;
				float screenDepth50_g61 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g61 = saturate( abs( ( screenDepth50_g61 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g61 = lerp( 1.0 , voroi47_g61 , pow( distanceDepth50_g61 , 0.1 ));
				float smoothstepResult44_g61 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g61);
				float CrustLevel45_g61 = saturate( smoothstepResult44_g61 );
				float time39_g61 = _TimeParameters.x;
				float2 voronoiSmoothId39_g61 = 0;
				float2 paralaxOffset34_g61 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g61 = ( panner53_g61 + paralaxOffset34_g61 );
				float2 panner1_g64 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g61);
				float temp_output_13_0_g64 = 2.0;
				float simplePerlin2D7_g64 = snoise( ( panner1_g64 + float2( 0.01,0 ) )*temp_output_13_0_g64 );
				simplePerlin2D7_g64 = simplePerlin2D7_g64*0.5 + 0.5;
				float simplePerlin2D2_g64 = snoise( panner1_g64*temp_output_13_0_g64 );
				simplePerlin2D2_g64 = simplePerlin2D2_g64*0.5 + 0.5;
				float simplePerlin2D8_g64 = snoise( ( panner1_g64 + float2( 0,0.01 ) )*temp_output_13_0_g64 );
				simplePerlin2D8_g64 = simplePerlin2D8_g64*0.5 + 0.5;
				float4 appendResult9_g64 = (float4(( simplePerlin2D7_g64 - simplePerlin2D2_g64 ) , ( simplePerlin2D8_g64 - simplePerlin2D2_g64 ) , 0.0 , 0.0));
				float2 coords39_g61 = ( ( appendResult9_g64 * 4.0 ) + float4( temp_output_54_0_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g61 = 0;
				float2 uv39_g61 = 0;
				float fade39_g61 = 0.5;
				float voroi39_g61 = 0;
				float rest39_g61 = 0;
				for( int it39_g61 = 0; it39_g61 <5; it39_g61++ ){
				voroi39_g61 += fade39_g61 * voronoi39_g61( coords39_g61, time39_g61, id39_g61, uv39_g61, 0,voronoiSmoothId39_g61 );
				rest39_g61 += fade39_g61;
				coords39_g61 *= 2;
				fade39_g61 *= 0.5;
				}//Voronoi39_g61
				voroi39_g61 /= rest39_g61;
				float4 lerpResult10_g61 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g61 ) * (0.5 + (pow( saturate( ( voroi47_g61 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g61 ) , CrustLevel45_g61);
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				float4 LavaEmission7_g51 = ( _LavaColor_Instance * voroi39_g51 * smoothstepResult44_g51 );
				float4 LavaEmission7_g56 = ( _LavaColor_Instance * voroi39_g56 * smoothstepResult44_g56 );
				float4 LavaEmission7_g61 = ( _LavaColor_Instance * voroi39_g61 * smoothstepResult44_g61 );
				

				float3 BaseColor = ( ( lerpResult10_g51 * temp_output_128_0 ) + ( lerpResult10_g56 * temp_output_129_0 ) + ( lerpResult10_g61 * temp_output_130_0 ) ).rgb;
				float3 Emission = ( ( LavaEmission7_g51 * temp_output_128_0 ) + ( LavaEmission7_g56 * temp_output_129_0 ) + ( LavaEmission7_g61 * temp_output_130_0 ) ).rgb;
				float Alpha = 1;
				float AlphaClipThreshold = 0.5;

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				MetaInput metaInput = (MetaInput)0;
				metaInput.Albedo = BaseColor;
				metaInput.Emission = Emission;
				#ifdef EDITOR_VISUALIZATION
					metaInput.VizUV = input.VizUV.xy;
					metaInput.LightCoord = input.LightCoord;
				#endif

				return UnityMetaFragment(metaInput);
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "Universal2D"
			Tags { "LightMode"="Universal2D" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite On
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

			HLSLPROGRAM

			#pragma multi_compile_fragment _ALPHATEST_ON
			#define _NORMAL_DROPOFF_TS 1
			#define ASE_FOG 1
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _EMISSION
			#define _NORMALMAP 1
			#define ASE_VERSION 19801
			#define ASE_SRP_VERSION 140011
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_2D

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#pragma multi_compile_instancing


			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_tangent : TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 positionWS : TEXCOORD0;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
				#endif
				float4 ase_texcoord2 : TEXCOORD2;
				float4 ase_texcoord3 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
				float4 ase_texcoord5 : TEXCOORD5;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
				UNITY_DEFINE_INSTANCED_PROP(float4, _CrustColor)
				UNITY_DEFINE_INSTANCED_PROP(float4, _LavaColor)
				UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash47_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			inline float2 ParallaxOffset( half h, half height, half3 viewDir )
			{
				h = h * height - height/2.0;
				float3 v = normalize( viewDir );
				v.z += 0.42;
				return h* (v.xy / v.z);
			}
			
					float2 voronoihash47_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash47_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID( input );
				UNITY_TRANSFER_INSTANCE_ID( input, output );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( output );

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				float4 ase_positionCS = TransformObjectToHClip( ( input.positionOS ).xyz );
				float4 screenPos = ComputeScreenPos( ase_positionCS );
				output.ase_texcoord2 = screenPos;
				float3 ase_tangentWS = TransformObjectToWorldDir( input.ase_tangent.xyz );
				output.ase_texcoord3.xyz = ase_tangentWS;
				output.ase_texcoord4.xyz = ase_normalWS;
				float ase_tangentSign = input.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_bitangentWS = cross( ase_normalWS, ase_tangentWS ) * ase_tangentSign;
				output.ase_texcoord5.xyz = ase_bitangentWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord3.w = 0;
				output.ase_texcoord4.w = 0;
				output.ase_texcoord5.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					output.positionWS = vertexInput.positionWS;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				output.positionCS = vertexInput.positionCS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_tangent : TANGENT;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				output.ase_tangent = input.ase_tangent;
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				output.ase_tangent = patch[0].ase_tangent * bary.x + patch[1].ase_tangent * bary.y + patch[2].ase_tangent * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input  ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( input );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 WorldPosition = input.positionWS;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = input.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float4 _CrustColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_CrustColor);
				float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_TurbulenceSpeed);
				float mulTime3_g51 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g51 = mulTime3_g51;
				float2 voronoiSmoothId47_g51 = 0;
				float3 break154 = ( WorldPosition * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner53_g51 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g51);
				float2 panner1_g53 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g51);
				float temp_output_13_0_g53 = 2.0;
				float simplePerlin2D7_g53 = snoise( ( panner1_g53 + float2( 0.01,0 ) )*temp_output_13_0_g53 );
				simplePerlin2D7_g53 = simplePerlin2D7_g53*0.5 + 0.5;
				float simplePerlin2D2_g53 = snoise( panner1_g53*temp_output_13_0_g53 );
				simplePerlin2D2_g53 = simplePerlin2D2_g53*0.5 + 0.5;
				float simplePerlin2D8_g53 = snoise( ( panner1_g53 + float2( 0,0.01 ) )*temp_output_13_0_g53 );
				simplePerlin2D8_g53 = simplePerlin2D8_g53*0.5 + 0.5;
				float4 appendResult9_g53 = (float4(( simplePerlin2D7_g53 - simplePerlin2D2_g53 ) , ( simplePerlin2D8_g53 - simplePerlin2D2_g53 ) , 0.0 , 0.0));
				float2 coords47_g51 = ( ( appendResult9_g53 * 2.0 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g51 = 0;
				float2 uv47_g51 = 0;
				float fade47_g51 = 0.5;
				float voroi47_g51 = 0;
				float rest47_g51 = 0;
				for( int it47_g51 = 0; it47_g51 <2; it47_g51++ ){
				voroi47_g51 += fade47_g51 * voronoi47_g51( coords47_g51, time47_g51, id47_g51, uv47_g51, 0,voronoiSmoothId47_g51 );
				rest47_g51 += fade47_g51;
				coords47_g51 *= 2;
				fade47_g51 *= 0.5;
				}//Voronoi47_g51
				voroi47_g51 /= rest47_g51;
				float4 screenPos = input.ase_texcoord2;
				float4 ase_positionSSNorm = screenPos / screenPos.w;
				ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
				float screenDepth50_g51 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g51 = saturate( abs( ( screenDepth50_g51 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g51 = lerp( 1.0 , voroi47_g51 , pow( distanceDepth50_g51 , 0.1 ));
				float smoothstepResult44_g51 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g51);
				float CrustLevel45_g51 = saturate( smoothstepResult44_g51 );
				float4 _LavaColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_LavaColor);
				float time39_g51 = _TimeParameters.x;
				float2 voronoiSmoothId39_g51 = 0;
				float3 ase_tangentWS = input.ase_texcoord3.xyz;
				float3 ase_normalWS = input.ase_texcoord4.xyz;
				float3 ase_bitangentWS = input.ase_texcoord5.xyz;
				float3 tanToWorld0 = float3( ase_tangentWS.x, ase_bitangentWS.x, ase_normalWS.x );
				float3 tanToWorld1 = float3( ase_tangentWS.y, ase_bitangentWS.y, ase_normalWS.y );
				float3 tanToWorld2 = float3( ase_tangentWS.z, ase_bitangentWS.z, ase_normalWS.z );
				float3 ase_viewVectorTS =  tanToWorld0 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).x + tanToWorld1 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).y  + tanToWorld2 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).z;
				float3 ase_viewDirTS = normalize( ase_viewVectorTS );
				float2 paralaxOffset34_g51 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g51 = ( panner53_g51 + paralaxOffset34_g51 );
				float2 panner1_g54 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g51);
				float temp_output_13_0_g54 = 2.0;
				float simplePerlin2D7_g54 = snoise( ( panner1_g54 + float2( 0.01,0 ) )*temp_output_13_0_g54 );
				simplePerlin2D7_g54 = simplePerlin2D7_g54*0.5 + 0.5;
				float simplePerlin2D2_g54 = snoise( panner1_g54*temp_output_13_0_g54 );
				simplePerlin2D2_g54 = simplePerlin2D2_g54*0.5 + 0.5;
				float simplePerlin2D8_g54 = snoise( ( panner1_g54 + float2( 0,0.01 ) )*temp_output_13_0_g54 );
				simplePerlin2D8_g54 = simplePerlin2D8_g54*0.5 + 0.5;
				float4 appendResult9_g54 = (float4(( simplePerlin2D7_g54 - simplePerlin2D2_g54 ) , ( simplePerlin2D8_g54 - simplePerlin2D2_g54 ) , 0.0 , 0.0));
				float2 coords39_g51 = ( ( appendResult9_g54 * 4.0 ) + float4( temp_output_54_0_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g51 = 0;
				float2 uv39_g51 = 0;
				float fade39_g51 = 0.5;
				float voroi39_g51 = 0;
				float rest39_g51 = 0;
				for( int it39_g51 = 0; it39_g51 <5; it39_g51++ ){
				voroi39_g51 += fade39_g51 * voronoi39_g51( coords39_g51, time39_g51, id39_g51, uv39_g51, 0,voronoiSmoothId39_g51 );
				rest39_g51 += fade39_g51;
				coords39_g51 *= 2;
				fade39_g51 *= 0.5;
				}//Voronoi39_g51
				voroi39_g51 /= rest39_g51;
				float4 lerpResult10_g51 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g51 ) * (0.5 + (pow( saturate( ( voroi47_g51 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g51 ) , CrustLevel45_g51);
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float mulTime3_g56 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g56 = mulTime3_g56;
				float2 voronoiSmoothId47_g56 = 0;
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner53_g56 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g56);
				float2 panner1_g58 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g56);
				float temp_output_13_0_g58 = 2.0;
				float simplePerlin2D7_g58 = snoise( ( panner1_g58 + float2( 0.01,0 ) )*temp_output_13_0_g58 );
				simplePerlin2D7_g58 = simplePerlin2D7_g58*0.5 + 0.5;
				float simplePerlin2D2_g58 = snoise( panner1_g58*temp_output_13_0_g58 );
				simplePerlin2D2_g58 = simplePerlin2D2_g58*0.5 + 0.5;
				float simplePerlin2D8_g58 = snoise( ( panner1_g58 + float2( 0,0.01 ) )*temp_output_13_0_g58 );
				simplePerlin2D8_g58 = simplePerlin2D8_g58*0.5 + 0.5;
				float4 appendResult9_g58 = (float4(( simplePerlin2D7_g58 - simplePerlin2D2_g58 ) , ( simplePerlin2D8_g58 - simplePerlin2D2_g58 ) , 0.0 , 0.0));
				float2 coords47_g56 = ( ( appendResult9_g58 * 2.0 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g56 = 0;
				float2 uv47_g56 = 0;
				float fade47_g56 = 0.5;
				float voroi47_g56 = 0;
				float rest47_g56 = 0;
				for( int it47_g56 = 0; it47_g56 <2; it47_g56++ ){
				voroi47_g56 += fade47_g56 * voronoi47_g56( coords47_g56, time47_g56, id47_g56, uv47_g56, 0,voronoiSmoothId47_g56 );
				rest47_g56 += fade47_g56;
				coords47_g56 *= 2;
				fade47_g56 *= 0.5;
				}//Voronoi47_g56
				voroi47_g56 /= rest47_g56;
				float screenDepth50_g56 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g56 = saturate( abs( ( screenDepth50_g56 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g56 = lerp( 1.0 , voroi47_g56 , pow( distanceDepth50_g56 , 0.1 ));
				float smoothstepResult44_g56 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g56);
				float CrustLevel45_g56 = saturate( smoothstepResult44_g56 );
				float time39_g56 = _TimeParameters.x;
				float2 voronoiSmoothId39_g56 = 0;
				float2 paralaxOffset34_g56 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g56 = ( panner53_g56 + paralaxOffset34_g56 );
				float2 panner1_g59 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g56);
				float temp_output_13_0_g59 = 2.0;
				float simplePerlin2D7_g59 = snoise( ( panner1_g59 + float2( 0.01,0 ) )*temp_output_13_0_g59 );
				simplePerlin2D7_g59 = simplePerlin2D7_g59*0.5 + 0.5;
				float simplePerlin2D2_g59 = snoise( panner1_g59*temp_output_13_0_g59 );
				simplePerlin2D2_g59 = simplePerlin2D2_g59*0.5 + 0.5;
				float simplePerlin2D8_g59 = snoise( ( panner1_g59 + float2( 0,0.01 ) )*temp_output_13_0_g59 );
				simplePerlin2D8_g59 = simplePerlin2D8_g59*0.5 + 0.5;
				float4 appendResult9_g59 = (float4(( simplePerlin2D7_g59 - simplePerlin2D2_g59 ) , ( simplePerlin2D8_g59 - simplePerlin2D2_g59 ) , 0.0 , 0.0));
				float2 coords39_g56 = ( ( appendResult9_g59 * 4.0 ) + float4( temp_output_54_0_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g56 = 0;
				float2 uv39_g56 = 0;
				float fade39_g56 = 0.5;
				float voroi39_g56 = 0;
				float rest39_g56 = 0;
				for( int it39_g56 = 0; it39_g56 <5; it39_g56++ ){
				voroi39_g56 += fade39_g56 * voronoi39_g56( coords39_g56, time39_g56, id39_g56, uv39_g56, 0,voronoiSmoothId39_g56 );
				rest39_g56 += fade39_g56;
				coords39_g56 *= 2;
				fade39_g56 *= 0.5;
				}//Voronoi39_g56
				voroi39_g56 /= rest39_g56;
				float4 lerpResult10_g56 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g56 ) * (0.5 + (pow( saturate( ( voroi47_g56 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g56 ) , CrustLevel45_g56);
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float mulTime3_g61 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g61 = mulTime3_g61;
				float2 voronoiSmoothId47_g61 = 0;
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner53_g61 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g61);
				float2 panner1_g63 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g61);
				float temp_output_13_0_g63 = 2.0;
				float simplePerlin2D7_g63 = snoise( ( panner1_g63 + float2( 0.01,0 ) )*temp_output_13_0_g63 );
				simplePerlin2D7_g63 = simplePerlin2D7_g63*0.5 + 0.5;
				float simplePerlin2D2_g63 = snoise( panner1_g63*temp_output_13_0_g63 );
				simplePerlin2D2_g63 = simplePerlin2D2_g63*0.5 + 0.5;
				float simplePerlin2D8_g63 = snoise( ( panner1_g63 + float2( 0,0.01 ) )*temp_output_13_0_g63 );
				simplePerlin2D8_g63 = simplePerlin2D8_g63*0.5 + 0.5;
				float4 appendResult9_g63 = (float4(( simplePerlin2D7_g63 - simplePerlin2D2_g63 ) , ( simplePerlin2D8_g63 - simplePerlin2D2_g63 ) , 0.0 , 0.0));
				float2 coords47_g61 = ( ( appendResult9_g63 * 2.0 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g61 = 0;
				float2 uv47_g61 = 0;
				float fade47_g61 = 0.5;
				float voroi47_g61 = 0;
				float rest47_g61 = 0;
				for( int it47_g61 = 0; it47_g61 <2; it47_g61++ ){
				voroi47_g61 += fade47_g61 * voronoi47_g61( coords47_g61, time47_g61, id47_g61, uv47_g61, 0,voronoiSmoothId47_g61 );
				rest47_g61 += fade47_g61;
				coords47_g61 *= 2;
				fade47_g61 *= 0.5;
				}//Voronoi47_g61
				voroi47_g61 /= rest47_g61;
				float screenDepth50_g61 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g61 = saturate( abs( ( screenDepth50_g61 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g61 = lerp( 1.0 , voroi47_g61 , pow( distanceDepth50_g61 , 0.1 ));
				float smoothstepResult44_g61 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g61);
				float CrustLevel45_g61 = saturate( smoothstepResult44_g61 );
				float time39_g61 = _TimeParameters.x;
				float2 voronoiSmoothId39_g61 = 0;
				float2 paralaxOffset34_g61 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g61 = ( panner53_g61 + paralaxOffset34_g61 );
				float2 panner1_g64 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g61);
				float temp_output_13_0_g64 = 2.0;
				float simplePerlin2D7_g64 = snoise( ( panner1_g64 + float2( 0.01,0 ) )*temp_output_13_0_g64 );
				simplePerlin2D7_g64 = simplePerlin2D7_g64*0.5 + 0.5;
				float simplePerlin2D2_g64 = snoise( panner1_g64*temp_output_13_0_g64 );
				simplePerlin2D2_g64 = simplePerlin2D2_g64*0.5 + 0.5;
				float simplePerlin2D8_g64 = snoise( ( panner1_g64 + float2( 0,0.01 ) )*temp_output_13_0_g64 );
				simplePerlin2D8_g64 = simplePerlin2D8_g64*0.5 + 0.5;
				float4 appendResult9_g64 = (float4(( simplePerlin2D7_g64 - simplePerlin2D2_g64 ) , ( simplePerlin2D8_g64 - simplePerlin2D2_g64 ) , 0.0 , 0.0));
				float2 coords39_g61 = ( ( appendResult9_g64 * 4.0 ) + float4( temp_output_54_0_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g61 = 0;
				float2 uv39_g61 = 0;
				float fade39_g61 = 0.5;
				float voroi39_g61 = 0;
				float rest39_g61 = 0;
				for( int it39_g61 = 0; it39_g61 <5; it39_g61++ ){
				voroi39_g61 += fade39_g61 * voronoi39_g61( coords39_g61, time39_g61, id39_g61, uv39_g61, 0,voronoiSmoothId39_g61 );
				rest39_g61 += fade39_g61;
				coords39_g61 *= 2;
				fade39_g61 *= 0.5;
				}//Voronoi39_g61
				voroi39_g61 /= rest39_g61;
				float4 lerpResult10_g61 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g61 ) * (0.5 + (pow( saturate( ( voroi47_g61 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g61 ) , CrustLevel45_g61);
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				

				float3 BaseColor = ( ( lerpResult10_g51 * temp_output_128_0 ) + ( lerpResult10_g56 * temp_output_129_0 ) + ( lerpResult10_g61 * temp_output_130_0 ) ).rgb;
				float Alpha = 1;
				float AlphaClipThreshold = 0.5;

				half4 color = half4(BaseColor, Alpha );

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				return color;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthNormals"
			Tags { "LightMode"="DepthNormals" }

			ZWrite On
			Blend One Zero
			ZTest LEqual
			ZWrite On

			HLSLPROGRAM

			
            #pragma multi_compile _ALPHATEST_ON
            #define _NORMAL_DROPOFF_TS 1
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011
            #define REQUIRE_DEPTH_TEXTURE 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
		

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_DEPTHNORMALSONLY
			//#define SHADERPASS SHADERPASS_DEPTHNORMALS

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#define ASE_NEEDS_FRAG_WORLD_NORMAL
			#define ASE_NEEDS_FRAG_SCREEN_POSITION
			#define ASE_NEEDS_FRAG_WORLD_TANGENT
			#define ASE_NEEDS_VERT_TANGENT
			#pragma multi_compile_instancing


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
				float4 tangentWS : TEXCOORD3;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD4;
				#endif
				float4 ase_texcoord5 : TEXCOORD5;
				float4 ase_texcoord6 : TEXCOORD6;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
				UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash18_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
					float2 voronoihash47_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			float3 PerturbNormal107_g55( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			
					float2 voronoihash18_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
					float2 voronoihash47_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			float3 PerturbNormal107_g60( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			
					float2 voronoihash18_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
					float2 voronoihash47_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			float3 PerturbNormal107_g65( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				float3 ase_tangentWS = TransformObjectToWorldDir( input.tangentOS.xyz );
				float ase_tangentSign = input.tangentOS.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_bitangentWS = cross( ase_normalWS, ase_tangentWS ) * ase_tangentSign;
				output.ase_texcoord6.xyz = ase_bitangentWS;
				
				output.ase_texcoord5.xy = input.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord5.zw = 0;
				output.ase_texcoord6.w = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;
				input.tangentOS = input.tangentOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );

				float3 normalWS = TransformObjectToWorldNormal( input.normalOS );
				float4 tangentWS = float4( TransformObjectToWorldDir( input.tangentOS.xyz ), input.tangentOS.w );

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				output.positionCS = vertexInput.positionCS;
				output.clipPosV = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;
				output.normalWS = normalWS;
				output.tangentWS = tangentWS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float4 ase_texcoord : TEXCOORD0;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				output.tangentOS = input.tangentOS;
				output.ase_texcoord = input.ase_texcoord;
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				output.tangentOS = patch[0].tangentOS * bary.x + patch[1].tangentOS * bary.y + patch[2].tangentOS * bary.z;
				output.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			void frag(	PackedVaryings input
						, out half4 outNormalWS : SV_Target0
						#ifdef ASE_DEPTH_WRITE_ON
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						#ifdef _WRITE_RENDERING_LAYERS
						, out float4 outRenderingLayers : SV_Target1
						#endif
						 )
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				float4 ShadowCoords = float4( 0, 0, 0, 0 );
				float3 WorldNormal = input.normalWS;
				float4 WorldTangent = input.tangentWS;
				float3 WorldPosition = input.positionWS;
				float4 ClipPos = input.clipPosV;
				float4 ScreenPos = ComputeScreenPos( input.clipPosV );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = input.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float3 surf_pos107_g55 = WorldPosition;
				float3 surf_norm107_g55 = WorldNormal;
				float time18_g51 = 0.0;
				float2 voronoiSmoothId18_g51 = 0;
				float2 texCoord3_g52 = input.ase_texcoord5.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g52 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g52);
				float temp_output_13_0_g52 = 30.0;
				float simplePerlin2D7_g52 = snoise( ( panner1_g52 + float2( 0.01,0 ) )*temp_output_13_0_g52 );
				simplePerlin2D7_g52 = simplePerlin2D7_g52*0.5 + 0.5;
				float simplePerlin2D2_g52 = snoise( panner1_g52*temp_output_13_0_g52 );
				simplePerlin2D2_g52 = simplePerlin2D2_g52*0.5 + 0.5;
				float simplePerlin2D8_g52 = snoise( ( panner1_g52 + float2( 0,0.01 ) )*temp_output_13_0_g52 );
				simplePerlin2D8_g52 = simplePerlin2D8_g52*0.5 + 0.5;
				float4 appendResult9_g52 = (float4(( simplePerlin2D7_g52 - simplePerlin2D2_g52 ) , ( simplePerlin2D8_g52 - simplePerlin2D2_g52 ) , 0.0 , 0.0));
				float3 break154 = ( WorldPosition * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner53_g51 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g51);
				float2 coords18_g51 = ( ( appendResult9_g52 * 0.1 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g51 = 0;
				float2 uv18_g51 = 0;
				float fade18_g51 = 0.5;
				float voroi18_g51 = 0;
				float rest18_g51 = 0;
				for( int it18_g51 = 0; it18_g51 <2; it18_g51++ ){
				voroi18_g51 += fade18_g51 * voronoi18_g51( coords18_g51, time18_g51, id18_g51, uv18_g51, 0,voronoiSmoothId18_g51 );
				rest18_g51 += fade18_g51;
				coords18_g51 *= 2;
				fade18_g51 *= 0.5;
				}//Voronoi18_g51
				voroi18_g51 /= rest18_g51;
				float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_TurbulenceSpeed);
				float mulTime3_g51 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g51 = mulTime3_g51;
				float2 voronoiSmoothId47_g51 = 0;
				float2 panner1_g53 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g51);
				float temp_output_13_0_g53 = 2.0;
				float simplePerlin2D7_g53 = snoise( ( panner1_g53 + float2( 0.01,0 ) )*temp_output_13_0_g53 );
				simplePerlin2D7_g53 = simplePerlin2D7_g53*0.5 + 0.5;
				float simplePerlin2D2_g53 = snoise( panner1_g53*temp_output_13_0_g53 );
				simplePerlin2D2_g53 = simplePerlin2D2_g53*0.5 + 0.5;
				float simplePerlin2D8_g53 = snoise( ( panner1_g53 + float2( 0,0.01 ) )*temp_output_13_0_g53 );
				simplePerlin2D8_g53 = simplePerlin2D8_g53*0.5 + 0.5;
				float4 appendResult9_g53 = (float4(( simplePerlin2D7_g53 - simplePerlin2D2_g53 ) , ( simplePerlin2D8_g53 - simplePerlin2D2_g53 ) , 0.0 , 0.0));
				float2 coords47_g51 = ( ( appendResult9_g53 * 2.0 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g51 = 0;
				float2 uv47_g51 = 0;
				float fade47_g51 = 0.5;
				float voroi47_g51 = 0;
				float rest47_g51 = 0;
				for( int it47_g51 = 0; it47_g51 <2; it47_g51++ ){
				voroi47_g51 += fade47_g51 * voronoi47_g51( coords47_g51, time47_g51, id47_g51, uv47_g51, 0,voronoiSmoothId47_g51 );
				rest47_g51 += fade47_g51;
				coords47_g51 *= 2;
				fade47_g51 *= 0.5;
				}//Voronoi47_g51
				voroi47_g51 /= rest47_g51;
				float4 ase_positionSSNorm = ScreenPos / ScreenPos.w;
				ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
				float screenDepth50_g51 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g51 = saturate( abs( ( screenDepth50_g51 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g51 = lerp( 1.0 , voroi47_g51 , pow( distanceDepth50_g51 , 0.1 ));
				float smoothstepResult44_g51 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g51);
				float CrustLevel45_g51 = saturate( smoothstepResult44_g51 );
				float temp_output_8_0_g51 = ( voroi18_g51 * pow( ( 1.0 - CrustLevel45_g51 ) , 100.0 ) );
				float height107_g55 = temp_output_8_0_g51;
				float scale107_g55 = 1.0;
				float3 localPerturbNormal107_g55 = PerturbNormal107_g55( surf_pos107_g55 , surf_norm107_g55 , height107_g55 , scale107_g55 );
				float3 ase_bitangentWS = input.ase_texcoord6.xyz;
				float3x3 ase_worldToTangent = float3x3( WorldTangent.xyz, ase_bitangentWS, WorldNormal );
				float3 worldToTangentDir42_g55 = mul( ase_worldToTangent, localPerturbNormal107_g55 );
				float3 CrustNormal65_g51 = worldToTangentDir42_g55;
				float dotResult113 = dot( WorldNormal , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float3 surf_pos107_g60 = WorldPosition;
				float3 surf_norm107_g60 = WorldNormal;
				float time18_g56 = 0.0;
				float2 voronoiSmoothId18_g56 = 0;
				float2 texCoord3_g57 = input.ase_texcoord5.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g57 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g57);
				float temp_output_13_0_g57 = 30.0;
				float simplePerlin2D7_g57 = snoise( ( panner1_g57 + float2( 0.01,0 ) )*temp_output_13_0_g57 );
				simplePerlin2D7_g57 = simplePerlin2D7_g57*0.5 + 0.5;
				float simplePerlin2D2_g57 = snoise( panner1_g57*temp_output_13_0_g57 );
				simplePerlin2D2_g57 = simplePerlin2D2_g57*0.5 + 0.5;
				float simplePerlin2D8_g57 = snoise( ( panner1_g57 + float2( 0,0.01 ) )*temp_output_13_0_g57 );
				simplePerlin2D8_g57 = simplePerlin2D8_g57*0.5 + 0.5;
				float4 appendResult9_g57 = (float4(( simplePerlin2D7_g57 - simplePerlin2D2_g57 ) , ( simplePerlin2D8_g57 - simplePerlin2D2_g57 ) , 0.0 , 0.0));
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner53_g56 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g56);
				float2 coords18_g56 = ( ( appendResult9_g57 * 0.1 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g56 = 0;
				float2 uv18_g56 = 0;
				float fade18_g56 = 0.5;
				float voroi18_g56 = 0;
				float rest18_g56 = 0;
				for( int it18_g56 = 0; it18_g56 <2; it18_g56++ ){
				voroi18_g56 += fade18_g56 * voronoi18_g56( coords18_g56, time18_g56, id18_g56, uv18_g56, 0,voronoiSmoothId18_g56 );
				rest18_g56 += fade18_g56;
				coords18_g56 *= 2;
				fade18_g56 *= 0.5;
				}//Voronoi18_g56
				voroi18_g56 /= rest18_g56;
				float mulTime3_g56 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g56 = mulTime3_g56;
				float2 voronoiSmoothId47_g56 = 0;
				float2 panner1_g58 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g56);
				float temp_output_13_0_g58 = 2.0;
				float simplePerlin2D7_g58 = snoise( ( panner1_g58 + float2( 0.01,0 ) )*temp_output_13_0_g58 );
				simplePerlin2D7_g58 = simplePerlin2D7_g58*0.5 + 0.5;
				float simplePerlin2D2_g58 = snoise( panner1_g58*temp_output_13_0_g58 );
				simplePerlin2D2_g58 = simplePerlin2D2_g58*0.5 + 0.5;
				float simplePerlin2D8_g58 = snoise( ( panner1_g58 + float2( 0,0.01 ) )*temp_output_13_0_g58 );
				simplePerlin2D8_g58 = simplePerlin2D8_g58*0.5 + 0.5;
				float4 appendResult9_g58 = (float4(( simplePerlin2D7_g58 - simplePerlin2D2_g58 ) , ( simplePerlin2D8_g58 - simplePerlin2D2_g58 ) , 0.0 , 0.0));
				float2 coords47_g56 = ( ( appendResult9_g58 * 2.0 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g56 = 0;
				float2 uv47_g56 = 0;
				float fade47_g56 = 0.5;
				float voroi47_g56 = 0;
				float rest47_g56 = 0;
				for( int it47_g56 = 0; it47_g56 <2; it47_g56++ ){
				voroi47_g56 += fade47_g56 * voronoi47_g56( coords47_g56, time47_g56, id47_g56, uv47_g56, 0,voronoiSmoothId47_g56 );
				rest47_g56 += fade47_g56;
				coords47_g56 *= 2;
				fade47_g56 *= 0.5;
				}//Voronoi47_g56
				voroi47_g56 /= rest47_g56;
				float screenDepth50_g56 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g56 = saturate( abs( ( screenDepth50_g56 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g56 = lerp( 1.0 , voroi47_g56 , pow( distanceDepth50_g56 , 0.1 ));
				float smoothstepResult44_g56 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g56);
				float CrustLevel45_g56 = saturate( smoothstepResult44_g56 );
				float temp_output_8_0_g56 = ( voroi18_g56 * pow( ( 1.0 - CrustLevel45_g56 ) , 100.0 ) );
				float height107_g60 = temp_output_8_0_g56;
				float scale107_g60 = 1.0;
				float3 localPerturbNormal107_g60 = PerturbNormal107_g60( surf_pos107_g60 , surf_norm107_g60 , height107_g60 , scale107_g60 );
				float3 worldToTangentDir42_g60 = mul( ase_worldToTangent, localPerturbNormal107_g60 );
				float3 CrustNormal65_g56 = worldToTangentDir42_g60;
				float dotResult119 = dot( WorldNormal , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float3 surf_pos107_g65 = WorldPosition;
				float3 surf_norm107_g65 = WorldNormal;
				float time18_g61 = 0.0;
				float2 voronoiSmoothId18_g61 = 0;
				float2 texCoord3_g62 = input.ase_texcoord5.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g62 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g62);
				float temp_output_13_0_g62 = 30.0;
				float simplePerlin2D7_g62 = snoise( ( panner1_g62 + float2( 0.01,0 ) )*temp_output_13_0_g62 );
				simplePerlin2D7_g62 = simplePerlin2D7_g62*0.5 + 0.5;
				float simplePerlin2D2_g62 = snoise( panner1_g62*temp_output_13_0_g62 );
				simplePerlin2D2_g62 = simplePerlin2D2_g62*0.5 + 0.5;
				float simplePerlin2D8_g62 = snoise( ( panner1_g62 + float2( 0,0.01 ) )*temp_output_13_0_g62 );
				simplePerlin2D8_g62 = simplePerlin2D8_g62*0.5 + 0.5;
				float4 appendResult9_g62 = (float4(( simplePerlin2D7_g62 - simplePerlin2D2_g62 ) , ( simplePerlin2D8_g62 - simplePerlin2D2_g62 ) , 0.0 , 0.0));
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner53_g61 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g61);
				float2 coords18_g61 = ( ( appendResult9_g62 * 0.1 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g61 = 0;
				float2 uv18_g61 = 0;
				float fade18_g61 = 0.5;
				float voroi18_g61 = 0;
				float rest18_g61 = 0;
				for( int it18_g61 = 0; it18_g61 <2; it18_g61++ ){
				voroi18_g61 += fade18_g61 * voronoi18_g61( coords18_g61, time18_g61, id18_g61, uv18_g61, 0,voronoiSmoothId18_g61 );
				rest18_g61 += fade18_g61;
				coords18_g61 *= 2;
				fade18_g61 *= 0.5;
				}//Voronoi18_g61
				voroi18_g61 /= rest18_g61;
				float mulTime3_g61 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g61 = mulTime3_g61;
				float2 voronoiSmoothId47_g61 = 0;
				float2 panner1_g63 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g61);
				float temp_output_13_0_g63 = 2.0;
				float simplePerlin2D7_g63 = snoise( ( panner1_g63 + float2( 0.01,0 ) )*temp_output_13_0_g63 );
				simplePerlin2D7_g63 = simplePerlin2D7_g63*0.5 + 0.5;
				float simplePerlin2D2_g63 = snoise( panner1_g63*temp_output_13_0_g63 );
				simplePerlin2D2_g63 = simplePerlin2D2_g63*0.5 + 0.5;
				float simplePerlin2D8_g63 = snoise( ( panner1_g63 + float2( 0,0.01 ) )*temp_output_13_0_g63 );
				simplePerlin2D8_g63 = simplePerlin2D8_g63*0.5 + 0.5;
				float4 appendResult9_g63 = (float4(( simplePerlin2D7_g63 - simplePerlin2D2_g63 ) , ( simplePerlin2D8_g63 - simplePerlin2D2_g63 ) , 0.0 , 0.0));
				float2 coords47_g61 = ( ( appendResult9_g63 * 2.0 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g61 = 0;
				float2 uv47_g61 = 0;
				float fade47_g61 = 0.5;
				float voroi47_g61 = 0;
				float rest47_g61 = 0;
				for( int it47_g61 = 0; it47_g61 <2; it47_g61++ ){
				voroi47_g61 += fade47_g61 * voronoi47_g61( coords47_g61, time47_g61, id47_g61, uv47_g61, 0,voronoiSmoothId47_g61 );
				rest47_g61 += fade47_g61;
				coords47_g61 *= 2;
				fade47_g61 *= 0.5;
				}//Voronoi47_g61
				voroi47_g61 /= rest47_g61;
				float screenDepth50_g61 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g61 = saturate( abs( ( screenDepth50_g61 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g61 = lerp( 1.0 , voroi47_g61 , pow( distanceDepth50_g61 , 0.1 ));
				float smoothstepResult44_g61 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g61);
				float CrustLevel45_g61 = saturate( smoothstepResult44_g61 );
				float temp_output_8_0_g61 = ( voroi18_g61 * pow( ( 1.0 - CrustLevel45_g61 ) , 100.0 ) );
				float height107_g65 = temp_output_8_0_g61;
				float scale107_g65 = 1.0;
				float3 localPerturbNormal107_g65 = PerturbNormal107_g65( surf_pos107_g65 , surf_norm107_g65 , height107_g65 , scale107_g65 );
				float3 worldToTangentDir42_g65 = mul( ase_worldToTangent, localPerturbNormal107_g65 );
				float3 CrustNormal65_g61 = worldToTangentDir42_g65;
				float dotResult124 = dot( WorldNormal , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				float3 normalizeResult148 = normalize( ( ( CrustNormal65_g51 * temp_output_128_0 ) + ( CrustNormal65_g56 * temp_output_129_0 ) + ( CrustNormal65_g61 * temp_output_130_0 ) ) );
				

				float3 Normal = normalizeResult148;
				float Alpha = 1;
				float AlphaClipThreshold = 0.5;

				#ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = input.positionCS.z;
				#endif

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
				#endif

				#if defined(_GBUFFER_NORMALS_OCT)
					float2 octNormalWS = PackNormalOctQuadEncode(WorldNormal);
					float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
					half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
					outNormalWS = half4(packedNormalWS, 0.0);
				#else
					#if defined(_NORMALMAP)
						#if _NORMAL_DROPOFF_TS
							float crossSign = (WorldTangent.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
							float3 bitangent = crossSign * cross(WorldNormal.xyz, WorldTangent.xyz);
							float3 normalWS = TransformTangentToWorld(Normal, half3x3(WorldTangent.xyz, bitangent, WorldNormal.xyz));
						#elif _NORMAL_DROPOFF_OS
							float3 normalWS = TransformObjectToWorldNormal(Normal);
						#elif _NORMAL_DROPOFF_WS
							float3 normalWS = Normal;
						#endif
					#else
						float3 normalWS = WorldNormal;
					#endif
					outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);
				#endif

				#ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
				#endif
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "GBuffer"
			Tags { "LightMode"="UniversalGBuffer" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite On
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA
			

			HLSLPROGRAM

			
            #pragma multi_compile_fragment _ALPHATEST_ON
            #define _NORMAL_DROPOFF_TS 1
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma instancing_options renderinglayer
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011
            #define REQUIRE_DEPTH_TEXTURE 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

			
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
           

			

			#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
			#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
			#pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

			
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
		

			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
			#pragma multi_compile _ SHADOWS_SHADOWMASK
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DYNAMICLIGHTMAP_ON

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SHADERPASS SHADERPASS_GBUFFER

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
				#define ENABLE_TERRAIN_PERPIXEL_NORMAL
			#endif

			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#define ASE_NEEDS_FRAG_SCREEN_POSITION
			#define ASE_NEEDS_FRAG_WORLD_TANGENT
			#define ASE_NEEDS_FRAG_WORLD_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_BITANGENT
			#pragma multi_compile_instancing


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				float4 lightmapUVOrVertexSH : TEXCOORD1;
				#if defined(ASE_FOG) || defined(_ADDITIONAL_LIGHTS_VERTEX)
					half4 fogFactorAndVertexLight : TEXCOORD2;
				#endif
				float4 tSpace0 : TEXCOORD3;
				float4 tSpace1 : TEXCOORD4;
				float4 tSpace2 : TEXCOORD5;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
				float4 shadowCoord : TEXCOORD6;
				#endif
				#if defined(DYNAMICLIGHTMAP_ON)
				float2 dynamicLightmapUV : TEXCOORD7;
				#endif
				float4 ase_texcoord8 : TEXCOORD8;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
				UNITY_DEFINE_INSTANCED_PROP(float4, _CrustColor)
				UNITY_DEFINE_INSTANCED_PROP(float4, _LavaColor)
				UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash47_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
			inline float2 ParallaxOffset( half h, half height, half3 viewDir )
			{
				h = h * height - height/2.0;
				float3 v = normalize( viewDir );
				v.z += 0.42;
				return h* (v.xy / v.z);
			}
			
					float2 voronoihash47_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash47_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi47_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash47_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash39_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi39_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash39_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash18_g51( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g51( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g51( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
			float3 PerturbNormal107_g55( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			
					float2 voronoihash18_g56( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g56( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g56( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
			float3 PerturbNormal107_g60( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			
					float2 voronoihash18_g61( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi18_g61( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash18_g61( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F2;
					}
			
			float3 PerturbNormal107_g65( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				output.ase_texcoord8.xy = input.texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord8.zw = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;
				input.tangentOS = input.tangentOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );
				VertexNormalInputs normalInput = GetVertexNormalInputs( input.normalOS, input.tangentOS );

				output.tSpace0 = float4( normalInput.normalWS, vertexInput.positionWS.x);
				output.tSpace1 = float4( normalInput.tangentWS, vertexInput.positionWS.y);
				output.tSpace2 = float4( normalInput.bitangentWS, vertexInput.positionWS.z);

				#if defined(LIGHTMAP_ON)
					OUTPUT_LIGHTMAP_UV(input.texcoord1, unity_LightmapST, output.lightmapUVOrVertexSH.xy);
				#endif

				#if defined(DYNAMICLIGHTMAP_ON)
					output.dynamicLightmapUV.xy = input.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				#endif

				#if !defined(LIGHTMAP_ON)
					OUTPUT_SH(normalInput.normalWS.xyz, output.lightmapUVOrVertexSH.xyz);
				#endif

				#if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					output.lightmapUVOrVertexSH.zw = input.texcoord.xy;
					output.lightmapUVOrVertexSH.xy = input.texcoord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif

				#if defined(ASE_FOG) || defined(_ADDITIONAL_LIGHTS_VERTEX)
					output.fogFactorAndVertexLight = 0;
					#if defined(ASE_FOG) && !defined(_FOG_FRAGMENT)
						// @diogo: no fog applied in GBuffer
					#endif
					#ifdef _ADDITIONAL_LIGHTS_VERTEX
						half3 vertexLight = VertexLighting( vertexInput.positionWS, normalInput.normalWS );
						output.fogFactorAndVertexLight.yzw = vertexLight;
					#endif
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					output.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				output.positionCS = vertexInput.positionCS;
				output.clipPosV = vertexInput.positionCS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				output.tangentOS = input.tangentOS;
				output.texcoord = input.texcoord;
				output.texcoord1 = input.texcoord1;
				output.texcoord2 = input.texcoord2;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				output.tangentOS = patch[0].tangentOS * bary.x + patch[1].tangentOS * bary.y + patch[2].tangentOS * bary.z;
				output.texcoord = patch[0].texcoord * bary.x + patch[1].texcoord * bary.y + patch[2].texcoord * bary.z;
				output.texcoord1 = patch[0].texcoord1 * bary.x + patch[1].texcoord1 * bary.y + patch[2].texcoord1 * bary.z;
				output.texcoord2 = patch[0].texcoord2 * bary.x + patch[1].texcoord2 * bary.y + patch[2].texcoord2 * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			FragmentOutput frag ( PackedVaryings input
								#ifdef ASE_DEPTH_WRITE_ON
								,out float outputDepth : ASE_SV_DEPTH
								#endif
								 )
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float2 sampleCoords = (input.lightmapUVOrVertexSH.zw / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
					float3 WorldNormal = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
					float3 WorldTangent = -cross(GetObjectToWorldMatrix()._13_23_33, WorldNormal);
					float3 WorldBiTangent = cross(WorldNormal, -WorldTangent);
				#else
					float3 WorldNormal = normalize( input.tSpace0.xyz );
					float3 WorldTangent = input.tSpace1.xyz;
					float3 WorldBiTangent = input.tSpace2.xyz;
				#endif

				float3 WorldPosition = float3(input.tSpace0.w,input.tSpace1.w,input.tSpace2.w);
				float3 WorldViewDirection = GetWorldSpaceNormalizeViewDir( WorldPosition );
				float4 ShadowCoords = float4( 0, 0, 0, 0 );
				float4 ClipPos = input.clipPosV;
				float4 ScreenPos = ComputeScreenPos( input.clipPosV );

				float2 NormalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					ShadowCoords = input.shadowCoord;
				#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
				#else
					ShadowCoords = float4(0, 0, 0, 0);
				#endif

				float4 _CrustColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_CrustColor);
				float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_TurbulenceSpeed);
				float mulTime3_g51 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g51 = mulTime3_g51;
				float2 voronoiSmoothId47_g51 = 0;
				float3 break154 = ( WorldPosition * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner53_g51 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g51);
				float2 panner1_g53 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g51);
				float temp_output_13_0_g53 = 2.0;
				float simplePerlin2D7_g53 = snoise( ( panner1_g53 + float2( 0.01,0 ) )*temp_output_13_0_g53 );
				simplePerlin2D7_g53 = simplePerlin2D7_g53*0.5 + 0.5;
				float simplePerlin2D2_g53 = snoise( panner1_g53*temp_output_13_0_g53 );
				simplePerlin2D2_g53 = simplePerlin2D2_g53*0.5 + 0.5;
				float simplePerlin2D8_g53 = snoise( ( panner1_g53 + float2( 0,0.01 ) )*temp_output_13_0_g53 );
				simplePerlin2D8_g53 = simplePerlin2D8_g53*0.5 + 0.5;
				float4 appendResult9_g53 = (float4(( simplePerlin2D7_g53 - simplePerlin2D2_g53 ) , ( simplePerlin2D8_g53 - simplePerlin2D2_g53 ) , 0.0 , 0.0));
				float2 coords47_g51 = ( ( appendResult9_g53 * 2.0 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g51 = 0;
				float2 uv47_g51 = 0;
				float fade47_g51 = 0.5;
				float voroi47_g51 = 0;
				float rest47_g51 = 0;
				for( int it47_g51 = 0; it47_g51 <2; it47_g51++ ){
				voroi47_g51 += fade47_g51 * voronoi47_g51( coords47_g51, time47_g51, id47_g51, uv47_g51, 0,voronoiSmoothId47_g51 );
				rest47_g51 += fade47_g51;
				coords47_g51 *= 2;
				fade47_g51 *= 0.5;
				}//Voronoi47_g51
				voroi47_g51 /= rest47_g51;
				float4 ase_positionSSNorm = ScreenPos / ScreenPos.w;
				ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
				float screenDepth50_g51 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g51 = saturate( abs( ( screenDepth50_g51 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g51 = lerp( 1.0 , voroi47_g51 , pow( distanceDepth50_g51 , 0.1 ));
				float smoothstepResult44_g51 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g51);
				float CrustLevel45_g51 = saturate( smoothstepResult44_g51 );
				float4 _LavaColor_Instance = UNITY_ACCESS_INSTANCED_PROP(UMSLavaTriplanar,_LavaColor);
				float time39_g51 = _TimeParameters.x;
				float2 voronoiSmoothId39_g51 = 0;
				float3 tanToWorld0 = float3( WorldTangent.x, WorldBiTangent.x, WorldNormal.x );
				float3 tanToWorld1 = float3( WorldTangent.y, WorldBiTangent.y, WorldNormal.y );
				float3 tanToWorld2 = float3( WorldTangent.z, WorldBiTangent.z, WorldNormal.z );
				float3 ase_viewVectorTS =  tanToWorld0 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).x + tanToWorld1 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).y  + tanToWorld2 * ( _WorldSpaceCameraPos.xyz - WorldPosition ).z;
				float3 ase_viewDirTS = normalize( ase_viewVectorTS );
				float2 paralaxOffset34_g51 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g51 = ( panner53_g51 + paralaxOffset34_g51 );
				float2 panner1_g54 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g51);
				float temp_output_13_0_g54 = 2.0;
				float simplePerlin2D7_g54 = snoise( ( panner1_g54 + float2( 0.01,0 ) )*temp_output_13_0_g54 );
				simplePerlin2D7_g54 = simplePerlin2D7_g54*0.5 + 0.5;
				float simplePerlin2D2_g54 = snoise( panner1_g54*temp_output_13_0_g54 );
				simplePerlin2D2_g54 = simplePerlin2D2_g54*0.5 + 0.5;
				float simplePerlin2D8_g54 = snoise( ( panner1_g54 + float2( 0,0.01 ) )*temp_output_13_0_g54 );
				simplePerlin2D8_g54 = simplePerlin2D8_g54*0.5 + 0.5;
				float4 appendResult9_g54 = (float4(( simplePerlin2D7_g54 - simplePerlin2D2_g54 ) , ( simplePerlin2D8_g54 - simplePerlin2D2_g54 ) , 0.0 , 0.0));
				float2 coords39_g51 = ( ( appendResult9_g54 * 4.0 ) + float4( temp_output_54_0_g51, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g51 = 0;
				float2 uv39_g51 = 0;
				float fade39_g51 = 0.5;
				float voroi39_g51 = 0;
				float rest39_g51 = 0;
				for( int it39_g51 = 0; it39_g51 <5; it39_g51++ ){
				voroi39_g51 += fade39_g51 * voronoi39_g51( coords39_g51, time39_g51, id39_g51, uv39_g51, 0,voronoiSmoothId39_g51 );
				rest39_g51 += fade39_g51;
				coords39_g51 *= 2;
				fade39_g51 *= 0.5;
				}//Voronoi39_g51
				voroi39_g51 /= rest39_g51;
				float4 lerpResult10_g51 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g51 ) * (0.5 + (pow( saturate( ( voroi47_g51 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g51 ) , CrustLevel45_g51);
				float dotResult113 = dot( WorldNormal , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float mulTime3_g56 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g56 = mulTime3_g56;
				float2 voronoiSmoothId47_g56 = 0;
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner53_g56 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g56);
				float2 panner1_g58 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g56);
				float temp_output_13_0_g58 = 2.0;
				float simplePerlin2D7_g58 = snoise( ( panner1_g58 + float2( 0.01,0 ) )*temp_output_13_0_g58 );
				simplePerlin2D7_g58 = simplePerlin2D7_g58*0.5 + 0.5;
				float simplePerlin2D2_g58 = snoise( panner1_g58*temp_output_13_0_g58 );
				simplePerlin2D2_g58 = simplePerlin2D2_g58*0.5 + 0.5;
				float simplePerlin2D8_g58 = snoise( ( panner1_g58 + float2( 0,0.01 ) )*temp_output_13_0_g58 );
				simplePerlin2D8_g58 = simplePerlin2D8_g58*0.5 + 0.5;
				float4 appendResult9_g58 = (float4(( simplePerlin2D7_g58 - simplePerlin2D2_g58 ) , ( simplePerlin2D8_g58 - simplePerlin2D2_g58 ) , 0.0 , 0.0));
				float2 coords47_g56 = ( ( appendResult9_g58 * 2.0 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g56 = 0;
				float2 uv47_g56 = 0;
				float fade47_g56 = 0.5;
				float voroi47_g56 = 0;
				float rest47_g56 = 0;
				for( int it47_g56 = 0; it47_g56 <2; it47_g56++ ){
				voroi47_g56 += fade47_g56 * voronoi47_g56( coords47_g56, time47_g56, id47_g56, uv47_g56, 0,voronoiSmoothId47_g56 );
				rest47_g56 += fade47_g56;
				coords47_g56 *= 2;
				fade47_g56 *= 0.5;
				}//Voronoi47_g56
				voroi47_g56 /= rest47_g56;
				float screenDepth50_g56 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g56 = saturate( abs( ( screenDepth50_g56 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g56 = lerp( 1.0 , voroi47_g56 , pow( distanceDepth50_g56 , 0.1 ));
				float smoothstepResult44_g56 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g56);
				float CrustLevel45_g56 = saturate( smoothstepResult44_g56 );
				float time39_g56 = _TimeParameters.x;
				float2 voronoiSmoothId39_g56 = 0;
				float2 paralaxOffset34_g56 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g56 = ( panner53_g56 + paralaxOffset34_g56 );
				float2 panner1_g59 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g56);
				float temp_output_13_0_g59 = 2.0;
				float simplePerlin2D7_g59 = snoise( ( panner1_g59 + float2( 0.01,0 ) )*temp_output_13_0_g59 );
				simplePerlin2D7_g59 = simplePerlin2D7_g59*0.5 + 0.5;
				float simplePerlin2D2_g59 = snoise( panner1_g59*temp_output_13_0_g59 );
				simplePerlin2D2_g59 = simplePerlin2D2_g59*0.5 + 0.5;
				float simplePerlin2D8_g59 = snoise( ( panner1_g59 + float2( 0,0.01 ) )*temp_output_13_0_g59 );
				simplePerlin2D8_g59 = simplePerlin2D8_g59*0.5 + 0.5;
				float4 appendResult9_g59 = (float4(( simplePerlin2D7_g59 - simplePerlin2D2_g59 ) , ( simplePerlin2D8_g59 - simplePerlin2D2_g59 ) , 0.0 , 0.0));
				float2 coords39_g56 = ( ( appendResult9_g59 * 4.0 ) + float4( temp_output_54_0_g56, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g56 = 0;
				float2 uv39_g56 = 0;
				float fade39_g56 = 0.5;
				float voroi39_g56 = 0;
				float rest39_g56 = 0;
				for( int it39_g56 = 0; it39_g56 <5; it39_g56++ ){
				voroi39_g56 += fade39_g56 * voronoi39_g56( coords39_g56, time39_g56, id39_g56, uv39_g56, 0,voronoiSmoothId39_g56 );
				rest39_g56 += fade39_g56;
				coords39_g56 *= 2;
				fade39_g56 *= 0.5;
				}//Voronoi39_g56
				voroi39_g56 /= rest39_g56;
				float4 lerpResult10_g56 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g56 ) * (0.5 + (pow( saturate( ( voroi47_g56 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g56 ) , CrustLevel45_g56);
				float dotResult119 = dot( WorldNormal , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float mulTime3_g61 = _TimeParameters.x * _TurbulenceSpeed_Instance;
				float time47_g61 = mulTime3_g61;
				float2 voronoiSmoothId47_g61 = 0;
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner53_g61 = ( 1.0 * _Time.y * _ScrollSpeed + temp_output_66_0_g61);
				float2 panner1_g63 = ( _TimeParameters.x * float2( 0,0 ) + panner53_g61);
				float temp_output_13_0_g63 = 2.0;
				float simplePerlin2D7_g63 = snoise( ( panner1_g63 + float2( 0.01,0 ) )*temp_output_13_0_g63 );
				simplePerlin2D7_g63 = simplePerlin2D7_g63*0.5 + 0.5;
				float simplePerlin2D2_g63 = snoise( panner1_g63*temp_output_13_0_g63 );
				simplePerlin2D2_g63 = simplePerlin2D2_g63*0.5 + 0.5;
				float simplePerlin2D8_g63 = snoise( ( panner1_g63 + float2( 0,0.01 ) )*temp_output_13_0_g63 );
				simplePerlin2D8_g63 = simplePerlin2D8_g63*0.5 + 0.5;
				float4 appendResult9_g63 = (float4(( simplePerlin2D7_g63 - simplePerlin2D2_g63 ) , ( simplePerlin2D8_g63 - simplePerlin2D2_g63 ) , 0.0 , 0.0));
				float2 coords47_g61 = ( ( appendResult9_g63 * 2.0 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id47_g61 = 0;
				float2 uv47_g61 = 0;
				float fade47_g61 = 0.5;
				float voroi47_g61 = 0;
				float rest47_g61 = 0;
				for( int it47_g61 = 0; it47_g61 <2; it47_g61++ ){
				voroi47_g61 += fade47_g61 * voronoi47_g61( coords47_g61, time47_g61, id47_g61, uv47_g61, 0,voronoiSmoothId47_g61 );
				rest47_g61 += fade47_g61;
				coords47_g61 *= 2;
				fade47_g61 *= 0.5;
				}//Voronoi47_g61
				voroi47_g61 /= rest47_g61;
				float screenDepth50_g61 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_positionSSNorm.xy ),_ZBufferParams);
				float distanceDepth50_g61 = saturate( abs( ( screenDepth50_g61 - LinearEyeDepth( ase_positionSSNorm.z,_ZBufferParams ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
				float lerpResult48_g61 = lerp( 1.0 , voroi47_g61 , pow( distanceDepth50_g61 , 0.1 ));
				float smoothstepResult44_g61 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g61);
				float CrustLevel45_g61 = saturate( smoothstepResult44_g61 );
				float time39_g61 = _TimeParameters.x;
				float2 voronoiSmoothId39_g61 = 0;
				float2 paralaxOffset34_g61 = ParallaxOffset( 1 , _LavaParallaxDepth , ase_viewDirTS );
				float2 temp_output_54_0_g61 = ( panner53_g61 + paralaxOffset34_g61 );
				float2 panner1_g64 = ( _TimeParameters.x * float2( 0,0 ) + temp_output_54_0_g61);
				float temp_output_13_0_g64 = 2.0;
				float simplePerlin2D7_g64 = snoise( ( panner1_g64 + float2( 0.01,0 ) )*temp_output_13_0_g64 );
				simplePerlin2D7_g64 = simplePerlin2D7_g64*0.5 + 0.5;
				float simplePerlin2D2_g64 = snoise( panner1_g64*temp_output_13_0_g64 );
				simplePerlin2D2_g64 = simplePerlin2D2_g64*0.5 + 0.5;
				float simplePerlin2D8_g64 = snoise( ( panner1_g64 + float2( 0,0.01 ) )*temp_output_13_0_g64 );
				simplePerlin2D8_g64 = simplePerlin2D8_g64*0.5 + 0.5;
				float4 appendResult9_g64 = (float4(( simplePerlin2D7_g64 - simplePerlin2D2_g64 ) , ( simplePerlin2D8_g64 - simplePerlin2D2_g64 ) , 0.0 , 0.0));
				float2 coords39_g61 = ( ( appendResult9_g64 * 4.0 ) + float4( temp_output_54_0_g61, 0.0 , 0.0 ) ).xy * 1.0;
				float2 id39_g61 = 0;
				float2 uv39_g61 = 0;
				float fade39_g61 = 0.5;
				float voroi39_g61 = 0;
				float rest39_g61 = 0;
				for( int it39_g61 = 0; it39_g61 <5; it39_g61++ ){
				voroi39_g61 += fade39_g61 * voronoi39_g61( coords39_g61, time39_g61, id39_g61, uv39_g61, 0,voronoiSmoothId39_g61 );
				rest39_g61 += fade39_g61;
				coords39_g61 *= 2;
				fade39_g61 *= 0.5;
				}//Voronoi39_g61
				voroi39_g61 /= rest39_g61;
				float4 lerpResult10_g61 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel45_g61 ) * (0.5 + (pow( saturate( ( voroi47_g61 * 10.0 ) ) , 3.0 ) - 0.0) * (1.0 - 0.5) / (1.0 - 0.0)) ) , ( _LavaColor_Instance * voroi39_g61 ) , CrustLevel45_g61);
				float dotResult124 = dot( WorldNormal , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				
				float3 surf_pos107_g55 = WorldPosition;
				float3 surf_norm107_g55 = WorldNormal;
				float time18_g51 = 0.0;
				float2 voronoiSmoothId18_g51 = 0;
				float2 texCoord3_g52 = input.ase_texcoord8.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g52 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g52);
				float temp_output_13_0_g52 = 30.0;
				float simplePerlin2D7_g52 = snoise( ( panner1_g52 + float2( 0.01,0 ) )*temp_output_13_0_g52 );
				simplePerlin2D7_g52 = simplePerlin2D7_g52*0.5 + 0.5;
				float simplePerlin2D2_g52 = snoise( panner1_g52*temp_output_13_0_g52 );
				simplePerlin2D2_g52 = simplePerlin2D2_g52*0.5 + 0.5;
				float simplePerlin2D8_g52 = snoise( ( panner1_g52 + float2( 0,0.01 ) )*temp_output_13_0_g52 );
				simplePerlin2D8_g52 = simplePerlin2D8_g52*0.5 + 0.5;
				float4 appendResult9_g52 = (float4(( simplePerlin2D7_g52 - simplePerlin2D2_g52 ) , ( simplePerlin2D8_g52 - simplePerlin2D2_g52 ) , 0.0 , 0.0));
				float2 coords18_g51 = ( ( appendResult9_g52 * 0.1 ) + float4( panner53_g51, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g51 = 0;
				float2 uv18_g51 = 0;
				float fade18_g51 = 0.5;
				float voroi18_g51 = 0;
				float rest18_g51 = 0;
				for( int it18_g51 = 0; it18_g51 <2; it18_g51++ ){
				voroi18_g51 += fade18_g51 * voronoi18_g51( coords18_g51, time18_g51, id18_g51, uv18_g51, 0,voronoiSmoothId18_g51 );
				rest18_g51 += fade18_g51;
				coords18_g51 *= 2;
				fade18_g51 *= 0.5;
				}//Voronoi18_g51
				voroi18_g51 /= rest18_g51;
				float temp_output_8_0_g51 = ( voroi18_g51 * pow( ( 1.0 - CrustLevel45_g51 ) , 100.0 ) );
				float height107_g55 = temp_output_8_0_g51;
				float scale107_g55 = 1.0;
				float3 localPerturbNormal107_g55 = PerturbNormal107_g55( surf_pos107_g55 , surf_norm107_g55 , height107_g55 , scale107_g55 );
				float3x3 ase_worldToTangent = float3x3( WorldTangent, WorldBiTangent, WorldNormal );
				float3 worldToTangentDir42_g55 = mul( ase_worldToTangent, localPerturbNormal107_g55 );
				float3 CrustNormal65_g51 = worldToTangentDir42_g55;
				float3 surf_pos107_g60 = WorldPosition;
				float3 surf_norm107_g60 = WorldNormal;
				float time18_g56 = 0.0;
				float2 voronoiSmoothId18_g56 = 0;
				float2 texCoord3_g57 = input.ase_texcoord8.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g57 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g57);
				float temp_output_13_0_g57 = 30.0;
				float simplePerlin2D7_g57 = snoise( ( panner1_g57 + float2( 0.01,0 ) )*temp_output_13_0_g57 );
				simplePerlin2D7_g57 = simplePerlin2D7_g57*0.5 + 0.5;
				float simplePerlin2D2_g57 = snoise( panner1_g57*temp_output_13_0_g57 );
				simplePerlin2D2_g57 = simplePerlin2D2_g57*0.5 + 0.5;
				float simplePerlin2D8_g57 = snoise( ( panner1_g57 + float2( 0,0.01 ) )*temp_output_13_0_g57 );
				simplePerlin2D8_g57 = simplePerlin2D8_g57*0.5 + 0.5;
				float4 appendResult9_g57 = (float4(( simplePerlin2D7_g57 - simplePerlin2D2_g57 ) , ( simplePerlin2D8_g57 - simplePerlin2D2_g57 ) , 0.0 , 0.0));
				float2 coords18_g56 = ( ( appendResult9_g57 * 0.1 ) + float4( panner53_g56, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g56 = 0;
				float2 uv18_g56 = 0;
				float fade18_g56 = 0.5;
				float voroi18_g56 = 0;
				float rest18_g56 = 0;
				for( int it18_g56 = 0; it18_g56 <2; it18_g56++ ){
				voroi18_g56 += fade18_g56 * voronoi18_g56( coords18_g56, time18_g56, id18_g56, uv18_g56, 0,voronoiSmoothId18_g56 );
				rest18_g56 += fade18_g56;
				coords18_g56 *= 2;
				fade18_g56 *= 0.5;
				}//Voronoi18_g56
				voroi18_g56 /= rest18_g56;
				float temp_output_8_0_g56 = ( voroi18_g56 * pow( ( 1.0 - CrustLevel45_g56 ) , 100.0 ) );
				float height107_g60 = temp_output_8_0_g56;
				float scale107_g60 = 1.0;
				float3 localPerturbNormal107_g60 = PerturbNormal107_g60( surf_pos107_g60 , surf_norm107_g60 , height107_g60 , scale107_g60 );
				float3 worldToTangentDir42_g60 = mul( ase_worldToTangent, localPerturbNormal107_g60 );
				float3 CrustNormal65_g56 = worldToTangentDir42_g60;
				float3 surf_pos107_g65 = WorldPosition;
				float3 surf_norm107_g65 = WorldNormal;
				float time18_g61 = 0.0;
				float2 voronoiSmoothId18_g61 = 0;
				float2 texCoord3_g62 = input.ase_texcoord8.xy * float2( 1,1 ) + float2( 0,0 );
				float2 panner1_g62 = ( _TimeParameters.x * float2( 0,0 ) + texCoord3_g62);
				float temp_output_13_0_g62 = 30.0;
				float simplePerlin2D7_g62 = snoise( ( panner1_g62 + float2( 0.01,0 ) )*temp_output_13_0_g62 );
				simplePerlin2D7_g62 = simplePerlin2D7_g62*0.5 + 0.5;
				float simplePerlin2D2_g62 = snoise( panner1_g62*temp_output_13_0_g62 );
				simplePerlin2D2_g62 = simplePerlin2D2_g62*0.5 + 0.5;
				float simplePerlin2D8_g62 = snoise( ( panner1_g62 + float2( 0,0.01 ) )*temp_output_13_0_g62 );
				simplePerlin2D8_g62 = simplePerlin2D8_g62*0.5 + 0.5;
				float4 appendResult9_g62 = (float4(( simplePerlin2D7_g62 - simplePerlin2D2_g62 ) , ( simplePerlin2D8_g62 - simplePerlin2D2_g62 ) , 0.0 , 0.0));
				float2 coords18_g61 = ( ( appendResult9_g62 * 0.1 ) + float4( panner53_g61, 0.0 , 0.0 ) ).xy * 3.0;
				float2 id18_g61 = 0;
				float2 uv18_g61 = 0;
				float fade18_g61 = 0.5;
				float voroi18_g61 = 0;
				float rest18_g61 = 0;
				for( int it18_g61 = 0; it18_g61 <2; it18_g61++ ){
				voroi18_g61 += fade18_g61 * voronoi18_g61( coords18_g61, time18_g61, id18_g61, uv18_g61, 0,voronoiSmoothId18_g61 );
				rest18_g61 += fade18_g61;
				coords18_g61 *= 2;
				fade18_g61 *= 0.5;
				}//Voronoi18_g61
				voroi18_g61 /= rest18_g61;
				float temp_output_8_0_g61 = ( voroi18_g61 * pow( ( 1.0 - CrustLevel45_g61 ) , 100.0 ) );
				float height107_g65 = temp_output_8_0_g61;
				float scale107_g65 = 1.0;
				float3 localPerturbNormal107_g65 = PerturbNormal107_g65( surf_pos107_g65 , surf_norm107_g65 , height107_g65 , scale107_g65 );
				float3 worldToTangentDir42_g65 = mul( ase_worldToTangent, localPerturbNormal107_g65 );
				float3 CrustNormal65_g61 = worldToTangentDir42_g65;
				float3 normalizeResult148 = normalize( ( ( CrustNormal65_g51 * temp_output_128_0 ) + ( CrustNormal65_g56 * temp_output_129_0 ) + ( CrustNormal65_g61 * temp_output_130_0 ) ) );
				
				float4 LavaEmission7_g51 = ( _LavaColor_Instance * voroi39_g51 * smoothstepResult44_g51 );
				float4 LavaEmission7_g56 = ( _LavaColor_Instance * voroi39_g56 * smoothstepResult44_g56 );
				float4 LavaEmission7_g61 = ( _LavaColor_Instance * voroi39_g61 * smoothstepResult44_g61 );
				
				float lerpResult42_g51 = lerp( ( pow( temp_output_8_0_g51 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g51);
				float lerpResult42_g56 = lerp( ( pow( temp_output_8_0_g56 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g56);
				float lerpResult42_g61 = lerp( ( pow( temp_output_8_0_g61 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g61);
				

				float3 BaseColor = ( ( lerpResult10_g51 * temp_output_128_0 ) + ( lerpResult10_g56 * temp_output_129_0 ) + ( lerpResult10_g61 * temp_output_130_0 ) ).rgb;
				float3 Normal = normalizeResult148;
				float3 Emission = ( ( LavaEmission7_g51 * temp_output_128_0 ) + ( LavaEmission7_g56 * temp_output_129_0 ) + ( LavaEmission7_g61 * temp_output_130_0 ) ).rgb;
				float3 Specular = 0.5;
				float Metallic = 0;
				float Smoothness = ( ( lerpResult42_g51 * temp_output_128_0 ) + ( lerpResult42_g56 * temp_output_129_0 ) + ( lerpResult42_g61 * temp_output_130_0 ) );
				float Occlusion = 1;
				float Alpha = 1;
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;
				float3 BakedGI = 0;
				float3 RefractionColor = 1;
				float RefractionIndex = 1;
				float3 Transmission = 1;
				float3 Translucency = 1;

				#ifdef ASE_DEPTH_WRITE_ON
					float DepthValue = input.positionCS.z;
				#endif

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				InputData inputData = (InputData)0;
				inputData.positionWS = WorldPosition;
				inputData.positionCS = input.positionCS;
				inputData.shadowCoord = ShadowCoords;

				#ifdef _NORMALMAP
					#if _NORMAL_DROPOFF_TS
						inputData.normalWS = TransformTangentToWorld(Normal, half3x3( WorldTangent, WorldBiTangent, WorldNormal ));
					#elif _NORMAL_DROPOFF_OS
						inputData.normalWS = TransformObjectToWorldNormal(Normal);
					#elif _NORMAL_DROPOFF_WS
						inputData.normalWS = Normal;
					#endif
				#else
					inputData.normalWS = WorldNormal;
				#endif

				inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
				inputData.viewDirectionWS = SafeNormalize( WorldViewDirection );

				#ifdef ASE_FOG
					// @diogo: no fog applied in GBuffer
				#endif
				#ifdef _ADDITIONAL_LIGHTS_VERTEX
					inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
				#endif

				#if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
					float3 SH = SampleSH(inputData.normalWS.xyz);
				#else
					float3 SH = input.lightmapUVOrVertexSH.xyz;
				#endif

				#ifdef ASE_BAKEDGI
					inputData.bakedGI = BakedGI;
				#else
					#if defined(DYNAMICLIGHTMAP_ON)
						inputData.bakedGI = SAMPLE_GI( input.lightmapUVOrVertexSH.xy, input.dynamicLightmapUV.xy, SH, inputData.normalWS);
					#else
						inputData.bakedGI = SAMPLE_GI( input.lightmapUVOrVertexSH.xy, SH, inputData.normalWS );
					#endif
				#endif

				inputData.normalizedScreenSpaceUV = NormalizedScreenSpaceUV;
				inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUVOrVertexSH.xy);

				#if defined(DEBUG_DISPLAY)
					#if defined(DYNAMICLIGHTMAP_ON)
						inputData.dynamicLightmapUV = input.dynamicLightmapUV.xy;
						#endif
					#if defined(LIGHTMAP_ON)
						inputData.staticLightmapUV = input.lightmapUVOrVertexSH.xy;
					#else
						inputData.vertexSH = SH;
					#endif
				#endif

				#ifdef _DBUFFER
					ApplyDecal(input.positionCS,
						BaseColor,
						Specular,
						inputData.normalWS,
						Metallic,
						Occlusion,
						Smoothness);
				#endif

				BRDFData brdfData;
				InitializeBRDFData
				(BaseColor, Metallic, Specular, Smoothness, Alpha, brdfData);

				Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
				half4 color;
				MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
				color.rgb = GlobalIllumination(brdfData, inputData.bakedGI, Occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
				color.a = Alpha;

				#ifdef ASE_FINAL_COLOR_ALPHA_MULTIPLY
					color.rgb *= color.a;
				#endif

				#ifdef ASE_DEPTH_WRITE_ON
					outputDepth = DepthValue;
				#endif

				return BRDFDataToGbuffer(brdfData, inputData, Smoothness, Emission + color.rgb, Occlusion);
			}

			ENDHLSL
		}

		
		Pass
		{
			
			Name "SceneSelectionPass"
			Tags { "LightMode"="SceneSelectionPass" }

			Cull Off
			AlphaToMask Off

			HLSLPROGRAM

			
            #define _NORMAL_DROPOFF_TS 1
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

			#define SCENESELECTIONPASS 1

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define SHADERPASS SHADERPASS_DEPTHONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

			

			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#define ASE_NEEDS_VERT_NORMAL


			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			PackedVaryings VertexFunction(Attributes input  )
			{
				PackedVaryings output;
				ZERO_INITIALIZE(PackedVaryings, output);

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				float3 positionWS = TransformObjectToWorld( input.positionOS.xyz );

				output.positionCS = TransformWorldToHClip(positionWS);

				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input ) : SV_Target
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				

				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = 0;

				#ifdef SCENESELECTIONPASS
					outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
				#elif defined(SCENEPICKINGPASS)
					outColor = _SelectionID;
				#endif

				return outColor;
			}

			ENDHLSL
		}

		
		Pass
		{
			
			Name "ScenePickingPass"
			Tags { "LightMode"="Picking" }

			AlphaToMask Off

			HLSLPROGRAM

			
            #define _NORMAL_DROPOFF_TS 1
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define _EMISSION
            #define _NORMALMAP 1
            #define ASE_VERSION 19801
            #define ASE_SRP_VERSION 140011


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma vertex vert
			#pragma fragment frag

			#if defined(_SPECULAR_SETUP) && defined(_ASE_LIGHTING_SIMPLE)
				#define _SPECULAR_COLOR 1
			#endif

		    #define SCENEPICKINGPASS 1

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define SHADERPASS SHADERPASS_DEPTHONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

			

			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#define ASE_NEEDS_VERT_NORMAL


			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float2 _Wavescrollspeed;
			float2 _ScrollSpeed;
			float _OverallScale;
			float _Lavawavetiling;
			float _Lavawaveoffset;
			float _LavaLevel;
			float _CrustLevel;
			float _CrustFadeDistance;
			float _LavaParallaxDepth;
			float _Crustsmoothness;
			float _Lavasmoothness;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			UNITY_INSTANCING_BUFFER_START(UMSLavaTriplanar)
			UNITY_INSTANCING_BUFFER_END(UMSLavaTriplanar)


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			PackedVaryings VertexFunction(Attributes input  )
			{
				PackedVaryings output;
				ZERO_INITIALIZE(PackedVaryings, output);

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				float3 break154 = ( ase_positionWS * _OverallScale );
				float2 appendResult109 = (float2(break154.x , break154.z));
				float2 temp_output_66_0_g51 = appendResult109;
				float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
				float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
				simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
				float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
				float2 appendResult117 = (float2(break154.x , break154.y));
				float2 temp_output_66_0_g56 = appendResult117;
				float2 panner82_g56 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g56);
				float simplePerlin2D79_g56 = snoise( panner82_g56*_Lavawavetiling );
				simplePerlin2D79_g56 = simplePerlin2D79_g56*0.5 + 0.5;
				float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
				float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
				float2 appendResult121 = (float2(break154.z , break154.y));
				float2 temp_output_66_0_g61 = appendResult121;
				float2 panner82_g61 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g61);
				float simplePerlin2D79_g61 = snoise( panner82_g61*_Lavawavetiling );
				simplePerlin2D79_g61 = simplePerlin2D79_g61*0.5 + 0.5;
				float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
				float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = ( ( ( simplePerlin2D79_g51 * input.normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * input.normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * input.normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				float3 positionWS = TransformObjectToWorld( input.positionOS.xyz );
				output.positionCS = TransformWorldToHClip(positionWS);

				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input ) : SV_Target
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				

				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
						clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = 0;

				#ifdef SCENESELECTIONPASS
					outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
				#elif defined(SCENEPICKINGPASS)
					outColor = _SelectionID;
				#endif

				return outColor;
			}

			ENDHLSL
		}
		
	}
	
	CustomEditor "UnityEditor.ShaderGraphLitGUI"
	FallBack "Hidden/Shader Graph/FallbackError"
	
	Fallback Off
}
/*ASEBEGIN
Version=19801
Node;AmplifyShaderEditor.WorldPosInputsNode;13;-6752,-880;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;99;-6560,-656;Inherit;False;Property;_OverallScale;OverallScale;0;0;Create;True;0;0;0;False;0;False;1;1.5;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.WorldNormalVector;114;-6224,-496;Inherit;False;False;1;0;FLOAT3;0,0,1;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;153;-6496,-1040;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DotProductOpNode;113;-5840,-496;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,1,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;119;-5856,-336;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;124;-5840,-176;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;1,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;154;-6288,-1040;Inherit;False;FLOAT3;1;0;FLOAT3;0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.AbsOpNode;118;-5664,-336;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;123;-5664,-176;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;116;-5600,-512;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;131;-5760,0;Inherit;False;Constant;_Float3;Float 3;12;0;Create;True;0;0;0;False;0;False;5;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;109;-5952,-1024;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;117;-5936,-880;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;121;-5968,-704;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.PowerNode;128;-5440,-432;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;130;-5440,-208;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;141;-5584,-1088;Inherit;False;LavaBase;1;;51;f88859ea02d1de9418d963f1a1027734;0;1;66;FLOAT2;0,0;False;5;COLOR;69;FLOAT3;68;COLOR;67;FLOAT;0;FLOAT3;75
Node;AmplifyShaderEditor.FunctionNode;142;-5584,-896;Inherit;False;LavaBase;1;;56;f88859ea02d1de9418d963f1a1027734;0;1;66;FLOAT2;0,0;False;5;COLOR;69;FLOAT3;68;COLOR;67;FLOAT;0;FLOAT3;75
Node;AmplifyShaderEditor.FunctionNode;143;-5584,-720;Inherit;False;LavaBase;1;;61;f88859ea02d1de9418d963f1a1027734;0;1;66;FLOAT2;0,0;False;5;COLOR;69;FLOAT3;68;COLOR;67;FLOAT;0;FLOAT3;75
Node;AmplifyShaderEditor.PowerNode;129;-5440,-320;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.CommentaryNode;161;-5200,-256;Inherit;False;228;378.9;Comment;3;158;159;160;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;157;-5200,-640;Inherit;False;228;378.9;Comment;3;149;151;150;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;156;-5202,-1410;Inherit;False;228;378.9;Comment;3;115;120;122;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;155;-5202,-1026;Inherit;False;228;378.9;Comment;3;145;146;144;;1,1,1,1;0;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;163;-5152,160;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;164;-5152,352;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;165;-5152,256;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;147;-4720,-416;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;152;-4720,-272;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.NormalizeNode;148;-4544,-416;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;125;-4720,-560;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;145;-5152,-880;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;146;-5152,-784;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;144;-5152,-976;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;115;-5152,-1360;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;120;-5152,-1264;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;122;-5152,-1168;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;149;-5152,-592;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;151;-5152,-400;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;150;-5152,-496;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;162;-4720,-144;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;158;-5152,-192;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;159;-5152,0;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;160;-5152,-96;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;166;-4704,32;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;ExtraPrePass;0;0;ExtraPrePass;5;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;0;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;2;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;ShadowCaster;0;2;ShadowCaster;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=ShadowCaster;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;3;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;DepthOnly;0;3;DepthOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;True;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;False;False;True;1;LightMode=DepthOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;4;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;Meta;0;4;Meta;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Meta;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;5;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;Universal2D;0;5;Universal2D;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=Universal2D;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;6;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;DepthNormals;0;6;DepthNormals;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormals;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;7;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;GBuffer;0;7;GBuffer;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalGBuffer;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;8;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;SceneSelectionPass;0;8;SceneSelectionPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=SceneSelectionPass;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;9;0,0;Float;False;False;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;New Amplify Shader;94348b07e5e8bab40bd6c8a1e3df54cd;True;ScenePickingPass;0;9;ScenePickingPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Picking;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;-4240,-448;Float;False;True;-1;3;UnityEditor.ShaderGraphLitGUI;0;12;UMS/LavaTriplanar;94348b07e5e8bab40bd6c8a1e3df54cd;True;Forward;0;1;Forward;21;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;2;False;;True;3;False;;True;True;0;False;;0;False;;True;4;RenderPipeline=UniversalPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;UniversalMaterialType=Lit;True;5;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalForward;False;False;0;;0;0;Standard;43;Lighting Model;0;0;Workflow;1;0;Surface;1;638788424456135002;  Refraction Model;0;0;  Blend;0;0;Two Sided;1;0;Alpha Clipping;1;0;  Use Shadow Threshold;0;0;Fragment Normal Space,InvertActionOnDeselection;0;0;Forward Only;0;0;Transmission;0;0;  Transmission Shadow;0.5,False,;0;Translucency;0;0;  Translucency Strength;1,False,;0;  Normal Distortion;0.5,False,;0;  Scattering;2,False,;0;  Direct;0.9,False,;0;  Ambient;0.1,False,;0;  Shadow;0.5,False,;0;Cast Shadows;1;0;Receive Shadows;1;0;Receive SSAO;1;0;GPU Instancing;1;0;LOD CrossFade;1;0;Built-in Fog;1;0;_FinalColorxAlpha;0;0;Meta Pass;1;0;Override Baked GI;0;0;Extra Pre Pass;0;0;Tessellation;0;0;  Phong;0;0;  Strength;0.5,False,;0;  Type;0;0;  Tess;16,False,;0;  Min;10,False,;0;  Max;25,False,;0;  Edge Length;16,False,;0;  Max Displacement;25,False,;0;Write Depth;0;0;  Early Z;0;0;Vertex Position,InvertActionOnDeselection;1;0;Debug Display;0;0;Clear Coat;0;0;0;10;False;True;True;True;True;True;True;True;True;True;False;;False;0
WireConnection;153;0;13;0
WireConnection;153;1;99;0
WireConnection;113;0;114;0
WireConnection;119;0;114;0
WireConnection;124;0;114;0
WireConnection;154;0;153;0
WireConnection;118;0;119;0
WireConnection;123;0;124;0
WireConnection;116;0;113;0
WireConnection;109;0;154;0
WireConnection;109;1;154;2
WireConnection;117;0;154;0
WireConnection;117;1;154;1
WireConnection;121;0;154;2
WireConnection;121;1;154;1
WireConnection;128;0;116;0
WireConnection;128;1;131;0
WireConnection;130;0;123;0
WireConnection;130;1;131;0
WireConnection;141;66;109;0
WireConnection;142;66;117;0
WireConnection;143;66;121;0
WireConnection;129;0;118;0
WireConnection;129;1;131;0
WireConnection;163;0;141;75
WireConnection;163;1;128;0
WireConnection;164;0;143;75
WireConnection;164;1;130;0
WireConnection;165;0;142;75
WireConnection;165;1;129;0
WireConnection;147;0;144;0
WireConnection;147;1;145;0
WireConnection;147;2;146;0
WireConnection;152;0;149;0
WireConnection;152;1;150;0
WireConnection;152;2;151;0
WireConnection;148;0;147;0
WireConnection;125;0;115;0
WireConnection;125;1;120;0
WireConnection;125;2;122;0
WireConnection;145;0;142;68
WireConnection;145;1;129;0
WireConnection;146;0;143;68
WireConnection;146;1;130;0
WireConnection;144;0;141;68
WireConnection;144;1;128;0
WireConnection;115;0;141;69
WireConnection;115;1;128;0
WireConnection;120;0;142;69
WireConnection;120;1;129;0
WireConnection;122;0;143;69
WireConnection;122;1;130;0
WireConnection;149;0;141;67
WireConnection;149;1;128;0
WireConnection;151;0;143;67
WireConnection;151;1;130;0
WireConnection;150;0;142;67
WireConnection;150;1;129;0
WireConnection;162;0;158;0
WireConnection;162;1;160;0
WireConnection;162;2;159;0
WireConnection;158;0;141;0
WireConnection;158;1;128;0
WireConnection;159;0;143;0
WireConnection;159;1;130;0
WireConnection;160;0;142;0
WireConnection;160;1;129;0
WireConnection;166;0;163;0
WireConnection;166;1;165;0
WireConnection;166;2;164;0
WireConnection;1;0;125;0
WireConnection;1;1;148;0
WireConnection;1;2;152;0
WireConnection;1;4;162;0
WireConnection;1;8;166;0
ASEEND*/
//CHKSM=997330F8D4AF6EFA137A8588B30DF627CBE72D03