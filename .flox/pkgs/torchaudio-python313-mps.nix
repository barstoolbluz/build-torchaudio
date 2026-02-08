# TorchAudio with MPS (Metal Performance Shaders) for Apple Silicon
# Package name: torchaudio-python313-mps
#
# macOS build for Apple Silicon (M1/M2/M3/M4) with Metal GPU acceleration
# Hardware: Apple M1, M2, M3, M4 and variants (Pro, Max, Ultra)
# Requires: macOS 12.3+

{ python3Packages
, lib
, darwin
}:

let
  # Import nixpkgs at a specific revision where PyTorch 2.8.0 and TorchAudio 2.8.0 are compatible
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;
    };
    system = "aarch64-darwin";
  };

  # Darwin frameworks for MPS and Accelerate
  darwinFrameworks = with darwin.apple_sdk.frameworks; [
    Accelerate
    Metal
    MetalPerformanceShaders
    MetalPerformanceShadersGraph
    CoreML
  ];

  # Custom PyTorch with MPS configuration
  customPytorch = (nixpkgs_pinned.python3Packages.torch.overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    buildInputs = nixpkgs_pinned.lib.filter (p: !(nixpkgs_pinned.lib.hasPrefix "cuda" (p.pname or "")))
      (oldAttrs.buildInputs or []) ++ darwinFrameworks;
    nativeBuildInputs = nixpkgs_pinned.lib.filter (p: p.pname or "" != "addDriverRunpath")
      (oldAttrs.nativeBuildInputs or []);

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export USE_CUDA=0
      export USE_MPS=1
      export USE_METAL=1
      export BLAS=Accelerate
      export MAX_JOBS=32
    '';

    passthru = (oldAttrs.passthru or {}) // {
      gpuArch = "mps";
      blasProvider = "accelerate";
    };
  }));

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;  # CRITICAL: "torch", not "pytorch"
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-mps";
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    buildInputs = (oldAttrs.buildInputs or []) ++ darwinFrameworks;

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: MPS (Metal Performance Shaders)"
      echo "Platform: Apple Silicon (aarch64-darwin)"
      echo "BLAS Backend: Apple Accelerate"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio with MPS GPU acceleration for Apple Silicon";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: Metal Performance Shaders (MPS) for Apple Silicon
        - Platform: macOS 12.3+ on M1/M2/M3/M4
        - BLAS: Apple Accelerate framework
        - Python: 3.13
      '';
      platforms = [ "aarch64-darwin" ];
    };
  })
