# TorchAudio optimized for NVIDIA DRIVE Thor (SM110) + AVX-512 BF16
# Package name: torchaudio-python313-cuda13_0-sm110-avx512bf16

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision with CUDA 13.0 (required for SM110)
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;  # Required for CUDA packages
      cudaSupport = true;
    };
  };

  # GPU target: SM110 (NVIDIA DRIVE Thor/Orin+ - Automotive/Edge)
  gpuArchNum = "110";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
  gpuArchSM = "sm_110";      # For TORCH_CUDA_ARCH_LIST (with sm_ prefix)

  # CPU optimization: AVX-512 with BF16 (Brain Float 16)
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mavx512bf16" # Brain Float 16 instructions (ML training acceleration)
    "-mfma"        # Fused multiply-add
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
    pname = "torchaudio-python313-cuda13_0-sm110-avx512bf16";

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
      echo "GPU Target: SM110 (NVIDIA DRIVE Thor/Orin+)"
      echo "CPU Features: AVX-512 + BF16"
      echo "CUDA: 13.0 (Compute Capability 11.0)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA DRIVE Thor (SM110) + AVX-512 BF16";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA DRIVE Thor/Orin+ (SM110) - Automotive/Edge AI
        - CPU: x86-64 with AVX-512 BF16 instruction set
        - CUDA: 13.0 with compute capability 11.0
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: NVIDIA DRIVE Thor, Orin+ (Automotive/Embedded platforms)
        - CPU: Intel Sapphire Rapids+ (2023+), AMD Zen 4+ (2022+)
        - Driver: NVIDIA 570+ required

        BF16 acceleration for ML training workloads.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
