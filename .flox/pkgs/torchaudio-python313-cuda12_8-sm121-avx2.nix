# TorchAudio optimized for NVIDIA DGX Spark (SM121) + AVX2
# Package name: torchaudio-python313-cuda12_8-sm121-avx2

{ python3Packages
, lib
, config
, cudaPackages
, addDriverRunpath
, fetchPypi
}:

let
  # GPU target: SM121 (DGX Spark - specialized datacenter)
  gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
  gpuArchSM = "sm_121";      # For TORCH_CUDA_ARCH_LIST (with sm_ prefix)

  # CPU optimization: AVX2 (broad x86-64 compatibility)
  cpuFlags = [
    "-mavx2"       # AVX2 instructions
    "-mfma"        # Fused multiply-add
    "-mf16c"       # Half-precision conversions
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # TODO: Reference the actual pytorch package from build-pytorch
  # For now, using nixpkgs pytorch with similar configuration
  customPytorch = (python3Packages.pytorch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  });

in
  # Override torchaudio to use our custom pytorch
  (python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_8-sm121-avx2";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: SM121 (DGX Spark - Specialized Datacenter)"
      echo "CPU Features: AVX2"
      echo "CUDA: 12.8 (Compute Capability 12.1)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA DGX Spark (SM121) + AVX2";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA DGX Spark (SM121, Compute Capability 12.1)
        - CPU: x86-64 with AVX2 instruction set (broad compatibility)
        - CUDA: 12.8
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: DGX Spark specialized datacenter GPUs
        - CPU: Intel Haswell+ (2013+), AMD Excavator+ (2015+)
        - Driver: NVIDIA 570+ required

        NOTE: This package depends on a matching PyTorch variant.
        Ensure pytorch-python313-cuda12_8-sm121-avx2 is installed.

        Choose this if: You need broad x86-64 CPU compatibility with DGX Spark.
        For newer CPUs, consider avx512 variants for better performance.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
