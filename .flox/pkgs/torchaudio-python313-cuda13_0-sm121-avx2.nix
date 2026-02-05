# TorchAudio optimized for NVIDIA DGX Spark (SM121) + AVX2
# Package name: torchaudio-python313-cuda13_0-sm121-avx2

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs with CUDA 13.0 (SM121 recognized natively)
  # TODO: Pin to nixpkgs commit where cudaPackages defaults to CUDA 13.0
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;  # Required for CUDA packages
      cudaSupport = true;
    };
  };

  # GPU target: SM121 (DGX Spark - specialized datacenter)
  gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
  gpuArchSM = "12.1";      # For TORCH_CUDA_ARCH_LIST (dot notation)

  # CPU optimization: AVX2 (broad x86-64 compatibility)
  cpuFlags = [
    "-mavx2"       # AVX2 instructions
    "-mfma"        # Fused multiply-add
    "-mf16c"       # Half-precision conversions
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # For now, using nixpkgs pytorch with similar configuration
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
  # Override torchaudio to use our custom pytorch
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda13_0-sm121-avx2";

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
      echo "GPU Target: SM121 (DGX Spark - Specialized Datacenter)"
      echo "CPU Features: AVX2"
      echo "CUDA: 13.0 (Compute Capability 12.1)"
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
        - CUDA: 13.0
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: DGX Spark specialized datacenter GPUs
        - CPU: Intel Haswell+ (2013+), AMD Excavator+ (2015+)
        - Driver: NVIDIA 570+ required

        NOTE: This package depends on a matching PyTorch variant.
        Ensure pytorch-python313-cuda13_0-sm121-avx2 is installed.

        Choose this if: You need broad x86-64 CPU compatibility with DGX Spark.
        For newer CPUs, consider avx512 variants for better performance.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
