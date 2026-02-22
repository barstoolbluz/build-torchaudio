# TorchAudio with PyTorch 2.10.0 for NVIDIA Blackwell DC (SM100: B100/B200) + AVX-512 BF16 (no MAGMA)
# Package name: torchaudio-python313-cuda13_0-sm100-avx512bf16-nomagma
#
# NOTE: This uses the same PyTorch 2.10.0 overlay approach as build-pytorch.
# See build-pytorch/docs/pytorch-2.10-cuda13-build-notes.md for details on fixes.
#
# CUDA 13.0 compatibility patches:
# - OpenCV: https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision with CUDA 13.0
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = {
      allowUnfree = true;
      allowBroken = true;
      cudaSupport = true;
    };
    overlays = [
      # Overlay 1: Use CUDA 13.0
      (final: prev: { cudaPackages = final.cudaPackages_13; })
      # Overlay 2: Patch OpenCV for CUDA 13.0 compatibility
      # This fixes: 'struct cudaDeviceProp' has no member named 'clockRate' (and others)
      # PR #27636: https://github.com/opencv/opencv/pull/27636
      # Also patches opencv_contrib for thrust::not1 removal (commit 9a9b173)
      (final: prev: {
        opencv = prev.opencv.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            (final.fetchpatch {
              name = "opencv-cuda-13.0-deviceprop-fix.patch";
              url = "https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7.patch";
              hash = "sha256-zeDA8K7k6Sff5Xw/9XmqbCg/dhj9iu095rXuZTdj8PY=";
            })
          ];

          # Patch opencv_contrib for CUDA 13.0 (thrust::not1 removal)
          postPatch = (oldAttrs.postPatch or "") + ''
            if [ -d "opencv_contrib" ]; then
              echo "Patching opencv_contrib for CUDA 13.0 (thrust::not1 removal)..."
              patch -p2 -d opencv_contrib < ${final.fetchpatch {
                name = "opencv-contrib-cuda-13.0-videostab-fix.patch";
                url = "https://github.com/opencv/opencv_contrib/commit/9a9b173cd178e7c07a98896a009c2a2021a6b247.patch";
                hash = "sha256-W3eBv7HnoUrNBupXAykv5UsHcYG/o9P55VIddRYWrF8=";
              }}
            fi
          '';
        });
      })

      # Overlay 3: Upgrade PyTorch to 2.10.0
      (final: prev: {
        python3Packages = prev.python3Packages.override {
          overrides = pfinal: pprev: {
            torch = pprev.torch.overrideAttrs (oldAttrs: rec {
              version = "2.10.0";

              src = prev.fetchFromGitHub {
                owner = "pytorch";
                repo = "pytorch";
                rev = "v${version}";
                hash = "sha256-RKiZLHBCneMtZKRgTEuW1K7+Jpi+tx11BMXuS1jC1xQ=";
                fetchSubmodules = true;
              };

              # Clear patches - nixpkgs patches are for 2.9.1 and won't apply to 2.10.0
              patches = [];
            });
          };
        };
      })
    ];
  };


  # Helper to filter MAGMA from dependency lists (nomagma variant)
  filterMagma = deps: builtins.filter (d:
    !(nixpkgs_pinned.lib.hasPrefix "magma" (d.pname or d.name or ""))
  ) deps;

  # GPU target: SM100 (Blackwell DC - B100/B200)
  gpuArchSM = "10.0";

  # CPU optimization: AVX-512 with BF16
  cpuFlags = [
    "-mavx512f"     # AVX-512 Foundation
    "-mavx512dq"    # Doubleword and Quadword instructions
    "-mavx512vl"    # Vector Length extensions
    "-mavx512bw"    # Byte and Word instructions
    "-mavx512bf16"  # BFloat16 instructions
    "-mfma"         # Fused multiply-add
  ];

  # Custom PyTorch 2.10.0 with all CUDA 13.0 fixes
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    pname = "pytorch210-for-torchaudio-sm100-avx512bf16-nomagma";

    # Filter MAGMA from all dependency lists
    buildInputs = filterMagma (oldAttrs.buildInputs or []);
    nativeBuildInputs = filterMagma (oldAttrs.nativeBuildInputs or []);
    propagatedBuildInputs = filterMagma (oldAttrs.propagatedBuildInputs or []);

    # Clear patches
    patches = [];

    # Limit build parallelism
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    # CMake flags for CUDA 13.0 compatibility
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DTORCH_BUILD_VERSION=2.10.0"
      "-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat"
      "-DCUDA_VERSION=13.0"
      "-DUSE_MAGMA=OFF"
    ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export USE_MAGMA=0
      export MAX_JOBS=32

      # Version fixes for PyTorch 2.10.0
      export PYTORCH_BUILD_VERSION=2.10.0
      echo "2.10.0" > version.txt

      # CCCL header path compatibility for CUTLASS
      mkdir -p /build/cccl-compat/cccl
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cuda /build/cccl-compat/cccl/cuda
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cub /build/cccl-compat/cccl/cub
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/thrust /build/cccl-compat/cccl/thrust
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/nv /build/cccl-compat/cccl/nv
      export CXXFLAGS="-I/build/cccl-compat $CXXFLAGS"
      export CFLAGS="-I/build/cccl-compat $CFLAGS"
      export CUDAFLAGS="-I/build/cccl-compat $CUDAFLAGS"
    '';

    # FindCUDAToolkit.cmake delegating stub
    # Uses CMAKE_ROOT to directly include CMake's built-in module, avoiding infinite recursion when installed
    postPatch = (oldAttrs.postPatch or "") + ''
      mkdir -p cmake/Modules
      cat > cmake/Modules/FindCUDAToolkit.cmake << 'EOF'
# Delegating stub for FindCUDAToolkit
# Directly include CMake's built-in module to avoid infinite recursion
if(NOT CUDAToolkit_FOUND)
  include(''${CMAKE_ROOT}/Modules/FindCUDAToolkit.cmake)
endif()
EOF
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda13_0-sm100-avx512bf16-nomagma";

    # Propagate pytorch's out output for transitive torch availability
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ customPytorch.out ];

    # Limit build parallelism
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: ${gpuArchSM} (Blackwell DC: B100/B200)"
      echo "CPU Features: AVX-512 + BF16"
      echo "CUDA: 13.0"
      echo "PyTorch: 2.10.0 (with CUDA 13.0 fixes)"
      echo "MAGMA: Disabled (nomagma variant - using cuSOLVER)"
      echo "TorchAudio: ${oldAttrs.version}"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA B100/B200 (SM100, Blackwell DC) + AVX-512 BF16 with PyTorch 2.10.0 (no MAGMA)";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Blackwell datacenter architecture (SM100) - B100/B200
        - CPU: x86-64 with AVX-512 BF16 instruction set
        - CUDA: 13.0 with compute capability 10.0
        - PyTorch: 2.10.0 (with all CUDA 13.0 compatibility fixes)
        - MAGMA: Disabled (using cuSOLVER for linear algebra)
        - Python: 3.13

        Hardware requirements:
        - GPU: B100, B200, or other SM100 GPUs
        - CPU: Intel Cooper Lake+ (2020+), AMD Zen 4+ (2022+)
        - Driver: NVIDIA 580+ required
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
