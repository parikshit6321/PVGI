using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class PVGI : MonoBehaviour {

	public enum DebugVoxelGrid {
		GRID_1,
		GRID_2,
		GRID_3,
		GRID_4,
		GRID_5
	};

	[Header("Debug Settings")]
	public bool debugMode = false;
	public DebugVoxelGrid debugVoxelGrid = DebugVoxelGrid.GRID_1;

	[Header("Shaders")]
	public Shader pvgiShader = null;
	public ComputeShader voxelGridEntryShader = null;

	[Header("General Settings")]
	public Vector2Int resolution = Vector2Int.zero;
	public float indirectLightingStrength = 1.0f;

	[Header("Voxelization Settings")]
	public float worldVolumeBoundary = 10.0f;
	public int highestVoxelResolution = 256;
	public Vector2Int injectionTextureResolution = Vector2Int.zero;

	[Header("Cone Trace Settings")]
	public int maximumIterations = 50;

	private RenderTexture lightingTexture = null;
	private RenderTexture positionTexture = null;

	private Material pvgiMaterial = null;

	private RenderTextureDescriptor voxelGridDescriptorFloat4;

	public RenderTexture voxelGrid1;
	public RenderTexture voxelGrid2;
	public RenderTexture voxelGrid3;
	public RenderTexture voxelGrid4;
	public RenderTexture voxelGrid5;

	// Use this for initialization
	void Start () {

		Screen.SetResolution (resolution.x, resolution.y, true);

		GetComponent<Camera> ().depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.DepthNormals;

		if (pvgiShader != null) {

			pvgiMaterial = new Material (pvgiShader);

		}

		InitializeVoxelGrid();

		lightingTexture = new RenderTexture (injectionTextureResolution.x, injectionTextureResolution.y, 0, RenderTextureFormat.ARGBFloat);
		positionTexture = new RenderTexture (injectionTextureResolution.x, injectionTextureResolution.y, 0, RenderTextureFormat.ARGBFloat);

	}

	// Function to initialize the voxel grid data
	private void InitializeVoxelGrid() {

		voxelGridDescriptorFloat4 = new RenderTextureDescriptor ();
		voxelGridDescriptorFloat4.bindMS = false;
		voxelGridDescriptorFloat4.colorFormat = RenderTextureFormat.ARGBFloat;
		voxelGridDescriptorFloat4.depthBufferBits = 0;
		voxelGridDescriptorFloat4.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
		voxelGridDescriptorFloat4.enableRandomWrite = true;
		voxelGridDescriptorFloat4.width = highestVoxelResolution;
		voxelGridDescriptorFloat4.height = highestVoxelResolution;
		voxelGridDescriptorFloat4.volumeDepth = highestVoxelResolution;
		voxelGridDescriptorFloat4.msaaSamples = 1;
		voxelGridDescriptorFloat4.sRGB = true;

		voxelGrid1 = new RenderTexture (voxelGridDescriptorFloat4);

		voxelGridDescriptorFloat4.width = highestVoxelResolution / 2;
		voxelGridDescriptorFloat4.height = highestVoxelResolution / 2;
		voxelGridDescriptorFloat4.volumeDepth = highestVoxelResolution / 2;

		voxelGrid2 = new RenderTexture (voxelGridDescriptorFloat4);

		voxelGridDescriptorFloat4.width = highestVoxelResolution / 4;
		voxelGridDescriptorFloat4.height = highestVoxelResolution / 4;
		voxelGridDescriptorFloat4.volumeDepth = highestVoxelResolution / 4;

		voxelGrid3 = new RenderTexture (voxelGridDescriptorFloat4);

		voxelGridDescriptorFloat4.width = highestVoxelResolution / 8;
		voxelGridDescriptorFloat4.height = highestVoxelResolution / 8;
		voxelGridDescriptorFloat4.volumeDepth = highestVoxelResolution / 8;

		voxelGrid4 = new RenderTexture (voxelGridDescriptorFloat4);

		voxelGridDescriptorFloat4.width = highestVoxelResolution / 16;
		voxelGridDescriptorFloat4.height = highestVoxelResolution / 16;
		voxelGridDescriptorFloat4.volumeDepth = highestVoxelResolution / 16;

		voxelGrid5 = new RenderTexture (voxelGridDescriptorFloat4);

		voxelGrid1.filterMode = FilterMode.Trilinear;
		voxelGrid2.filterMode = FilterMode.Trilinear;
		voxelGrid3.filterMode = FilterMode.Trilinear;
		voxelGrid4.filterMode = FilterMode.Trilinear;
		voxelGrid5.filterMode = FilterMode.Trilinear;

		voxelGrid1.Create ();
		voxelGrid2.Create ();
		voxelGrid3.Create ();
		voxelGrid4.Create ();
		voxelGrid5.Create ();

	}

	// Function to update data in the voxel grid
	private void UpdateVoxelGrid () {

		// Kernel index for the entry point in compute shader
		int kernelHandle = voxelGridEntryShader.FindKernel("CSMain");

		// Updating voxel grid 1
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGrid", voxelGrid1);
		voxelGridEntryShader.SetInt("voxelResolution", highestVoxelResolution);
		voxelGridEntryShader.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridEntryShader.SetTexture(kernelHandle, "lightingTexture", lightingTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "positionTexture", positionTexture);

		voxelGridEntryShader.Dispatch(kernelHandle, injectionTextureResolution.x, injectionTextureResolution.y, 1);

		// Updating voxel grid 2
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGrid", voxelGrid2);
		voxelGridEntryShader.SetInt("voxelResolution", highestVoxelResolution / 2);
		voxelGridEntryShader.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridEntryShader.SetTexture(kernelHandle, "lightingTexture", lightingTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "positionTexture", positionTexture);

		voxelGridEntryShader.Dispatch(kernelHandle, injectionTextureResolution.x, injectionTextureResolution.y, 1);

		// Updating voxel grid 3
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGrid", voxelGrid3);
		voxelGridEntryShader.SetInt("voxelResolution", highestVoxelResolution / 4);
		voxelGridEntryShader.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridEntryShader.SetTexture(kernelHandle, "lightingTexture", lightingTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "positionTexture", positionTexture);

		voxelGridEntryShader.Dispatch(kernelHandle, injectionTextureResolution.x, injectionTextureResolution.y, 1);

		// Updating voxel grid 4
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGrid", voxelGrid4);
		voxelGridEntryShader.SetInt("voxelResolution", highestVoxelResolution / 8);
		voxelGridEntryShader.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridEntryShader.SetTexture(kernelHandle, "lightingTexture", lightingTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "positionTexture", positionTexture);

		voxelGridEntryShader.Dispatch(kernelHandle, injectionTextureResolution.x, injectionTextureResolution.y, 1);

		// Updating voxel grid 5
		voxelGridEntryShader.SetTexture(kernelHandle, "voxelGrid", voxelGrid5);
		voxelGridEntryShader.SetInt("voxelResolution", highestVoxelResolution / 16);
		voxelGridEntryShader.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		voxelGridEntryShader.SetTexture(kernelHandle, "lightingTexture", lightingTexture);
		voxelGridEntryShader.SetTexture(kernelHandle, "positionTexture", positionTexture);

		voxelGridEntryShader.Dispatch(kernelHandle, injectionTextureResolution.x, injectionTextureResolution.y, 1);
	}

	// This is called once per frame after the scene is rendered
	void OnRenderImage (RenderTexture source, RenderTexture destination) {

		pvgiMaterial.SetFloat ("worldVolumeBoundary", worldVolumeBoundary);
		pvgiMaterial.SetMatrix ("InverseViewMatrix", GetComponent<Camera>().cameraToWorldMatrix);
		pvgiMaterial.SetMatrix ("InverseProjectionMatrix", GetComponent<Camera>().projectionMatrix.inverse);
		pvgiMaterial.SetInt ("highestVoxelResolution", highestVoxelResolution);
		pvgiMaterial.SetFloat ("indirectLightingStrength", indirectLightingStrength);

		Graphics.Blit (source, lightingTexture);
		Graphics.Blit (source, positionTexture, pvgiMaterial, 0);

		UpdateVoxelGrid ();

		pvgiMaterial.SetTexture("voxelGrid1", voxelGrid1);
		pvgiMaterial.SetTexture("voxelGrid2", voxelGrid2);
		pvgiMaterial.SetTexture("voxelGrid3", voxelGrid3);
		pvgiMaterial.SetTexture("voxelGrid4", voxelGrid4);
		pvgiMaterial.SetTexture("voxelGrid5", voxelGrid5);

		if (debugMode) {
			if (debugVoxelGrid == DebugVoxelGrid.GRID_1) {
				pvgiMaterial.EnableKeyword ("GRID_1");
				pvgiMaterial.DisableKeyword ("GRID_2");
				pvgiMaterial.DisableKeyword ("GRID_3");
				pvgiMaterial.DisableKeyword ("GRID_4");
				pvgiMaterial.DisableKeyword ("GRID_5");
			} else if (debugVoxelGrid == DebugVoxelGrid.GRID_2) {
				pvgiMaterial.DisableKeyword ("GRID_1");
				pvgiMaterial.EnableKeyword ("GRID_2");
				pvgiMaterial.DisableKeyword ("GRID_3");
				pvgiMaterial.DisableKeyword ("GRID_4");
				pvgiMaterial.DisableKeyword ("GRID_5");
			} else if (debugVoxelGrid == DebugVoxelGrid.GRID_3) {
				pvgiMaterial.DisableKeyword ("GRID_1");
				pvgiMaterial.DisableKeyword ("GRID_2");
				pvgiMaterial.EnableKeyword ("GRID_3");
				pvgiMaterial.DisableKeyword ("GRID_4");
				pvgiMaterial.DisableKeyword ("GRID_5");
			} else if (debugVoxelGrid == DebugVoxelGrid.GRID_4) {
				pvgiMaterial.DisableKeyword ("GRID_1");
				pvgiMaterial.DisableKeyword ("GRID_2");
				pvgiMaterial.DisableKeyword ("GRID_3");
				pvgiMaterial.EnableKeyword ("GRID_4");
				pvgiMaterial.DisableKeyword ("GRID_5");
			} else {
				pvgiMaterial.DisableKeyword ("GRID_1");
				pvgiMaterial.DisableKeyword ("GRID_2");
				pvgiMaterial.DisableKeyword ("GRID_3");
				pvgiMaterial.DisableKeyword ("GRID_4");
				pvgiMaterial.EnableKeyword ("GRID_5");
			}

			Graphics.Blit (source, destination, pvgiMaterial, 1);
		} else {
			Graphics.Blit (source, destination, pvgiMaterial, 2);
		}

	}

}