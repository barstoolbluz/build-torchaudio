# TorchAudio with MPS (Metal Performance Shaders) for Apple Silicon
# Package name: torchaudio-python313-darwin-mps
#
# macOS build for Apple Silicon (M1/M2/M3/M4) with Metal GPU acceleration
# Requires: macOS 12.3+

{ pkgs ? import <nixpkgs> {} }:

let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = {
      allowUnfree = true;
    };
  };

  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = false;
  }).overrideAttrs (oldAttrs: {
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    buildInputs = nixpkgs_pinned.lib.filter (p: !(nixpkgs_pinned.lib.hasPrefix "cuda" (p.pname or "")))
      (oldAttrs.buildInputs or []);
    nativeBuildInputs = nixpkgs_pinned.lib.filter (p: p.pname or "" != "addDriverRunpath")
      (oldAttrs.nativeBuildInputs or []);

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export USE_CUDA=0
      export USE_CUDNN=0
      export USE_CUBLAS=0
      export USE_MPS=1
      export USE_METAL=1
      export BLAS=vecLib
      export MAX_JOBS=32
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-darwin-mps";

    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: MPS (Metal Performance Shaders)"
      echo "Platform: Apple Silicon (aarch64-darwin)"
      echo "BLAS Backend: vecLib (Apple Accelerate)"
      echo "PyTorch: ${customPytorch.version}"
      echo "TorchAudio: ${oldAttrs.version}"
      echo "========================================="
    '';

    postInstall = (oldAttrs.postInstall or "") + ''
      echo 1 > $out/.metadata-rev
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio with MPS GPU acceleration for Apple Silicon";
      platforms = [ "aarch64-darwin" ];
    };
  })
