# TorchAudio CPU-only optimized for ARMv9
# Package name: torchaudio-python313-cpu-armv9

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

  # CPU optimization
  cpuFlags = [
    "-march=armv9-a+sve+sve2"
  ];

  # Custom PyTorch (CPU-only) with CPU optimization
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = false;
  }).overrideAttrs (oldAttrs: {
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cpu-armv9";

    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "CPU Features: ARMv9"
      echo "CUDA: Disabled"
      echo "PyTorch: ${customPytorch.version}"
      echo "TorchAudio: ${oldAttrs.version}"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only optimized for ARMv9";
      platforms = oldAttrs.meta.platforms or [ "x86_64-linux" "aarch64-linux" ];
    };
  })
