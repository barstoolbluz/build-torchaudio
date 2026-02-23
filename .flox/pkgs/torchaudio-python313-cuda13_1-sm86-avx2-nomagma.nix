# TorchAudio with PyTorch 2.10.0 for NVIDIA Ampere (SM86: RTX 3090, A40) + AVX2 (no MAGMA)
# Package name: torchaudio-python313-cuda13_1-sm86-avx2-nomagma
#
# NOTE: This uses the same PyTorch 2.10.0 overlay approach as build-pytorch.
# See build-pytorch/docs/pytorch-2.10-cuda13-build-notes.md for details on fixes.
#
# CUDA 13.1 compatibility patches:
# - OpenCV: https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision with CUDA 13.1
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/2017d6d515f8a7b289fe06d3a880a7ec588c3900.tar.gz";
  }) {
    config = {
      allowUnfree = true;
      allowBroken = true;
      cudaSupport = true;
    };
    overlays = [
      # Overlay 1: Use CUDA 13.1
      (final: prev: { cudaPackages = final.cudaPackages_13_1; })

      # Overlay 2: Upgrade PyTorch to 2.10.0
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

  gpuArchSM = "8.6";
  cpuFlags = [ "-mavx2" "-mfma" "-mf16c" ];

  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    pname = "pytorch210-for-torchaudio-sm86-avx2-nomagma";
    # Filter MAGMA from all dependency lists
    buildInputs = filterMagma (oldAttrs.buildInputs or []);
    nativeBuildInputs = filterMagma (oldAttrs.nativeBuildInputs or []);
    propagatedBuildInputs = filterMagma (oldAttrs.propagatedBuildInputs or []);
    patches = [];
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DTORCH_BUILD_VERSION=2.10.0"
      "-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat"
      "-DCUDA_VERSION=13.1"
      "-DUSE_MAGMA=OFF"
    ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export USE_MAGMA=0
      export MAX_JOBS=32
      export PYTORCH_BUILD_VERSION=2.10.0
      echo "2.10.0" > version.txt
      mkdir -p /build/cccl-compat/cccl
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cuda /build/cccl-compat/cccl/cuda
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cub /build/cccl-compat/cccl/cub
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/thrust /build/cccl-compat/cccl/thrust
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/nv /build/cccl-compat/cccl/nv
      export CXXFLAGS="-I/build/cccl-compat $CXXFLAGS"
      export CFLAGS="-I/build/cccl-compat $CFLAGS"
      export CUDAFLAGS="-I/build/cccl-compat $CUDAFLAGS"
    '';
    postPatch = (oldAttrs.postPatch or "") + ''
      mkdir -p cmake/Modules
      cat > cmake/Modules/FindCUDAToolkit.cmake << 'EOF'
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
    pname = "torchaudio-python313-cuda13_1-sm86-avx2-nomagma";

    # Propagate pytorch's out output for transitive torch availability
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ customPytorch.out ];
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: ${gpuArchSM} (Ampere: RTX 3090, A40)"
      echo "CPU Features: AVX2"
      echo "CUDA: 13.1"
      echo "PyTorch: 2.10.0 (with CUDA 13.1 fixes)"
      echo "========================================="
    '';
    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA RTX 3090/A40 (SM86, Ampere) + AVX2 with PyTorch 2.10.0 (no MAGMA)";
      platforms = [ "x86_64-linux" ];
    };
  })
