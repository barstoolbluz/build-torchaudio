# TorchAudio with MPS (Metal Performance Shaders) for Apple Silicon
# Package name: torchaudio-python313-darwin-mps
#
# macOS build for Apple Silicon (M1/M2/M3/M4) with Metal GPU acceleration
# Hardware: Apple M1, M2, M3, M4 and variants (Pro, Max, Ultra)
# Requires: macOS 12.3+

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision where PyTorch 2.8.0 and TorchAudio 2.8.0 are compatible
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
  }) {
    config = {
      allowUnfree = true;
    };
  };

  # Import the exact pytorch derivation from build-pytorch
  # This ensures torchaudio links against the same libtorch as the published pytorch package
  pytorch_src = builtins.fetchTarball {
    url = "https://github.com/barstoolbluz/build-pytorch/archive/96d3c27ab902dbe5cb973d94f86d5cf51ea4a6df.tar.gz";
  };
  customPytorch = import "${pytorch_src}/.flox/pkgs/pytorch-python313-darwin-mps.nix" {};

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-darwin-mps";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    # Propagate pytorch's main (out) output so the torch Python package
    # is available in downstream environments. Without .out, Nix's
    # chooseDevOutputs selects the dev output (headers only, no site-packages).
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ customPytorch.out ];

    # Filter out any CUDA deps from torchaudio
    buildInputs = nixpkgs_pinned.lib.filter (p: !(nixpkgs_pinned.lib.hasPrefix "cuda" (p.pname or "")))
      (oldAttrs.buildInputs or []);
    nativeBuildInputs = nixpkgs_pinned.lib.filter (p: p.pname or "" != "addDriverRunpath")
      (oldAttrs.nativeBuildInputs or []);

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
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: Metal Performance Shaders (MPS) for Apple Silicon
        - Platform: macOS 12.3+ on M1/M2/M3/M4
        - BLAS: vecLib (Apple Accelerate framework)
        - Python: 3.13
      '';
      platforms = [ "aarch64-darwin" ];
    };
  })
