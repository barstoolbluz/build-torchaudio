# TorchAudio CPU-only optimized for AVX-512
# Package name: torchaudio-python313-cpu-avx512

{ python3Packages
, lib
, openblas
}:

let
  # CPU optimization: AVX-512 (no GPU)
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mfma"        # Fused multiply-add
  ];

  # Custom PyTorch with matching CPU configuration
  customPytorch = (python3Packages.pytorch.overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    buildInputs = lib.filter (p: !(lib.hasPrefix "cuda" (p.pname or ""))) oldAttrs.buildInputs ++ [openblas];
    nativeBuildInputs = lib.filter (p: p.pname or "" != "addDriverRunpath") oldAttrs.nativeBuildInputs;

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export USE_CUDA=0
      export BLAS=OpenBLAS
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  }));

in
  (python3Packages.torchaudio.override {
    torch = customPytorch;  # CRITICAL: "torch", not "pytorch"
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cpu-avx512";
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: None (CPU-only build)"
      echo "CPU Features: AVX-512"
      echo "BLAS Backend: OpenBLAS"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only optimized for AVX-512";
      platforms = [ "x86_64-linux" ];
    };
  })
