// Upgrade NOTE: upgraded instancing buffer 'UMSBuiltInLava' to new syntax.

// Made with Amplify Shader Editor v1.9.8.1
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "UMS/BuiltInLava"
{
	Properties
	{
		_OverallScale("OverallScale", Float) = 1
		_TurbulenceSpeed("TurbulenceSpeed", Float) = 0.1
		_ScrollSpeed("ScrollSpeed", Vector) = (0,0,0,0)
		[HDR]_LavaColor("LavaColor", Color) = (64,11.15722,0,0)
		_Lavasmoothness("Lava smoothness", Range( 0 , 1)) = 0
		_LavaParallaxDepth("LavaParallaxDepth", Float) = 1
		_LavaLevel("LavaLevel", Range( 0 , 1)) = 0
		_CrustLevel("CrustLevel", Range( 0 , 1)) = 0
		_CrustFadeDistance("CrustFadeDistance", Float) = 0
		[HDR]_CrustColor("CrustColor", Color) = (0.0472623,0.03809185,0.0754717,0)
		_Crustsmoothness("Crust smoothness", Range( 0 , 1)) = 0
		[KeywordEnum(World,Vertex)] _ProjectionMode("ProjectionMode", Float) = 0
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent"  "Queue" = "Transparent+0" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Back
		CGINCLUDE
		#include "UnityShaderVariables.cginc"
		#include "UnityCG.cginc"
		#include "UnityPBSLighting.cginc"
		#include "Lighting.cginc"
		#pragma target 3.5
		#pragma multi_compile_instancing
		#pragma shader_feature_local _PROJECTIONMODE_WORLD _PROJECTIONMODE_VERTEX
		#define ASE_VERSION 19801
		#ifdef UNITY_PASS_SHADOWCASTER
			#undef INTERNAL_DATA
			#undef WorldReflectionVector
			#undef WorldNormalVector
			#define INTERNAL_DATA half3 internalSurfaceTtoW0; half3 internalSurfaceTtoW1; half3 internalSurfaceTtoW2;
			#define WorldReflectionVector(data,normal) reflect (data.worldRefl, half3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal)))
			#define WorldNormalVector(data,normal) half3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal))
		#endif
		struct Input
		{
			float3 worldPos;
			float3 worldNormal;
			INTERNAL_DATA
			float2 uv_texcoord;
			float4 ase_positionOS4f;
			float4 screenPos;
			float3 viewDir;
		};

		uniform float2 _ScrollSpeed;
		uniform float _OverallScale;
		uniform float _LavaLevel;
		uniform float _CrustLevel;
		UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
		uniform float4 _CameraDepthTexture_TexelSize;
		uniform float _CrustFadeDistance;
		uniform float _LavaParallaxDepth;
		uniform float _Crustsmoothness;
		uniform float _Lavasmoothness;

		UNITY_INSTANCING_BUFFER_START(UMSBuiltInLava)
			UNITY_DEFINE_INSTANCED_PROP(float4, _CrustColor)
#define _CrustColor_arr UMSBuiltInLava
			UNITY_DEFINE_INSTANCED_PROP(float4, _LavaColor)
#define _LavaColor_arr UMSBuiltInLava
			UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
#define _TurbulenceSpeed_arr UMSBuiltInLava
		UNITY_INSTANCING_BUFFER_END(UMSBuiltInLava)


		float2 voronoihash42( float2 p )
		{
			
			p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
			return frac( sin( p ) *43758.5453);
		}


		float voronoi42( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
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
			 		float2 o = voronoihash42( n + g );
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


		float2 voronoihash15( float2 p )
		{
			
			p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
			return frac( sin( p ) *43758.5453);
		}


		float voronoi15( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
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
			 		float2 o = voronoihash15( n + g );
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


		float3 PerturbNormal107_g17( float3 surf_pos, float3 surf_norm, float height, float scale )
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


		float2 voronoihash27( float2 p )
		{
			
			p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
			return frac( sin( p ) *43758.5453);
		}


		float voronoi27( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
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
			 		float2 o = voronoihash27( n + g );
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


		void vertexDataFunc( inout appdata_full v, out Input o )
		{
			UNITY_INITIALIZE_OUTPUT( Input, o );
			float4 ase_positionOS4f = v.vertex;
			o.ase_positionOS4f = ase_positionOS4f;
		}

		void surf( Input i , inout SurfaceOutputStandard o )
		{
			float3 ase_positionWS = i.worldPos;
			float3 surf_pos107_g17 = ase_positionWS;
			float3 ase_normalWS = WorldNormalVector( i, float3( 0, 0, 1 ) );
			float3 surf_norm107_g17 = ase_normalWS;
			float time42 = 0.0;
			float2 voronoiSmoothId42 = 0;
			float2 panner1_g15 = ( _Time.y * float2( 0,0 ) + i.uv_texcoord);
			float temp_output_13_0_g15 = 30.0;
			float simplePerlin2D7_g15 = snoise( ( panner1_g15 + float2( 0.01,0 ) )*temp_output_13_0_g15 );
			simplePerlin2D7_g15 = simplePerlin2D7_g15*0.5 + 0.5;
			float simplePerlin2D2_g15 = snoise( panner1_g15*temp_output_13_0_g15 );
			simplePerlin2D2_g15 = simplePerlin2D2_g15*0.5 + 0.5;
			float simplePerlin2D8_g15 = snoise( ( panner1_g15 + float2( 0,0.01 ) )*temp_output_13_0_g15 );
			simplePerlin2D8_g15 = simplePerlin2D8_g15*0.5 + 0.5;
			float4 appendResult9_g15 = (float4(( simplePerlin2D7_g15 - simplePerlin2D2_g15 ) , ( simplePerlin2D8_g15 - simplePerlin2D2_g15 ) , 0.0 , 0.0));
			float3 ase_positionOS = i.ase_positionOS4f.xyz;
			#if defined( _PROJECTIONMODE_WORLD )
				float3 staticSwitch102 = ase_positionWS;
			#elif defined( _PROJECTIONMODE_VERTEX )
				float3 staticSwitch102 = ase_positionOS;
			#else
				float3 staticSwitch102 = ase_positionWS;
			#endif
			float3 break100 = ( staticSwitch102 * _OverallScale );
			float2 appendResult14 = (float2(break100.x , break100.z));
			float2 panner106 = ( 1.0 * _Time.y * _ScrollSpeed + appendResult14);
			float2 coords42 = ( ( appendResult9_g15 * 0.1 ) + float4( panner106, 0.0 , 0.0 ) ).xy * 3.0;
			float2 id42 = 0;
			float2 uv42 = 0;
			float fade42 = 0.5;
			float voroi42 = 0;
			float rest42 = 0;
			for( int it42 = 0; it42 <2; it42++ ){
			voroi42 += fade42 * voronoi42( coords42, time42, id42, uv42, 0,voronoiSmoothId42 );
			rest42 += fade42;
			coords42 *= 2;
			fade42 *= 0.5;
			}//Voronoi42
			voroi42 /= rest42;
			float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(_TurbulenceSpeed_arr, _TurbulenceSpeed);
			float mulTime19 = _Time.y * _TurbulenceSpeed_Instance;
			float time15 = mulTime19;
			float2 voronoiSmoothId15 = 0;
			float2 panner1_g14 = ( _Time.y * float2( 0,0 ) + panner106);
			float temp_output_13_0_g14 = 2.0;
			float simplePerlin2D7_g14 = snoise( ( panner1_g14 + float2( 0.01,0 ) )*temp_output_13_0_g14 );
			simplePerlin2D7_g14 = simplePerlin2D7_g14*0.5 + 0.5;
			float simplePerlin2D2_g14 = snoise( panner1_g14*temp_output_13_0_g14 );
			simplePerlin2D2_g14 = simplePerlin2D2_g14*0.5 + 0.5;
			float simplePerlin2D8_g14 = snoise( ( panner1_g14 + float2( 0,0.01 ) )*temp_output_13_0_g14 );
			simplePerlin2D8_g14 = simplePerlin2D8_g14*0.5 + 0.5;
			float4 appendResult9_g14 = (float4(( simplePerlin2D7_g14 - simplePerlin2D2_g14 ) , ( simplePerlin2D8_g14 - simplePerlin2D2_g14 ) , 0.0 , 0.0));
			float2 coords15 = ( ( appendResult9_g14 * 2.0 ) + float4( panner106, 0.0 , 0.0 ) ).xy * 1.0;
			float2 id15 = 0;
			float2 uv15 = 0;
			float fade15 = 0.5;
			float voroi15 = 0;
			float rest15 = 0;
			for( int it15 = 0; it15 <2; it15++ ){
			voroi15 += fade15 * voronoi15( coords15, time15, id15, uv15, 0,voronoiSmoothId15 );
			rest15 += fade15;
			coords15 *= 2;
			fade15 *= 0.5;
			}//Voronoi15
			voroi15 /= rest15;
			float4 ase_positionSS = float4( i.screenPos.xyz , i.screenPos.w + 1e-7 );
			float4 ase_positionSSNorm = ase_positionSS / ase_positionSS.w;
			ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
			float screenDepth85 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_positionSSNorm.xy ));
			float distanceDepth85 = saturate( abs( ( screenDepth85 - LinearEyeDepth( ase_positionSSNorm.z ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
			float lerpResult96 = lerp( 1.0 , voroi15 , pow( distanceDepth85 , 0.1 ));
			float smoothstepResult20 = smoothstep( _LavaLevel , _CrustLevel , lerpResult96);
			float CrustLevel35 = saturate( smoothstepResult20 );
			float temp_output_50_0 = ( voroi42 * pow( ( 1.0 - CrustLevel35 ) , 100.0 ) );
			float height107_g17 = temp_output_50_0;
			float scale107_g17 = 1.0;
			float3 localPerturbNormal107_g17 = PerturbNormal107_g17( surf_pos107_g17 , surf_norm107_g17 , height107_g17 , scale107_g17 );
			float3 ase_tangentWS = WorldNormalVector( i, float3( 1, 0, 0 ) );
			float3 ase_bitangentWS = WorldNormalVector( i, float3( 0, 1, 0 ) );
			float3x3 ase_worldToTangent = float3x3( ase_tangentWS, ase_bitangentWS, ase_normalWS );
			float3 worldToTangentDir42_g17 = mul( ase_worldToTangent, localPerturbNormal107_g17 );
			float3 CrustNormal46 = worldToTangentDir42_g17;
			o.Normal = CrustNormal46;
			float4 _CrustColor_Instance = UNITY_ACCESS_INSTANCED_PROP(_CrustColor_arr, _CrustColor);
			float4 _LavaColor_Instance = UNITY_ACCESS_INSTANCED_PROP(_LavaColor_arr, _LavaColor);
			float time27 = _Time.y;
			float2 voronoiSmoothId27 = 0;
			float2 paralaxOffset71 = ParallaxOffset( 1 , _LavaParallaxDepth , i.viewDir );
			float2 temp_output_74_0 = ( panner106 + paralaxOffset71 );
			float2 panner1_g16 = ( _Time.y * float2( 0,0 ) + temp_output_74_0);
			float temp_output_13_0_g16 = 2.0;
			float simplePerlin2D7_g16 = snoise( ( panner1_g16 + float2( 0.01,0 ) )*temp_output_13_0_g16 );
			simplePerlin2D7_g16 = simplePerlin2D7_g16*0.5 + 0.5;
			float simplePerlin2D2_g16 = snoise( panner1_g16*temp_output_13_0_g16 );
			simplePerlin2D2_g16 = simplePerlin2D2_g16*0.5 + 0.5;
			float simplePerlin2D8_g16 = snoise( ( panner1_g16 + float2( 0,0.01 ) )*temp_output_13_0_g16 );
			simplePerlin2D8_g16 = simplePerlin2D8_g16*0.5 + 0.5;
			float4 appendResult9_g16 = (float4(( simplePerlin2D7_g16 - simplePerlin2D2_g16 ) , ( simplePerlin2D8_g16 - simplePerlin2D2_g16 ) , 0.0 , 0.0));
			float2 coords27 = ( ( appendResult9_g16 * 4.0 ) + float4( temp_output_74_0, 0.0 , 0.0 ) ).xy * 1.0;
			float2 id27 = 0;
			float2 uv27 = 0;
			float fade27 = 0.5;
			float voroi27 = 0;
			float rest27 = 0;
			for( int it27 = 0; it27 <5; it27++ ){
			voroi27 += fade27 * voronoi27( coords27, time27, id27, uv27, 0,voronoiSmoothId27 );
			rest27 += fade27;
			coords27 *= 2;
			fade27 *= 0.5;
			}//Voronoi27
			voroi27 /= rest27;
			float4 lerpResult37 = lerp( ( _CrustColor_Instance * ( 1.0 - CrustLevel35 ) ) , ( _LavaColor_Instance * voroi27 ) , CrustLevel35);
			o.Albedo = lerpResult37.rgb;
			float4 LavaEmission48 = ( _LavaColor_Instance * voroi27 * smoothstepResult20 );
			o.Emission = LavaEmission48.rgb;
			float lerpResult77 = lerp( ( pow( temp_output_50_0 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel35);
			o.Smoothness = lerpResult77;
			o.Alpha = 1;
		}

		ENDCG
		CGPROGRAM
		#pragma surface surf Standard alpha:fade keepalpha fullforwardshadows vertex:vertexDataFunc 

		ENDCG
		Pass
		{
			Name "ShadowCaster"
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.5
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
			#include "HLSLSupport.cginc"
			#if ( SHADER_API_D3D11 || SHADER_API_GLCORE || SHADER_API_GLES || SHADER_API_GLES3 || SHADER_API_METAL || SHADER_API_VULKAN )
				#define CAN_SKIP_VPOS
			#endif
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			struct v2f
			{
				V2F_SHADOW_CASTER;
				float2 customPack1 : TEXCOORD1;
				float4 customPack2 : TEXCOORD2;
				float4 screenPos : TEXCOORD3;
				float4 tSpace0 : TEXCOORD4;
				float4 tSpace1 : TEXCOORD5;
				float4 tSpace2 : TEXCOORD6;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
			v2f vert( appdata_full v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				UNITY_TRANSFER_INSTANCE_ID( v, o );
				Input customInputData;
				vertexDataFunc( v, customInputData );
				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				half3 worldNormal = UnityObjectToWorldNormal( v.normal );
				half3 worldTangent = UnityObjectToWorldDir( v.tangent.xyz );
				half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				half3 worldBinormal = cross( worldNormal, worldTangent ) * tangentSign;
				o.tSpace0 = float4( worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x );
				o.tSpace1 = float4( worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y );
				o.tSpace2 = float4( worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z );
				o.customPack1.xy = customInputData.uv_texcoord;
				o.customPack1.xy = v.texcoord;
				o.customPack2.xyzw = customInputData.ase_positionOS4f;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET( o )
				o.screenPos = ComputeScreenPos( o.pos );
				return o;
			}
			half4 frag( v2f IN
			#if !defined( CAN_SKIP_VPOS )
			, UNITY_VPOS_TYPE vpos : VPOS
			#endif
			) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				Input surfIN;
				UNITY_INITIALIZE_OUTPUT( Input, surfIN );
				surfIN.uv_texcoord = IN.customPack1.xy;
				surfIN.ase_positionOS4f = IN.customPack2.xyzw;
				float3 worldPos = float3( IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w );
				half3 worldViewDir = normalize( UnityWorldSpaceViewDir( worldPos ) );
				surfIN.viewDir = IN.tSpace0.xyz * worldViewDir.x + IN.tSpace1.xyz * worldViewDir.y + IN.tSpace2.xyz * worldViewDir.z;
				surfIN.worldPos = worldPos;
				surfIN.worldNormal = float3( IN.tSpace0.z, IN.tSpace1.z, IN.tSpace2.z );
				surfIN.internalSurfaceTtoW0 = IN.tSpace0.xyz;
				surfIN.internalSurfaceTtoW1 = IN.tSpace1.xyz;
				surfIN.internalSurfaceTtoW2 = IN.tSpace2.xyz;
				surfIN.screenPos = IN.screenPos;
				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT( SurfaceOutputStandard, o )
				surf( surfIN, o );
				#if defined( CAN_SKIP_VPOS )
				float2 vpos = IN.pos;
				#endif
				SHADOW_CASTER_FRAGMENT( IN )
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
	CustomEditor "AmplifyShaderEditor.MaterialInspector"
}
/*ASEBEGIN
Version=19801
Node;AmplifyShaderEditor.WorldPosInputsNode;13;-4448,-320;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.PosVertexDataNode;101;-4448,-112;Inherit;False;0;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;99;-4128,80;Inherit;False;Property;_OverallScale;OverallScale;0;0;Create;True;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.StaticSwitch;102;-4224,-208;Inherit;False;Property;_ProjectionMode;ProjectionMode;11;0;Create;True;0;0;0;False;0;False;0;0;0;True;;KeywordEnum;2;World;Vertex;Create;True;True;All;9;1;FLOAT3;0,0,0;False;0;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;5;FLOAT3;0,0,0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;98;-3888,-96;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.BreakToComponentsNode;100;-3200,-48;Inherit;False;FLOAT3;1;0;FLOAT3;0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.DynamicAppendNode;14;-3072,-48;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;105;-2960,144;Inherit;False;Property;_ScrollSpeed;ScrollSpeed;2;0;Create;True;0;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.PannerNode;106;-2800,-176;Inherit;False;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FunctionNode;12;-1856,-288;Inherit;True;NoiseNormal;-1;;14;afbd46a8199900f45b4efc7cc551f840;0;4;15;FLOAT;0;False;14;FLOAT2;0,0;False;13;FLOAT;2;False;12;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;18;-1200,64;Inherit;False;Constant;_Float0;Float 0;0;0;Create;True;0;0;0;False;0;False;2;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;103;-2016,544;Inherit;False;Property;_CrustFadeDistance;CrustFadeDistance;8;0;Create;True;0;0;0;False;0;False;0;0.3;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;16;-1040,0;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;104;-1728,592;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;107;-1232,256;Inherit;False;InstancedProperty;_TurbulenceSpeed;TurbulenceSpeed;1;0;Create;True;0;0;0;False;0;False;0.1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;17;-831.6138,145.9943;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleTimeNode;19;-960,256;Inherit;False;1;0;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DepthFade;85;-1496,432;Inherit;False;True;True;True;2;1;FLOAT3;0,0,0;False;0;FLOAT;0.3;False;1;FLOAT;0
Node;AmplifyShaderEditor.VoronoiNode;15;-704,176;Inherit;False;0;0;1;0;2;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.PowerNode;97;-1201.404,439.3308;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;21;-768,528;Inherit;False;Property;_CrustLevel;CrustLevel;7;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;96;-464,240;Inherit;False;3;0;FLOAT;1;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;22;-768,448;Inherit;False;Property;_LavaLevel;LavaLevel;6;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ViewDirInputsCoordNode;72;-2560,368;Inherit;False;Tangent;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;81;-2624,256;Inherit;False;Property;_LavaParallaxDepth;LavaParallaxDepth;5;0;Create;True;0;0;0;False;0;False;1;2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode;20;-240,256;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.2;False;1;FLOAT;0
Node;AmplifyShaderEditor.ParallaxOffsetHlpNode;71;-2352,208;Inherit;False;3;0;FLOAT;1;False;1;FLOAT;1;False;2;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SaturateNode;93;13.43787,266.3629;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;62;-2192,-464;Inherit;False;Constant;_Float2;Float 2;4;0;Create;True;0;0;0;False;0;False;0.1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;59;-2368,-736;Inherit;True;NoiseNormal;-1;;15;afbd46a8199900f45b4efc7cc551f840;0;4;15;FLOAT;0;False;14;FLOAT2;0,0;False;13;FLOAT;30;False;12;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;35;208,304;Inherit;False;CrustLevel;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;74;-2080,80;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;51;-1232,-480;Inherit;False;35;CrustLevel;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;61;-2000,-672;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.FunctionNode;75;-1888,112;Inherit;True;NoiseNormal;-1;;16;afbd46a8199900f45b4efc7cc551f840;0;4;15;FLOAT;0;False;14;FLOAT2;0,0;False;13;FLOAT;2;False;12;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;31;-1712,368;Inherit;False;Constant;_Float1;Float 1;2;0;Create;True;0;0;0;False;0;False;4;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;52;-1072,-528;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;60;-1840.86,-634.5802;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;30;-1520,64;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.PowerNode;53;-864,-512;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;100;False;1;FLOAT;0
Node;AmplifyShaderEditor.VoronoiNode;42;-1536,-832;Inherit;False;0;0;1;1;2;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;3;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.SimpleTimeNode;29;-912,-96;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;28;-1344,-240;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.GetLocalVarNode;44;16,-32;Inherit;False;35;CrustLevel;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;50;-807.0513,-731.7819;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;34;-496,-416;Inherit;False;InstancedProperty;_LavaColor;LavaColor;3;1;[HDR];Create;True;0;0;0;False;0;False;64,11.15722,0,0;0,0,0,0;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.VoronoiNode;27;-752,-224;Inherit;False;0;0;1;0;5;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.ColorNode;36;48,-432;Inherit;False;InstancedProperty;_CrustColor;CrustColor;9;1;[HDR];Create;True;0;0;0;False;0;False;0.0472623,0.03809185,0.0754717,0;0.02816874,0.01762192,0.03773582,0;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.OneMinusNode;41;240,-16;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;33;-240,-144;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;43;-464,-752;Inherit;True;Normal From Height;-1;;17;1942fe2c5f1a1f94881a33d532e4afeb;0;2;20;FLOAT;0;False;110;FLOAT;1;False;2;FLOAT3;40;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;79;528,240;Inherit;False;Property;_Crustsmoothness;Crust smoothness;10;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;82;496,64;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;48;-48.04236,-132.4711;Inherit;False;LavaEmission;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;46;-96,-752;Inherit;False;CrustNormal;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;40;368,-304;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;76;-144,-320;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;45;160,96;Inherit;False;35;CrustLevel;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;78;691.3292,449.1714;Inherit;False;35;CrustLevel;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;80;544,336;Inherit;False;Property;_Lavasmoothness;Lava smoothness;4;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;83;848,240;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;37;608,-144;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;55;-1184,-736;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;56;-1648,-528;Inherit;False;Simplex2D;True;False;2;0;FLOAT2;0,0;False;1;FLOAT;20;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;58;-1424,-608;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.9;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;63;-880,-16;Inherit;False;Simplex2D;True;False;2;0;FLOAT2;0,0;False;1;FLOAT;5;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;66;-656,0;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.95;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;70;-76.02991,-239.7571;Inherit;False;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.PowerNode;69;-496,-80;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;5;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;49;752,176;Inherit;False;48;LavaEmission;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;47;784,64;Inherit;False;46;CrustNormal;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.LerpOp;77;1056,288;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;108;1280,16;Float;False;True;-1;3;AmplifyShaderEditor.MaterialInspector;0;0;Standard;UMS/BuiltInLava;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Back;0;False;;0;False;;False;0;False;;0;False;;False;0;Transparent;0.5;True;True;0;False;Transparent;;Transparent;All;12;all;True;True;True;True;0;False;;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;2;15;10;25;False;0.5;True;2;5;False;;10;False;;0;0;False;;0;False;;0;False;;0;False;;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;True;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;;-1;0;False;;0;0;0;False;0.1;False;;0;False;;False;17;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;16;FLOAT4;0,0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;102;1;13;0
WireConnection;102;0;101;0
WireConnection;98;0;102;0
WireConnection;98;1;99;0
WireConnection;100;0;98;0
WireConnection;14;0;100;0
WireConnection;14;1;100;2
WireConnection;106;0;14;0
WireConnection;106;2;105;0
WireConnection;12;12;106;0
WireConnection;16;0;12;0
WireConnection;16;1;18;0
WireConnection;104;0;103;0
WireConnection;17;0;16;0
WireConnection;17;1;106;0
WireConnection;19;0;107;0
WireConnection;85;0;104;0
WireConnection;15;0;17;0
WireConnection;15;1;19;0
WireConnection;97;0;85;0
WireConnection;96;1;15;0
WireConnection;96;2;97;0
WireConnection;20;0;96;0
WireConnection;20;1;22;0
WireConnection;20;2;21;0
WireConnection;71;1;81;0
WireConnection;71;2;72;0
WireConnection;93;0;20;0
WireConnection;35;0;93;0
WireConnection;74;0;106;0
WireConnection;74;1;71;0
WireConnection;61;0;59;0
WireConnection;61;1;62;0
WireConnection;75;12;74;0
WireConnection;52;0;51;0
WireConnection;60;0;61;0
WireConnection;60;1;106;0
WireConnection;30;0;75;0
WireConnection;30;1;31;0
WireConnection;53;0;52;0
WireConnection;42;0;60;0
WireConnection;28;0;30;0
WireConnection;28;1;74;0
WireConnection;50;0;42;0
WireConnection;50;1;53;0
WireConnection;27;0;28;0
WireConnection;27;1;29;0
WireConnection;41;0;44;0
WireConnection;33;0;34;0
WireConnection;33;1;27;0
WireConnection;33;2;20;0
WireConnection;43;20;50;0
WireConnection;82;0;50;0
WireConnection;48;0;33;0
WireConnection;46;0;43;40
WireConnection;40;0;36;0
WireConnection;40;1;41;0
WireConnection;76;0;34;0
WireConnection;76;1;27;0
WireConnection;83;0;82;0
WireConnection;83;1;79;0
WireConnection;37;0;40;0
WireConnection;37;1;76;0
WireConnection;37;2;45;0
WireConnection;55;1;58;0
WireConnection;56;0;106;0
WireConnection;58;0;56;0
WireConnection;63;0;106;0
WireConnection;66;0;63;0
WireConnection;70;0;34;0
WireConnection;69;0;27;0
WireConnection;77;0;83;0
WireConnection;77;1;80;0
WireConnection;77;2;78;0
WireConnection;108;0;37;0
WireConnection;108;1;47;0
WireConnection;108;2;49;0
WireConnection;108;4;77;0
ASEEND*/
//CHKSM=6357E7014F51239C49E4F7AE80D0EDD52596FEBF