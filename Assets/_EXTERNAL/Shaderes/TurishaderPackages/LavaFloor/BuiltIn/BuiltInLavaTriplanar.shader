// Upgrade NOTE: upgraded instancing buffer 'UMSBuiltInLavaTriplanar' to new syntax.

// Made with Amplify Shader Editor v1.9.8.1
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "UMS/BuiltInLavaTriplanar"
{
	Properties
	{
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
			float4 screenPos;
			float3 viewDir;
		};

		uniform float2 _Wavescrollspeed;
		uniform float _OverallScale;
		uniform float _Lavawavetiling;
		uniform float _Lavawaveoffset;
		uniform float2 _ScrollSpeed;
		uniform float _LavaLevel;
		uniform float _CrustLevel;
		UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
		uniform float4 _CameraDepthTexture_TexelSize;
		uniform float _CrustFadeDistance;
		uniform float _LavaParallaxDepth;
		uniform float _Crustsmoothness;
		uniform float _Lavasmoothness;

		UNITY_INSTANCING_BUFFER_START(UMSBuiltInLavaTriplanar)
			UNITY_DEFINE_INSTANCED_PROP(float4, _CrustColor)
#define _CrustColor_arr UMSBuiltInLavaTriplanar
			UNITY_DEFINE_INSTANCED_PROP(float4, _LavaColor)
#define _LavaColor_arr UMSBuiltInLavaTriplanar
			UNITY_DEFINE_INSTANCED_PROP(float, _TurbulenceSpeed)
#define _TurbulenceSpeed_arr UMSBuiltInLavaTriplanar
		UNITY_INSTANCING_BUFFER_END(UMSBuiltInLavaTriplanar)


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


		void vertexDataFunc( inout appdata_full v, out Input o )
		{
			UNITY_INITIALIZE_OUTPUT( Input, o );
			float3 ase_positionWS = mul( unity_ObjectToWorld, v.vertex );
			float3 break154 = ( ase_positionWS * _OverallScale );
			float2 appendResult109 = (float2(break154.x , break154.z));
			float2 temp_output_66_0_g51 = appendResult109;
			float2 panner82_g51 = ( 1.0 * _Time.y * _Wavescrollspeed + temp_output_66_0_g51);
			float simplePerlin2D79_g51 = snoise( panner82_g51*_Lavawavetiling );
			simplePerlin2D79_g51 = simplePerlin2D79_g51*0.5 + 0.5;
			float3 ase_normalOS = v.normal.xyz;
			float3 ase_normalWS = UnityObjectToWorldNormal( v.normal );
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
			v.vertex.xyz += ( ( ( simplePerlin2D79_g51 * ase_normalOS * _Lavawaveoffset ) * temp_output_128_0 ) + ( ( simplePerlin2D79_g56 * ase_normalOS * _Lavawaveoffset ) * temp_output_129_0 ) + ( ( simplePerlin2D79_g61 * ase_normalOS * _Lavawaveoffset ) * temp_output_130_0 ) );
			v.vertex.w = 1;
		}

		void surf( Input i , inout SurfaceOutputStandard o )
		{
			float3 ase_positionWS = i.worldPos;
			float3 surf_pos107_g55 = ase_positionWS;
			float3 ase_normalWS = WorldNormalVector( i, float3( 0, 0, 1 ) );
			float3 surf_norm107_g55 = ase_normalWS;
			float time18_g51 = 0.0;
			float2 voronoiSmoothId18_g51 = 0;
			float2 panner1_g52 = ( _Time.y * float2( 0,0 ) + i.uv_texcoord);
			float temp_output_13_0_g52 = 30.0;
			float simplePerlin2D7_g52 = snoise( ( panner1_g52 + float2( 0.01,0 ) )*temp_output_13_0_g52 );
			simplePerlin2D7_g52 = simplePerlin2D7_g52*0.5 + 0.5;
			float simplePerlin2D2_g52 = snoise( panner1_g52*temp_output_13_0_g52 );
			simplePerlin2D2_g52 = simplePerlin2D2_g52*0.5 + 0.5;
			float simplePerlin2D8_g52 = snoise( ( panner1_g52 + float2( 0,0.01 ) )*temp_output_13_0_g52 );
			simplePerlin2D8_g52 = simplePerlin2D8_g52*0.5 + 0.5;
			float4 appendResult9_g52 = (float4(( simplePerlin2D7_g52 - simplePerlin2D2_g52 ) , ( simplePerlin2D8_g52 - simplePerlin2D2_g52 ) , 0.0 , 0.0));
			float3 break154 = ( ase_positionWS * _OverallScale );
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
			float _TurbulenceSpeed_Instance = UNITY_ACCESS_INSTANCED_PROP(_TurbulenceSpeed_arr, _TurbulenceSpeed);
			float mulTime3_g51 = _Time.y * _TurbulenceSpeed_Instance;
			float time47_g51 = mulTime3_g51;
			float2 voronoiSmoothId47_g51 = 0;
			float2 panner1_g53 = ( _Time.y * float2( 0,0 ) + panner53_g51);
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
			float4 ase_positionSS = float4( i.screenPos.xyz , i.screenPos.w + 1e-7 );
			float4 ase_positionSSNorm = ase_positionSS / ase_positionSS.w;
			ase_positionSSNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_positionSSNorm.z : ase_positionSSNorm.z * 0.5 + 0.5;
			float screenDepth50_g51 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_positionSSNorm.xy ));
			float distanceDepth50_g51 = saturate( abs( ( screenDepth50_g51 - LinearEyeDepth( ase_positionSSNorm.z ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
			float lerpResult48_g51 = lerp( 1.0 , voroi47_g51 , pow( distanceDepth50_g51 , 0.1 ));
			float smoothstepResult44_g51 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g51);
			float CrustLevel45_g51 = saturate( smoothstepResult44_g51 );
			float temp_output_8_0_g51 = ( voroi18_g51 * pow( ( 1.0 - CrustLevel45_g51 ) , 100.0 ) );
			float height107_g55 = temp_output_8_0_g51;
			float scale107_g55 = 1.0;
			float3 localPerturbNormal107_g55 = PerturbNormal107_g55( surf_pos107_g55 , surf_norm107_g55 , height107_g55 , scale107_g55 );
			float3 ase_tangentWS = WorldNormalVector( i, float3( 1, 0, 0 ) );
			float3 ase_bitangentWS = WorldNormalVector( i, float3( 0, 1, 0 ) );
			float3x3 ase_worldToTangent = float3x3( ase_tangentWS, ase_bitangentWS, ase_normalWS );
			float3 worldToTangentDir42_g55 = mul( ase_worldToTangent, localPerturbNormal107_g55 );
			float3 CrustNormal65_g51 = worldToTangentDir42_g55;
			float dotResult113 = dot( ase_normalWS , float3( 0,1,0 ) );
			float temp_output_128_0 = pow( abs( dotResult113 ) , 5.0 );
			float3 surf_pos107_g60 = ase_positionWS;
			float3 surf_norm107_g60 = ase_normalWS;
			float time18_g56 = 0.0;
			float2 voronoiSmoothId18_g56 = 0;
			float2 panner1_g57 = ( _Time.y * float2( 0,0 ) + i.uv_texcoord);
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
			float mulTime3_g56 = _Time.y * _TurbulenceSpeed_Instance;
			float time47_g56 = mulTime3_g56;
			float2 voronoiSmoothId47_g56 = 0;
			float2 panner1_g58 = ( _Time.y * float2( 0,0 ) + panner53_g56);
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
			float screenDepth50_g56 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_positionSSNorm.xy ));
			float distanceDepth50_g56 = saturate( abs( ( screenDepth50_g56 - LinearEyeDepth( ase_positionSSNorm.z ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
			float lerpResult48_g56 = lerp( 1.0 , voroi47_g56 , pow( distanceDepth50_g56 , 0.1 ));
			float smoothstepResult44_g56 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g56);
			float CrustLevel45_g56 = saturate( smoothstepResult44_g56 );
			float temp_output_8_0_g56 = ( voroi18_g56 * pow( ( 1.0 - CrustLevel45_g56 ) , 100.0 ) );
			float height107_g60 = temp_output_8_0_g56;
			float scale107_g60 = 1.0;
			float3 localPerturbNormal107_g60 = PerturbNormal107_g60( surf_pos107_g60 , surf_norm107_g60 , height107_g60 , scale107_g60 );
			float3 worldToTangentDir42_g60 = mul( ase_worldToTangent, localPerturbNormal107_g60 );
			float3 CrustNormal65_g56 = worldToTangentDir42_g60;
			float dotResult119 = dot( ase_normalWS , float3( 0,0,1 ) );
			float temp_output_129_0 = pow( abs( dotResult119 ) , 5.0 );
			float3 surf_pos107_g65 = ase_positionWS;
			float3 surf_norm107_g65 = ase_normalWS;
			float time18_g61 = 0.0;
			float2 voronoiSmoothId18_g61 = 0;
			float2 panner1_g62 = ( _Time.y * float2( 0,0 ) + i.uv_texcoord);
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
			float mulTime3_g61 = _Time.y * _TurbulenceSpeed_Instance;
			float time47_g61 = mulTime3_g61;
			float2 voronoiSmoothId47_g61 = 0;
			float2 panner1_g63 = ( _Time.y * float2( 0,0 ) + panner53_g61);
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
			float screenDepth50_g61 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_positionSSNorm.xy ));
			float distanceDepth50_g61 = saturate( abs( ( screenDepth50_g61 - LinearEyeDepth( ase_positionSSNorm.z ) ) / ( max( _CrustFadeDistance , 0.0 ) ) ) );
			float lerpResult48_g61 = lerp( 1.0 , voroi47_g61 , pow( distanceDepth50_g61 , 0.1 ));
			float smoothstepResult44_g61 = smoothstep( _LavaLevel , _CrustLevel , lerpResult48_g61);
			float CrustLevel45_g61 = saturate( smoothstepResult44_g61 );
			float temp_output_8_0_g61 = ( voroi18_g61 * pow( ( 1.0 - CrustLevel45_g61 ) , 100.0 ) );
			float height107_g65 = temp_output_8_0_g61;
			float scale107_g65 = 1.0;
			float3 localPerturbNormal107_g65 = PerturbNormal107_g65( surf_pos107_g65 , surf_norm107_g65 , height107_g65 , scale107_g65 );
			float3 worldToTangentDir42_g65 = mul( ase_worldToTangent, localPerturbNormal107_g65 );
			float3 CrustNormal65_g61 = worldToTangentDir42_g65;
			float dotResult124 = dot( ase_normalWS , float3( 1,0,0 ) );
			float temp_output_130_0 = pow( abs( dotResult124 ) , 5.0 );
			float3 normalizeResult148 = normalize( ( ( CrustNormal65_g51 * temp_output_128_0 ) + ( CrustNormal65_g56 * temp_output_129_0 ) + ( CrustNormal65_g61 * temp_output_130_0 ) ) );
			o.Normal = normalizeResult148;
			float4 _CrustColor_Instance = UNITY_ACCESS_INSTANCED_PROP(_CrustColor_arr, _CrustColor);
			float4 _LavaColor_Instance = UNITY_ACCESS_INSTANCED_PROP(_LavaColor_arr, _LavaColor);
			float time39_g51 = _Time.y;
			float2 voronoiSmoothId39_g51 = 0;
			float2 paralaxOffset34_g51 = ParallaxOffset( 1 , _LavaParallaxDepth , i.viewDir );
			float2 temp_output_54_0_g51 = ( panner53_g51 + paralaxOffset34_g51 );
			float2 panner1_g54 = ( _Time.y * float2( 0,0 ) + temp_output_54_0_g51);
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
			float time39_g56 = _Time.y;
			float2 voronoiSmoothId39_g56 = 0;
			float2 paralaxOffset34_g56 = ParallaxOffset( 1 , _LavaParallaxDepth , i.viewDir );
			float2 temp_output_54_0_g56 = ( panner53_g56 + paralaxOffset34_g56 );
			float2 panner1_g59 = ( _Time.y * float2( 0,0 ) + temp_output_54_0_g56);
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
			float time39_g61 = _Time.y;
			float2 voronoiSmoothId39_g61 = 0;
			float2 paralaxOffset34_g61 = ParallaxOffset( 1 , _LavaParallaxDepth , i.viewDir );
			float2 temp_output_54_0_g61 = ( panner53_g61 + paralaxOffset34_g61 );
			float2 panner1_g64 = ( _Time.y * float2( 0,0 ) + temp_output_54_0_g61);
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
			o.Albedo = ( ( lerpResult10_g51 * temp_output_128_0 ) + ( lerpResult10_g56 * temp_output_129_0 ) + ( lerpResult10_g61 * temp_output_130_0 ) ).rgb;
			float4 LavaEmission7_g51 = ( _LavaColor_Instance * voroi39_g51 * smoothstepResult44_g51 );
			float4 LavaEmission7_g56 = ( _LavaColor_Instance * voroi39_g56 * smoothstepResult44_g56 );
			float4 LavaEmission7_g61 = ( _LavaColor_Instance * voroi39_g61 * smoothstepResult44_g61 );
			o.Emission = ( ( LavaEmission7_g51 * temp_output_128_0 ) + ( LavaEmission7_g56 * temp_output_129_0 ) + ( LavaEmission7_g61 * temp_output_130_0 ) ).rgb;
			float lerpResult42_g51 = lerp( ( pow( temp_output_8_0_g51 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g51);
			float lerpResult42_g56 = lerp( ( pow( temp_output_8_0_g56 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g56);
			float lerpResult42_g61 = lerp( ( pow( temp_output_8_0_g61 , 1.0 ) * _Crustsmoothness ) , _Lavasmoothness , CrustLevel45_g61);
			o.Smoothness = ( ( lerpResult42_g51 * temp_output_128_0 ) + ( lerpResult42_g56 * temp_output_129_0 ) + ( lerpResult42_g61 * temp_output_130_0 ) );
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
				float4 screenPos : TEXCOORD2;
				float4 tSpace0 : TEXCOORD3;
				float4 tSpace1 : TEXCOORD4;
				float4 tSpace2 : TEXCOORD5;
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
Node;AmplifyShaderEditor.CommentaryNode;155;-5202,-1026;Inherit;False;228;378.9;;3;145;146;144;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;168;-5202,110;Inherit;False;228;378.9;;3;163;164;165;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;161;-5200,-256;Inherit;False;228;378.9;;3;158;159;160;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;157;-5200,-640;Inherit;False;228;378.9;;3;149;151;150;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;156;-5202,-1410;Inherit;False;228;378.9;;3;115;120;122;;1,1,1,1;0;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;145;-5152,-880;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;146;-5152,-784;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;144;-5152,-976;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;147;-4720,-416;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;115;-5152,-1360;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;120;-5152,-1264;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;122;-5152,-1168;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;149;-5152,-592;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;151;-5152,-400;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;150;-5152,-496;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;158;-5152,-192;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;159;-5152,0;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;160;-5152,-96;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;163;-5152,160;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;164;-5152,352;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;165;-5152,256;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;152;-4720,-272;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.NormalizeNode;148;-4544,-416;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;125;-4720,-560;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;162;-4720,-144;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;166;-4704,32;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;167;-4240,-448;Float;False;True;-1;3;AmplifyShaderEditor.MaterialInspector;0;0;Standard;UMS/BuiltInLavaTriplanar;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Back;0;False;;0;False;;False;0;False;;0;False;;False;0;Transparent;0.5;True;True;0;False;Transparent;;Transparent;All;12;all;True;True;True;True;0;False;;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;2;15;10;25;False;0.5;True;2;5;False;;10;False;;0;0;False;;0;False;;0;False;;0;False;;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;True;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;;-1;0;False;;0;0;0;False;0.1;False;;0;False;;False;17;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;16;FLOAT4;0,0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
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
WireConnection;145;0;142;68
WireConnection;145;1;129;0
WireConnection;146;0;143;68
WireConnection;146;1;130;0
WireConnection;144;0;141;68
WireConnection;144;1;128;0
WireConnection;147;0;144;0
WireConnection;147;1;145;0
WireConnection;147;2;146;0
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
WireConnection;158;0;141;0
WireConnection;158;1;128;0
WireConnection;159;0;143;0
WireConnection;159;1;130;0
WireConnection;160;0;142;0
WireConnection;160;1;129;0
WireConnection;163;0;141;75
WireConnection;163;1;128;0
WireConnection;164;0;143;75
WireConnection;164;1;130;0
WireConnection;165;0;142;75
WireConnection;165;1;129;0
WireConnection;152;0;149;0
WireConnection;152;1;150;0
WireConnection;152;2;151;0
WireConnection;148;0;147;0
WireConnection;125;0;115;0
WireConnection;125;1;120;0
WireConnection;125;2;122;0
WireConnection;162;0;158;0
WireConnection;162;1;160;0
WireConnection;162;2;159;0
WireConnection;166;0;163;0
WireConnection;166;1;165;0
WireConnection;166;2;164;0
WireConnection;167;0;125;0
WireConnection;167;1;148;0
WireConnection;167;2;152;0
WireConnection;167;4;162;0
WireConnection;167;11;166;0
ASEEND*/
//CHKSM=244D4E2DD9A28F07434C8DB0E6D651C423F5C2A2