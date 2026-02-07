# TorchAudio with PyTorch 2.10.0 for CPU-only + AVX2
# Package name: torchaudio-python313-cpu-avx2
#
# CPU-only build optimized for x86-64 systems with AVX2 instruction set.
# No GPU/CUDA support - pure CPU inference and training.

{ pkgs ? import <nixpkgs> {} }:

let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = { allowUnfree = true; allowBroken = true; };
    overlays = [
      # Overlay: Upgrade PyTorch to 2.10.0
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

  cpuFlags = [ "-mavx2" "-mfma" "-mf16c" ];

  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = false;
  }).overrideAttrs (oldAttrs: {
    pname = "pytorch210-for-torchaudio-cpu-avx2";
    patches = [];
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DTORCH_BUILD_VERSION=2.10.0"
      "-DUSE_CUDA=OFF"
    ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
      export PYTORCH_BUILD_VERSION=2.10.0
      echo "2.10.0" > version.txt
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cpu-avx2";
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: None (CPU-only)"
      echo "CPU Features: AVX2"
      echo "PyTorch: 2.10.0"
      echo "TorchAudio: ${oldAttrs.version}"
      echo "========================================="
    '';
    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only + AVX2 with PyTorch 2.10.0";
      longDescription = ''
        CPU-only TorchAudio build with targeted optimizations:
        - CPU: x86-64 with AVX2 instruction set
        - PyTorch: 2.10.0
        - Python: 3.13
        - No CUDA/GPU support

        Hardware requirements:
        - CPU: Intel Haswell+ (2013+), AMD Excavator+ (2015+)
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
