using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class PVGI : MonoBehaviour {

	public enum DebugVoxelGrid {
		PROGRESSIVE,
		NORMAL,
		IRRADIANCE
	};

	[Header("Debug Settings")]
	public bool debugMode = false;
	public DebugVoxelGrid debugVoxelGrid = DebugVoxelGrid.PROGRESSIVE;

	[Header("Shaders")]
	public Shader pvgiShader = null;
	public ComputeShader voxelGridEntryShader = null;
	public ComputeShader voxelGridCleanupShader = null;
	public ComputeShader voxelGridRayTracerShader = null;

	[Header("General Settings")]
	public Vector2Int resolution = Vector2Int.zero;
	public float indirectLightingStrength = 1.0f;

	[Header("Voxelization Settings")]
	public float worldVolumeBoundary = 10.0f;
	public int voxelVolumeDimension = 32;
	public float voxelizationDepth = 0.1f;

	[Header("Ray Trace Settings")]
	public float rayDistance = 30.0f;
	public int maximumIterations = 50;

	private RenderTexture lightingTexture = null;
	private RenderTexture positionTexture = null;
	private RenderTexture normalTexture = null;

	private Material pvgiMaterial = null;

	private RenderTextureDescriptor voxelGridDescriptorFloat4;

	private struct VoxelGrid
	{
		// Direct Lit Color and occupied flag
		public RenderTexture voxelGridProgressive;
		public RenderTexture voxelGridIrradiance;
		public RenderTexture voxelGridNormal;
	};

	private VoxelGrid voxelGrid;

	// Use this for initialization
	void Start () {

		Screen.SetResolution (resolution.x, resolution.y, true);

		GetComponent<Camera> ().depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.DepthNormals;

		if (pvgiShader != null) {

			pvgiMaterial = new Material (pvgiShader);

		}

		InitializeVoxelGrid();

		lightingTexture = new RenderTexture (voxelVolumeDimension, voxelVolumeDimension, 0, RenderTextureFormat.ARGBFloat);
		positionTexture = new RenderTexture (voxelVolumeDimension, voxelVolumeDimension, 0, RenderTextureFormat.ARGBFloat);
		normalTexture = new RenderTexture (voxelVolumeDimension, voxelVolumeDimension, 0, RenderTextureFormat.ARGBFloat);

	}

	// Function to initialize the voxel grid data
	private void InitializeVoxelGrid() {

		voxelGridDescriptorFloat4 = new RenderTextureDescriptor ();
		voxelGridDescriptorFloat4.bindMS = false;
		voxelGridDescriptorFloat4.colorFormat = RenderTextureFormat.ARGBFloat;
		voxelGridDescriptorFloat4.depthBufferBits = 0;
		voxelGridDescriptorFloat4.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
		voxelGridDescriptorFloat4.enableRandomWrite = true;
		voxelGridDescriptorFloat4.height = voxelVolumeDimension;
		voxelGridDescriptorFloat4.msaaSamples = 1;
		voxelGridDescriptorFloat4.volumeDepth = voxelVolumeDimension;
		voxelGridDescriptorFloat4.width = voxelVolumeDimension;
		voxelGridDescriptorFloat4.sRGB = true;

		voxelGrid.voxelGridProgressive = new RenderTexture (voxelGridDescriptorFloat4);
		voxelGrid.voxelGridIrradiance = new RenderTexture (voxelGridDescriptorFloat4);
		voxelGrid.voxelGridNormal = new RenderTexture (voxelGridDescriptorFloat4);

		voxelGrid.voxelGridProgressive.filterMode = FilterMode.Bilinear;
		voxelGrid.voxelGridIrradiance.filterMode = FilterMode.Bilinear;
		voxelGrid.voxelGridNormal.filterMode = FilterMode.Bilinear;

		voxelGrid.voxelGridProgressive.Create ();
		voxelGrid.voxelGridIrradiance.Create ();
		voxelGrid.voxelGridNormal.Create ();

	}

	// Function to update data in the voxel grid
	private void UpdateVoxelGrid () {

		// Kernel index for the entry point in compute shader
		int kernelHandle = voxelGridEntryShader.FindKernel("CSMain");

		// Updating voxel grid
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGridProgressive", voxelGrid.voxelGridProgressive);
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGridNormal", voxelGrid.voxelGridNormal);
		voxelGridEntryShader.SetInt("voxelVolumeDimension", voxelVolumeDimension);
		voxelGridEntryShader.SetFloat ("voxelizationDepth", voxelizationDepth);
		voxelGridEntryShader.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridEntryShader.SetTexture(kernelHandle, "lightingTexture", lightingTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "positionTexture", positionTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "normalTexture", normalTexture);

		voxelGridEntryShader.Dispatch(kernelHandle, voxelVolumeDimension, voxelVolumeDimension, 1);

	}

	// Function to cleanup the voxel grid irradiance
	private void CleanupVoxelGrid () {

		// Kernel index for the entry point in compute shader
		int kernelHandle = voxelGridCleanupShader.FindKernel("CSMain");
		voxelGridCleanupShader.SetTexture(kernelHandle, "voxelGridIrradiance", voxelGrid.voxelGridIrradiance);
		voxelGridCleanupShader.Dispatch(kernelHandle, voxelVolumeDimension, voxelVolumeDimension, voxelVolumeDimension);

	}

	// Function to ray trace through the voxel grid
	private void RayTraceVoxelGrid () {
	
		// Kernel index for the entry point in compute shader
		int kernelHandle = voxelGridCleanupShader.FindKernel("CSMain");
		voxelGridRayTracerShader.SetTexture(kernelHandle, "voxelGridProgressive", voxelGrid.voxelGridProgressive);
		voxelGridRayTracerShader.SetTexture(kernelHandle, "voxelGridNormal", voxelGrid.voxelGridNormal);
		voxelGridRayTracerShader.SetTexture(kernelHandle, "voxelGridIrradiance", voxelGrid.voxelGridIrradiance);
		voxelGridRayTracerShader.SetFloat("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridRayTracerShader.SetFloat("rayDistance", rayDistance);
		voxelGridRayTracerShader.SetFloat("maximumIterations", (float)maximumIterations);
		voxelGridRayTracerShader.SetInt("voxelVolumeDimension", voxelVolumeDimension);
		voxelGridRayTracerShader.SetTexture(kernelHandle, "positionTexture", positionTexture);
		voxelGridRayTracerShader.SetTexture(kernelHandle, "normalTexture", normalTexture);
		voxelGridRayTracerShader.Dispatch(kernelHandle, voxelVolumeDimension, voxelVolumeDimension, voxelVolumeDimension);

	}

	// This is called once per frame after the scene is rendered
	void OnRenderImage (RenderTexture source, RenderTexture destination) {

		pvgiMaterial.SetTexture("voxelGridProgressive", voxelGrid.voxelGridProgressive);
		pvgiMaterial.SetTexture("voxelGridIrradiance", voxelGrid.voxelGridIrradiance);
		pvgiMaterial.SetTexture("voxelGridNormal", voxelGrid.voxelGridNormal);
		pvgiMaterial.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		pvgiMaterial.SetMatrix ("InverseViewMatrix", GetComponent<Camera>().cameraToWorldMatrix);
		pvgiMaterial.SetMatrix ("InverseProjectionMatrix", GetComponent<Camera>().projectionMatrix.inverse);
		pvgiMaterial.SetInt ("voxelVolumeDimension", voxelVolumeDimension);
		pvgiMaterial.SetFloat ("indirectLightingStrength", indirectLightingStrength);

		Graphics.Blit (source, lightingTexture);
		Graphics.Blit (source, positionTexture, pvgiMaterial, 0);
		Graphics.Blit (source, normalTexture, pvgiMaterial, 1);

		CleanupVoxelGrid ();

		UpdateVoxelGrid ();

		RayTraceVoxelGrid ();

		if (debugMode) {

			if (debugVoxelGrid == DebugVoxelGrid.PROGRESSIVE) {
				Graphics.Blit (source, destination, pvgiMaterial, 2);
			} else if (debugVoxelGrid == DebugVoxelGrid.NORMAL) {
				Graphics.Blit (source, destination, pvgiMaterial, 3);
			} else {
				Graphics.Blit (source, destination, pvgiMaterial, 4);
			}
		} else {
			Graphics.Blit (source, destination, pvgiMaterial, 5);
		}

	}

}
