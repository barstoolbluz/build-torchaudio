# TorchAudio CPU-only optimized for AVX (Sandy Bridge+ maximum compatibility)
# Package name: torchaudio-python313-cpu-avx

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision with PyTorch 2.9.1 and TorchAudio
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = {
      allowUnfree = true;
    };
  };

  # CPU optimization - AVX only (Sandy Bridge+, 2011+)
  # Explicitly disable newer instructions for maximum compatibility
  cpuFlags = [
    "-mavx"      # Enable AVX
    "-mno-fma"   # Disable FMA3 (Haswell+)
    "-mno-bmi"   # Disable BMI1 (Haswell+)
    "-mno-bmi2"  # Disable BMI2 (Haswell+)
    "-mno-avx2"  # Disable AVX2 (Haswell+)
  ];

  # Custom PyTorch (CPU-only) with CPU optimization
  # Note: PyTorch needs special handling to disable FBGEMM/MKLDNN/NNPACK for AVX-only
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = false;
  }).overrideAttrs (oldAttrs: {
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DCXX_AVX2_FOUND=FALSE"
      "-DC_AVX2_FOUND=FALSE"
      "-DCXX_AVX512_FOUND=FALSE"
      "-DC_AVX512_FOUND=FALSE"
      "-DUSE_NNPACK=OFF"
    ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
      export USE_FBGEMM=0
      export USE_MKLDNN=0
      export USE_NNPACK=0
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cpu-avx";

    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "CPU Features: AVX (Sandy Bridge+ compatibility)"
      echo "CUDA: Disabled"
      echo "PyTorch: ${customPytorch.version}"
      echo "TorchAudio: ${oldAttrs.version}"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only optimized for AVX (Sandy Bridge+ maximum compatibility)";
      platforms = oldAttrs.meta.platforms or [ "x86_64-linux" ];
    };
  })
