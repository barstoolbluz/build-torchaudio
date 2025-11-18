# TorchAudio optimized for NVIDIA DGX Spark (SM121) + AVX-512 BF16
# Package name: torchaudio-python313-cuda12_8-sm121-avx512bf16

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

  # CPU optimization: AVX-512 with BF16 support
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mavx512bf16" # BF16 (Brain Float16) instructions
    "-mfma"        # Fused multiply-add
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
    pname = "torchaudio-python313-cuda12_8-sm121-avx512bf16";

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
      echo "CPU Features: AVX-512 + BF16"
      echo "CUDA: 12.8 (Compute Capability 12.1)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA DGX Spark (SM121) + AVX-512 BF16";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA DGX Spark (SM121, Compute Capability 12.1)
        - CPU: x86-64 with AVX-512 + BF16 instruction set
        - CUDA: 12.8
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: DGX Spark specialized datacenter GPUs
        - CPU: Intel Sapphire Rapids+ (2023+), AMD Genoa+ (2022+)
        - Driver: NVIDIA 570+ required

        NOTE: This package depends on a matching PyTorch variant.
        Ensure pytorch-python313-cuda12_8-sm121-avx512bf16 is installed.

        Choose this if: You have DGX Spark with latest datacenter CPUs and
        need BF16 training acceleration. BF16 provides better numerical
        stability than FP16 for training workloads.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
