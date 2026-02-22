# TorchAudio with PyTorch 2.10.0 for NVIDIA Ampere (SM86: RTX 3090, A40) + AVX-512 VNNI (no MAGMA)
# Package name: torchaudio-python313-cuda13_0-sm86-avx512vnni-nomagma

{ pkgs ? import <nixpkgs> {} }:

let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = { allowUnfree = true; allowBroken = true; cudaSupport = true; };
    overlays = [
      (final: prev: { cudaPackages = final.cudaPackages_13; })
      (final: prev: {
        opencv = prev.opencv.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            (final.fetchpatch {
              name = "opencv-cuda-13.0-deviceprop-fix.patch";
              url = "https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7.patch";
              hash = "sha256-zeDA8K7k6Sff5Xw/9XmqbCg/dhj9iu095rXuZTdj8PY=";
            })
          ];
          postPatch = (oldAttrs.postPatch or "") + ''
            if [ -d "opencv_contrib" ]; then
              patch -p2 -d opencv_contrib < ${final.fetchpatch {
                name = "opencv-contrib-cuda-13.0-videostab-fix.patch";
                url = "https://github.com/opencv/opencv_contrib/commit/9a9b173cd178e7c07a98896a009c2a2021a6b247.patch";
                hash = "sha256-W3eBv7HnoUrNBupXAykv5UsHcYG/o9P55VIddRYWrF8=";
              }}
            fi
          '';
        });
      })
      (final: prev: {
        python3Packages = prev.python3Packages.override {
          overrides = pfinal: pprev: {
            torch = pprev.torch.overrideAttrs (oldAttrs: rec {
              version = "2.10.0";
              src = prev.fetchFromGitHub {
                owner = "pytorch"; repo = "pytorch"; rev = "v${version}";
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
  cpuFlags = [ "-mavx512f" "-mavx512dq" "-mavx512vl" "-mavx512bw" "-mavx512vnni" "-mfma" ];

  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true; gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    pname = "pytorch210-for-torchaudio-sm86-avx512vnni-nomagma";
    # Filter MAGMA from all dependency lists
    buildInputs = filterMagma (oldAttrs.buildInputs or []);
    nativeBuildInputs = filterMagma (oldAttrs.nativeBuildInputs or []);
    propagatedBuildInputs = filterMagma (oldAttrs.propagatedBuildInputs or []);
    patches = [];
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DTORCH_BUILD_VERSION=2.10.0" "-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat" "-DCUDA_VERSION=13.0"
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
  (nixpkgs_pinned.python3Packages.torchaudio.override { torch = customPytorch; }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda13_0-sm86-avx512vnni-nomagma";

    # Propagate pytorch's out output for transitive torch availability
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ customPytorch.out ];
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
      echo "GPU Target: ${gpuArchSM} (Ampere: RTX 3090, A40) | CPU: AVX-512 VNNI | CUDA: 13.0"
    '';
    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA RTX 3090/A40 (SM86, Ampere) + AVX-512 VNNI with PyTorch 2.10.0 (no MAGMA)";
      platforms = [ "x86_64-linux" ];
    };
  })
