# TorchAudio CPU-only optimized for ARMv9
# Package name: torchaudio-python313-cpu-armv9
#
# ARM datacenter build for Grace CPUs, AWS Graviton3+
# Hardware: ARM Neoverse V1/V2, Cortex-X2+, Graviton3+

{ python3Packages
, lib
, openblas
}:

let
  # CPU optimization: ARMv9-A with SVE/SVE2
  cpuFlags = [
    "-march=armv9-a+sve+sve2"  # ARMv9 with Scalable Vector Extensions
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
    pname = "torchaudio-python313-cpu-armv9";
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
      echo "CPU Architecture: ARMv9-A with SVE2"
      echo "BLAS Backend: OpenBLAS"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only optimized for ARMv9 (Grace, Graviton3+, SVE2)";
      platforms = [ "aarch64-linux" ];
    };
  })
