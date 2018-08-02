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

		uniform sampler3D				voxelGridProgressive;
		uniform sampler3D				voxelGridIrradiance;
		uniform sampler3D				voxelGridNormal;

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

		uniform int						voxelVolumeDimension;

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

		float3 EncodePosition (float3 inputPosition)
		{
			float3 encodedPosition = inputPosition / worldVolumeBoundary;
			encodedPosition += float3(1.0f, 1.0f, 1.0f);
			encodedPosition /= 2.0f;
			return encodedPosition;
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

		float4 frag_normal (v2f i) : SV_Target
		{
			float depthValue;
			float3 viewSpaceNormal;
			DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture, i.uv), depthValue, viewSpaceNormal);
			viewSpaceNormal = normalize(viewSpaceNormal);
			float3 worldSpaceNormal = mul((float3x3)InverseViewMatrix, viewSpaceNormal);
			worldSpaceNormal = normalize(worldSpaceNormal);
			return float4(worldSpaceNormal, 1.0f);
		}

		// Returns the voxel information from grid
		inline float4 GetVoxelInfo(float3 voxelPosition)
		{
			float4 info = tex3D(voxelGridProgressive, voxelPosition);
			return info;
		}

		// Returns the world-space normal stored in the voxel
		inline float3 GetVoxelNormal(float3 voxelPosition)
		{
			float3 worldNormal = tex3D(voxelGridNormal, voxelPosition).rgb;
			return worldNormal;
		}

		// Returns the irradiance stored in the voxel
		inline float3 GetVoxelIrradiance(float3 voxelPosition)
		{
			float3 irradiance = tex3D(voxelGridIrradiance, voxelPosition).rgb;
			return irradiance;
		}

		// Function to get position of voxel in the grid
		inline float3 GetVoxelPosition (float3 worldPosition)
		{
			float3 encodedPosition = worldPosition / worldVolumeBoundary;
			encodedPosition += float3(1.0f, 1.0f, 1.0f);
			encodedPosition /= 2.0f;
			return encodedPosition;
		}

		float4 frag_debug_progressive (v2f i) : SV_Target
		{
			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			float4 voxelInfo = GetVoxelInfo(GetVoxelPosition(worldPos));
			return voxelInfo;

		}

		float4 frag_debug_normal (v2f i) : SV_Target
		{
			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			float3 voxelNormal = GetVoxelNormal(GetVoxelPosition(worldPos));
			return float4(voxelNormal, 1.0f);

		}

		float4 frag_debug_irradiance (v2f i) : SV_Target
		{
			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			float3 irradiance = GetVoxelIrradiance(GetVoxelPosition(worldPos));
			return float4(irradiance, 1.0f);

		}

		float4 frag_lighting (v2f i) : SV_Target
		{
			float metallic = tex2D (_CameraGBufferTexture1, i.uv).r;

			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			float4 gBufferSample = tex2D(_CameraGBufferTexture0, i.uv);
			float3 albedo = gBufferSample.rgb;
			float ao = gBufferSample.a;

			float3 voxelIrradiance = GetVoxelIrradiance(GetVoxelPosition(worldPos));

			float3 direct = tex2D(_MainTex, i.uv).rgb;
			float3 indirect = (((ao * indirectLightingStrength * (1.0f - metallic)) / PI) * (albedo * voxelIrradiance));
			float3 finalLighting = direct + indirect;

			return float4(finalLighting, 1.0f);

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

		// 1 : World Normal Writing pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_normal
			ENDCG
		}

		// 2 : Progressive Debug pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_debug_progressive
			ENDCG
		}

		// 3 : Normal Debug pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_debug_normal
			ENDCG
		}

		// 4: Irradiance Debug pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_debug_irradiance
			ENDCG
		}

		// 3 : Lighting accumulation pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_lighting
			ENDCG
		}
	}
}