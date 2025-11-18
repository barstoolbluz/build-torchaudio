# TorchAudio CPU-only optimized for AVX-512 + VNNI
# Package name: torchaudio-python313-cpu-avx512vnni
#
# Optimized for INT8 inference workloads (quantized models)
# Hardware: Intel Skylake-SP+ (2017), AMD Zen 4+ (2022)

{ python3Packages
, lib
, openblas
}:

let
  # CPU optimization: AVX-512 + VNNI (Vector Neural Network Instructions)
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mavx512vnni" # Vector Neural Network Instructions (INT8 acceleration)
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
    pname = "torchaudio-python313-cpu-avx512vnni";
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
      echo "CPU Features: AVX-512 + VNNI (INT8 optimized)"
      echo "BLAS Backend: OpenBLAS"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only optimized for AVX-512 VNNI (INT8 quantized inference)";
      platforms = [ "x86_64-linux" ];
    };
  })
