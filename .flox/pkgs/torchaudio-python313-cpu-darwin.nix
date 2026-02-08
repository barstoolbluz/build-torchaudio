# TorchAudio CPU-only for Intel Mac
# Package name: torchaudio-python313-cpu-darwin
#
# macOS build for Intel-based Macs (x86_64)
# Hardware: Intel Core i5/i7/i9, Xeon Mac Pro

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
    system = "x86_64-darwin";
  };

  # Darwin frameworks for Accelerate BLAS
  darwinFrameworks = with darwin.apple_sdk.frameworks; [
    Accelerate
  ];

  # CPU optimization: AVX2 (standard for Intel Macs)
  cpuFlags = [
    "-mavx2"       # AVX2 instructions
    "-mfma"        # Fused multiply-add
    "-mf16c"       # Half-precision conversions
  ];

  # Custom PyTorch with CPU-only configuration
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
      export USE_MPS=0
      export BLAS=Accelerate
      export CXXFLAGS="$CXXFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';

    passthru = (oldAttrs.passthru or {}) // {
      gpuArch = null;
      blasProvider = "accelerate";
    };
  }));

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;  # CRITICAL: "torch", not "pytorch"
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cpu-darwin";
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    buildInputs = (oldAttrs.buildInputs or []) ++ darwinFrameworks;

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: None (CPU-only build)"
      echo "Platform: Intel Mac (x86_64-darwin)"
      echo "CPU Features: AVX2"
      echo "BLAS Backend: Apple Accelerate"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only for Intel Mac";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: None (CPU-only)
        - Platform: Intel Mac (x86_64-darwin)
        - CPU: AVX2 instruction set
        - BLAS: Apple Accelerate framework
        - Python: 3.13

        Note: Intel Macs do not support MPS. Use this CPU-only variant.
      '';
      platforms = [ "x86_64-darwin" ];
    };
  })
