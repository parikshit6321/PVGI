Shader "Hidden/PVGIShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		CGINCLUDE

		#include "UnityCG.cginc"

		#define PI 3.1415926f

		uniform sampler3D				voxelGrid1;
		uniform sampler3D				voxelGrid2;
		uniform sampler3D				voxelGrid3;
		uniform sampler3D				voxelGrid4;
		uniform sampler3D				voxelGrid5;

		uniform sampler2D 				_MainTex;
		uniform sampler2D				_IndirectTex;
		uniform sampler2D				_CameraDepthTexture;
		uniform sampler2D				_CameraDepthNormalsTexture;
		uniform sampler2D				_CameraGBufferTexture0;
		uniform sampler2D				_CameraGBufferTexture1;

		uniform float4x4				InverseProjectionMatrix;
		uniform float4x4				InverseViewMatrix;

		uniform float4					_MainTex_TexelSize;

		uniform float					worldVolumeBoundary;
		uniform float					indirectLightingStrength;

		uniform int						highestVoxelResolution;

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct v2f
		{
			float2 uv : TEXCOORD0;
			float4 vertex : SV_POSITION;
			float4 cameraRay : TEXCOORD1;
		};

		v2f vert (appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv = v.uv;

			//transform clip pos to view space
			float4 clipPos = float4( v.uv * 2.0f - 1.0f, 1.0f, 1.0f);
			float4 cameraRay = mul(InverseProjectionMatrix, clipPos);
			o.cameraRay = cameraRay / cameraRay.w;

			return o;
		}

		float4 frag_position (v2f i) : SV_Target
		{
			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			return float4(worldPos, lindepth);
		}

		// Returns the voxel information from grid 1
		inline float4 GetVoxelInfo1(float3 worldPosition)
		{
			float3 voxelPosition = worldPosition / worldVolumeBoundary;
			voxelPosition += float3(1.0f, 1.0f, 1.0f);
			voxelPosition /= 2.0f;
			float4 info = tex3D(voxelGrid1, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 2
		inline float4 GetVoxelInfo2(float3 worldPosition)
		{
			float3 voxelPosition = worldPosition / worldVolumeBoundary;
			voxelPosition += float3(1.0f, 1.0f, 1.0f);
			voxelPosition /= 2.0f;
			float4 info = tex3D(voxelGrid2, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 3
		inline float4 GetVoxelInfo3(float3 worldPosition)
		{
			float3 voxelPosition = worldPosition / worldVolumeBoundary;
			voxelPosition += float3(1.0f, 1.0f, 1.0f);
			voxelPosition /= 2.0f;
			float4 info = tex3D(voxelGrid3, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 4
		inline float4 GetVoxelInfo4(float3 worldPosition)
		{
			float3 voxelPosition = worldPosition / worldVolumeBoundary;
			voxelPosition += float3(1.0f, 1.0f, 1.0f);
			voxelPosition /= 2.0f;
			float4 info = tex3D(voxelGrid4, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 5
		inline float4 GetVoxelInfo5(float3 worldPosition)
		{
			float3 voxelPosition = worldPosition / worldVolumeBoundary;
			voxelPosition += float3(1.0f, 1.0f, 1.0f);
			voxelPosition /= 2.0f;
			float4 info = tex3D(voxelGrid5, voxelPosition);
			return info;
		}

		float4 frag_debug (v2f i) : SV_Target
		{
			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			float4 voxelInfo = float4(0.0f, 0.0f, 0.0f, 0.0f);

			#if defined(GRID_1)
			voxelInfo = GetVoxelInfo1(worldPos);
			#endif

			#if defined(GRID_2)
			voxelInfo = GetVoxelInfo2(worldPos);
			#endif

			#if defined(GRID_3)
			voxelInfo = GetVoxelInfo3(worldPos);
			#endif

			#if defined(GRID_4)
			voxelInfo = GetVoxelInfo4(worldPos);
			#endif

			#if defined(GRID_5)
			voxelInfo = GetVoxelInfo5(worldPos);
			#endif

			float3 resultingColor = (voxelInfo.a > 0.0f ? voxelInfo.rgb : float3(0.0f, 0.0f, 0.0f));
			return float4(resultingColor, 1.0f);
		}

		ENDCG

		// 0 : World Position Writing pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_position
			ENDCG
		}

		// 1 : Voxel Grid debug pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_debug
			#pragma multi_compile GRID_1 GRID_2 GRID_3 GRID_4 GRID_5
			ENDCG
		}
	}
}