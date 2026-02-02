# TorchAudio optimized for NVIDIA Blackwell B300 (SM103) + ARMv8.2
# Package name: torchaudio-python313-cuda12_9-sm103-armv8_2

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision with CUDA 12.9 (required for SM103)
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;  # Required for CUDA packages
      cudaSupport = true;
    };
  };

  # GPU target: SM103 (Blackwell B300 - Datacenter)
  gpuArchNum = "103";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
  gpuArchSM = "sm_103";      # For TORCH_CUDA_ARCH_LIST (with sm_ prefix)

  # CPU optimization: ARMv8.2 with FP16 and dot product
  cpuFlags = [
    "-march=armv8.2-a+fp16+dotprod"  # ARMv8.2 with half-precision and dot product
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_9-sm103-armv8_2";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: SM103 (Blackwell B300 Datacenter)"
      echo "CPU Features: ARMv8.2 + FP16 + DotProd"
      echo "CUDA: 12.9 (Compute Capability 10.3)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA Blackwell B300 (SM103) + ARMv8.2";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Blackwell B300 (SM103) - Datacenter
        - CPU: ARMv8.2 with FP16 and dot product instructions
        - CUDA: 12.9 with compute capability 10.3
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: NVIDIA Blackwell B300 datacenter GPUs
        - CPU: AWS Graviton2, NVIDIA Grace platforms
        - Driver: NVIDIA 570+ required

        Optimized for ARM-based datacenter platforms.
      '';
      platforms = [ "aarch64-linux" ];
    };
  })
