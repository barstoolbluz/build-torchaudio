# TorchAudio with PyTorch 2.10.0 for NVIDIA Turing (SM75: T4, RTX 2080 Ti) + AVX2
# Package name: torchaudio-python313-cuda13_0-sm75-avx2

{ pkgs ? import <nixpkgs> {} }:

let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = { allowUnfree = true; allowBroken = true; cudaSupport = true; };
    overlays = [
      (final: prev: { cudaPackages = final.cudaPackages_13; })
      (final: prev: {
        magma = prev.magma.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            (final.fetchpatch {
              name = "cuda-13.0-clockrate-fix.patch";
              url = "https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd.patch";
              hash = "sha256-i9InbxD5HtfonB/GyF9nQhFmok3jZ73RxGcIciGBGvU=";
            })
          ];
        });
      })
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

  gpuArchSM = "7.5";
  cpuFlags = [ "-mavx2" "-mfma" "-mf16c" ];

  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true; gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    pname = "pytorch210-for-torchaudio-sm75-avx2";
    patches = [];
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DTORCH_BUILD_VERSION=2.10.0" "-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat" "-DCUDA_VERSION=13.0"
    ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
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
    pname = "torchaudio-python313-cuda13_0-sm75-avx2";
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
      echo "GPU Target: ${gpuArchSM} (Turing: T4, RTX 2080 Ti) | CPU: AVX2 | CUDA: 13.0"
    '';
    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA T4/RTX 2080 Ti (SM75, Turing) + AVX2 with PyTorch 2.10.0";
      platforms = [ "x86_64-linux" ];
    };
  })
