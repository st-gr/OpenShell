# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

final: prev:
let
  inherit (prev) lib;

  isAarch64Darwin = prev.stdenv.hostPlatform.system == "aarch64-darwin";

  darwinRuntimeTarball = prev.fetchurl {
    url = "https://github.com/NVIDIA/OpenShell/releases/download/vm-runtime/vm-runtime-darwin-aarch64.tar.zst";
    hash = "sha256-KSAKryBFZiytwYwXB0CR++u4tGlA5ficf7X/nen7qQE=";
  };

  darwinLibkrunfw = lib.makeOverridable (
    {
      variant ? null,
    }:

    assert lib.elem variant [
      null
      "sev"
      "tdx"
    ];

    if variant != null then
      throw "OpenShell's aarch64-darwin libkrunfw overlay only supports the default libkrunfw variant"
    else
      prev.stdenvNoCC.mkDerivation {
        pname = "libkrunfw";
        version = "5.3.0";

        src = darwinRuntimeTarball;

        nativeBuildInputs = [
          prev.zstd
        ];

        dontConfigure = true;
        dontBuild = true;

        unpackPhase = ''
          runHook preUnpack

          mkdir runtime
          ${prev.zstd}/bin/zstd -dc "$src" | tar -xf - -C runtime

          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall

          install -d "$out/lib"
          install -m 755 runtime/libkrunfw.5.dylib "$out/lib/libkrunfw.5.dylib"

          if [ -e runtime/libkrunfw.dylib ]; then
            install -m 755 runtime/libkrunfw.dylib "$out/lib/libkrunfw.dylib"
          else
            ln -s libkrunfw.5.dylib "$out/lib/libkrunfw.dylib"
          fi

          runHook postInstall
        '';

        passthru = {
          runtimeTarball = darwinRuntimeTarball;
        };

        meta = {
          description = "OpenShell libkrunfw runtime library for macOS ARM64";
          homepage = "https://github.com/NVIDIA/OpenShell/releases/tag/vm-runtime";
          license = with lib.licenses; [
            lgpl2Only
            lgpl21Only
          ];
          platforms = [ "aarch64-darwin" ];
        };
      }
  ) { };

  linuxStaticCc = prev.pkgsCross.aarch64-multiplatform.pkgsStatic.stdenv.cc;

  darwinLibkrun =
    (prev.libkrun.override {
      libkrunfw = final.libkrunfw;
      withBlk = true;
      withNet = true;
      withGpu = false;
      withSound = false;
      withInput = false;
      withTimesync = false;
    }).overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          linuxStaticCc
        ];

        buildInputs = [
          final.libkrunfw
          prev.apple-sdk_15
        ];

        makeFlags = (old.makeFlags or [ ]) ++ [
          "CC_LINUX=${linuxStaticCc}/bin/${linuxStaticCc.targetPrefix}cc"
          "SYSROOT_LINUX=${prev.emptyDirectory}"
        ];

        env = (old.env or { }) // {
          RUSTFLAGS = "";
        };

        postPatch = ''
          ${old.postPatch or ""}

          substituteInPlace Makefile \
            --replace-fail \
              'mv target/release/libkrun.dylib target/release/$(KRUN_BASE_$(OS))' \
              '[ "target/release/libkrun.dylib" = "target/release/$(KRUN_BASE_$(OS))" ] || mv target/release/libkrun.dylib target/release/$(KRUN_BASE_$(OS))'
        '';

        postInstall = ''
          mkdir -p "$dev/lib"

          if [ -d "$out/lib/pkgconfig" ]; then
            mv "$out/lib/pkgconfig" "$dev/lib/"
          fi
          if [ -d "$out/include" ]; then
            mv "$out/include" "$dev/"
          fi

          install -m 755 ${final.libkrunfw}/lib/libkrunfw.5.dylib "$out/lib/libkrunfw.5.dylib"
          if [ -e ${final.libkrunfw}/lib/libkrunfw.dylib ]; then
            install -m 755 ${final.libkrunfw}/lib/libkrunfw.dylib "$out/lib/libkrunfw.dylib"
          else
            ln -sf libkrunfw.5.dylib "$out/lib/libkrunfw.dylib"
          fi

          install_name_tool -id "@loader_path/libkrun.dylib" "$out/lib/libkrun.${old.version}.dylib"

          if command -v codesign >/dev/null 2>&1; then
            for dylib in "$out"/lib/*.dylib; do
              [ -e "$dylib" ] || continue
              codesign -f -s - "$dylib"
            done
          fi
        '';

        meta = (old.meta or { }) // {
          platforms = lib.unique ((old.meta.platforms or [ ]) ++ [ "aarch64-darwin" ]);
        };
      });
in
lib.optionalAttrs isAarch64Darwin {
  libkrunfw = darwinLibkrunfw;
  libkrun = darwinLibkrun;
}
