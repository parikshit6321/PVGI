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
		uniform float					lengthOfCone;
		uniform float					maximumIterations;

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

		// Returns the voxel position in the grids
		inline float3 GetVoxelPosition(float3 worldPosition)
		{
			float3 voxelPosition = worldPosition / worldVolumeBoundary;
			voxelPosition += float3(1.0f, 1.0f, 1.0f);
			voxelPosition /= 2.0f;
			return voxelPosition;
		}

		// Returns the voxel information from grid 1
		inline float4 GetVoxelInfo1(float3 voxelPosition)
		{
			float4 info = tex3D(voxelGrid1, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 2
		inline float4 GetVoxelInfo2(float3 voxelPosition)
		{
			float4 info = tex3D(voxelGrid2, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 3
		inline float4 GetVoxelInfo3(float3 voxelPosition)
		{
			float4 info = tex3D(voxelGrid3, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 4
		inline float4 GetVoxelInfo4(float3 voxelPosition)
		{
			float4 info = tex3D(voxelGrid4, voxelPosition);
			return info;
		}

		// Returns the voxel information from grid 5
		inline float4 GetVoxelInfo5(float3 voxelPosition)
		{
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
			voxelInfo = GetVoxelInfo1(GetVoxelPosition(worldPos));
			#endif

			#if defined(GRID_2)
			voxelInfo = GetVoxelInfo2(GetVoxelPosition(worldPos));
			#endif

			#if defined(GRID_3)
			voxelInfo = GetVoxelInfo3(GetVoxelPosition(worldPos));
			#endif

			#if defined(GRID_4)
			voxelInfo = GetVoxelInfo4(GetVoxelPosition(worldPos));
			#endif

			#if defined(GRID_5)
			voxelInfo = GetVoxelInfo5(GetVoxelPosition(worldPos));
			#endif

			float3 resultingColor = (voxelInfo.a > 0.0f ? voxelInfo.rgb : float3(0.0f, 0.0f, 0.0f));
			return float4(resultingColor, 1.0f);
		}

		inline float3 ConeTrace(float3 worldPosition, float3 coneDirection)
		{
			float3 computedColor = float3(0.0f, 0.0f, 0.0f);

			float coneStep = lengthOfCone / maximumIterations;

			float iteration0 = maximumIterations / 32.0f;
			float iteration1 = maximumIterations / 32.0f;
			float iteration2 = maximumIterations / 16.0f;
			float iteration3 = maximumIterations / 8.0f;
			float iteration4 = maximumIterations / 4.0f;
			float iteration5 = maximumIterations / 2.0f;

			float3 coneOrigin = worldPosition + (coneDirection * coneStep * iteration0);

			float3 currentPosition = coneOrigin;
			float4 currentVoxelInfo = float4(0.0f, 0.0f, 0.0f, 0.0f);

			float hitFound = 0.0f;

			// Sample voxel grid 1
			for (float i1 = 0.0f; i1 < iteration1; i1 += 1.0f)
			{
				currentPosition += (coneStep * coneDirection);

				if (hitFound < 0.9f)
				{
					currentVoxelInfo = GetVoxelInfo1(GetVoxelPosition(currentPosition));
					if (currentVoxelInfo.a > 0.0f)
					{
						hitFound = 1.0f;
					}
				}
			}

			// Sample voxel grid 2
			for (float i2 = 0.0f; i2 < iteration2; i2 += 1.0f)
			{
				currentPosition += (coneStep * coneDirection);

				if (hitFound < 0.9f)
				{
					currentVoxelInfo = GetVoxelInfo2(GetVoxelPosition(currentPosition));
					if (currentVoxelInfo.a > 0.0f)
					{
						hitFound = 1.0f;
					}
				}
			}

			// Sample voxel grid 3
			for (float i3 = 0.0f; i3 < iteration3; i3 += 1.0f)
			{
				currentPosition += (coneStep * coneDirection);

				if (hitFound < 0.9f)
				{
					currentVoxelInfo = GetVoxelInfo3(GetVoxelPosition(currentPosition));
					if (currentVoxelInfo.a > 0.0f)
					{
						hitFound = 1.0f;
					}
				}
			}

			// Sample voxel grid 4
			for (float i4 = 0.0f; i4 < iteration4; i4 += 1.0f)
			{
				currentPosition += (coneStep * coneDirection);

				if (hitFound < 0.9f)
				{
					currentVoxelInfo = GetVoxelInfo4(GetVoxelPosition(currentPosition));
					if (currentVoxelInfo.a > 0.0f)
					{
						hitFound = 1.0f;
					}
				}
			}

			// Sample voxel grid 5
			for (float i5 = 0.0f; i5 < iteration5; i5 += 1.0f)
			{
				currentPosition += (coneStep * coneDirection);

				if (hitFound < 0.9f)
				{
					currentVoxelInfo = GetVoxelInfo5(GetVoxelPosition(currentPosition));
					if (currentVoxelInfo.a > 0.0f)
					{
						hitFound = 1.0f;
					}
				}
			}

			computedColor = currentVoxelInfo.rgb;

			return computedColor;
		}

		inline float3 ComputeIndirectContribution(float3 worldPosition, float3 worldNormal)
		{
			float3 accumulatedColor = float3(0.0f, 0.0f, 0.0f);

			float3 randomVector = normalize(float3(1.0f, 2.0f, 3.0f));

			float3 direction1 = normalize(cross(worldNormal, randomVector));
			float3 direction2 = -direction1;
			float3 direction3 = normalize(cross(worldNormal, direction1));	// Not used in cone tracing
			float3 direction4 = -direction3; 								// Not used in cone tracing
			float3 direction5 = lerp(direction1, direction3, 0.6667f);
			float3 direction6 = -direction5;
			float3 direction7 = lerp(direction2, direction3, 0.6667f);
			float3 direction8 = -direction7;

			float3 coneDirection1 = worldNormal;
			float3 coneDirection2 = lerp(direction1, worldNormal, 0.3333f);
			float3 coneDirection3 = lerp(direction2, worldNormal, 0.3333f);
			float3 coneDirection4 = lerp(direction5, worldNormal, 0.3333f);
			float3 coneDirection5 = lerp(direction6, worldNormal, 0.3333f);
			float3 coneDirection6 = lerp(direction7, worldNormal, 0.3333f);
			float3 coneDirection7 = lerp(direction8, worldNormal, 0.3333f);

			accumulatedColor += ConeTrace(worldPosition, coneDirection1);
			accumulatedColor += ConeTrace(worldPosition, coneDirection2);
			accumulatedColor += ConeTrace(worldPosition, coneDirection3);
			accumulatedColor += ConeTrace(worldPosition, coneDirection4);
			accumulatedColor += ConeTrace(worldPosition, coneDirection5);
			accumulatedColor += ConeTrace(worldPosition, coneDirection6);
			accumulatedColor += ConeTrace(worldPosition, coneDirection7);

			return accumulatedColor;
		}

		float4 frag_lighting (v2f i) : SV_Target
		{
			float3 directLighting = tex2D(_MainTex, i.uv).rgb;

			float4 gBufferSample = tex2D(_CameraGBufferTexture0, i.uv);
			float3 albedo = gBufferSample.rgb;
			float ao = gBufferSample.a;

			float metallic = tex2D (_CameraGBufferTexture1, i.uv).r;

			// read low res depth and reconstruct world position
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			
			//linearise depth		
			float lindepth = Linear01Depth (depth);
			
			//get view and then world positions		
			float4 viewPos = float4(i.cameraRay.xyz * lindepth, 1.0f);
			float3 worldPos = mul(InverseViewMatrix, viewPos).xyz;

			float depthValue;
			float3 viewSpaceNormal;
			DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture, i.uv), depthValue, viewSpaceNormal);
			viewSpaceNormal = normalize(viewSpaceNormal);
			float3 worldSpaceNormal = mul((float3x3)InverseViewMatrix, viewSpaceNormal);
			worldSpaceNormal = normalize(worldSpaceNormal);

			float3 indirectLighting = ((ao * indirectLightingStrength * (1.0f - metallic) * albedo) / PI) * ComputeIndirectContribution(worldPos, worldSpaceNormal);

			float3 finalLighting = directLighting + indirectLighting;

			return float4(finalLighting, 1.0f);
		}

		ENDCG

		// 0 : World Position Writing pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_position
			#pragma target 5.0
			ENDCG
		}

		// 1 : Voxel Grid debug pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_debug
			#pragma multi_compile GRID_1 GRID_2 GRID_3 GRID_4 GRID_5
			#pragma target 5.0
			ENDCG
		}

		// 2 : Lighting pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_lighting
			#pragma target 5.0
			ENDCG
		}
	}
}