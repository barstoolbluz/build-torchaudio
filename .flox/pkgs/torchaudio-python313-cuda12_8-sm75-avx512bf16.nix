# TorchAudio optimized for NVIDIA Turing T4/RTX 2080 Ti (SM75) + AVX-512 BF16
# Package name: torchaudio-python313-cuda12_8-sm75-avx512bf16

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision where PyTorch 2.8.0 and TorchAudio 2.8.0 are compatible
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;  # Required for CUDA packages
      cudaSupport = true;
    };
  };

  # GPU target: SM75 (Turing T4/RTX 2080 Ti)
  gpuArchNum = "7.5";

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
  # TODO: Reference the actual pytorch package from build-pytorch
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchNum ];
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
    pname = "torchaudio-python313-cuda12_8-sm75-avx512bf16";

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
      echo "GPU Target: SM75 (Turing T4/RTX 2080 Ti)"
      echo "CPU Features: AVX-512 + BF16"
      echo "CUDA: 12.8 (Compute Capability 7.5)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    postInstall = (oldAttrs.postInstall or "") + ''
      echo 1 > $out/.metadata-rev
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA Turing T4/RTX 2080 Ti (SM75) + AVX-512 BF16";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Turing T4/RTX 2080 Ti (SM75)
        - CPU: x86-64 with AVX-512 BF16 instruction set
        - CUDA: 12.8 with compute capability 7.5
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: NVIDIA T4, RTX 2080 Ti, RTX 2080 Super, Quadro RTX 8000
        - CPU: Intel Sapphire Rapids+ (2023+), AMD Zen 4+ (2022+)
        - Driver: NVIDIA 418+ required

        BF16 acceleration for ML training on Turing.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
