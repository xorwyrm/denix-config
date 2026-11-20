{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  requireFile,
  androidenv,
  cmake,
  ninja,
  python3,
}: let
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "glomatico";
    repo = "wrapper-v2";
    rev = "9a6f29f493b1bac5325105ab6edf5dbd8caaae8c";
    hash = "sha256-NaXBJAg1davHh3n9lZXhc+oB0mlm3/aQ1hzPCgImmyY=";
  };
  # Pinned by CMakeLists.txt's FetchContent declarations.
  nlohmannJson = fetchFromGitHub {
    owner = "nlohmann";
    repo = "json";
    rev = "9cca280a4d0ccf0c08f47a99aa71d1b0e52f8d03";
    hash = "sha256-7F0Jon+1oWL7uqet5i1IgHX0fUw/+z0QwEcA3zs5xHg=";
  };
  dobby = fetchFromGitHub {
    owner = "BepInEx";
    repo = "Dobby";
    rev = "9d271803881f467aabfc24593c7dcaeb710fe861";
    hash = "sha256-C/Lyf5hl1bM+awYG27AJSrv6g4/WwvvwoR8Zn1cZEf0=";
  };
  # The worker must link against the APK's own libc++, which exports the
  # unwinder the NDK's copy lacks. It is LLVM's libc++ built for Apple Music
  # 3.6.0-beta (build 1109); the hash is the x86_64 profile's pin. The other
  # Apple libraries stay out of the store and are bind-mounted at runtime.
  appleLibcxx = requireFile {
    name = "apple-music-1109-x86_64-libc++_shared.so";
    sha256 = "82ffc20ba230bbdd031b27853d6cfaaa27079aabe6dd478cafd9b6fa866a35c2";
    message = ''
      Add libc++_shared.so from Apple Music 3.6.0-beta (build 1109, x86_64)
      to the store under the expected name:
        cp /var/lib/wrapper-v2/runtime/system/lib64/libc++_shared.so \
          apple-music-1109-x86_64-libc++_shared.so
        nix-store --add-fixed sha256 apple-music-1109-x86_64-libc++_shared.so
    '';
  };
  ndk =
    ((androidenv.override {licenseAccepted = true;}).composeAndroidPackages {
      includeNDK = true;
      ndkVersions = ["23.1.7779620"];
      platformVersions = [];
      buildToolsVersions = [];
      includeEmulator = false;
    }).ndk-bundle;
  supervisor = rustPlatform.buildRustPackage {
    pname = "wrapperd";
    inherit version src;
    cargoHash = "sha256-O9fZuAFKfD6Bx5eujfGnM+AgDkyKHHfEo7nzL3sv7hM=";
    doCheck = false;
  };
  launcher = stdenv.mkDerivation {
    pname = "wrapper-v2-launcher";
    inherit version src;
    dontConfigure = true;
    doCheck = false;
    buildPhase = ''
      $CXX -std=c++17 -Wall -Wextra -Werror -O2 native/launcher.cpp -o worker-launch
    '';
    installPhase = ''
      install -Dm755 worker-launch "$out/bin/worker-launch"
    '';
  };
  worker = stdenv.mkDerivation {
    pname = "wrapper-v2-worker";
    inherit version src;
    nativeBuildInputs = [cmake ninja python3];
    doCheck = false;
    dontUseCmakeConfigure = true;
    dontStrip = true;
    dontPatchELF = true;
    buildPhase = ''
      ndkRoot="${ndk}/libexec/android-sdk/ndk/23.1.7779620"
      cp ${appleLibcxx} libc++_shared.so
      cmake -S . -B build -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ndkRoot/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-21 \
        -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
        -DAPPLE_LIBCXX="$PWD/libc++_shared.so" \
        -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
        -DFETCHCONTENT_SOURCE_DIR_JSON=${nlohmannJson} \
        -DFETCHCONTENT_SOURCE_DIR_DOBBY=${dobby}
      cmake --build build --target apple-music-worker -j "$NIX_BUILD_CORES"
    '';
    installPhase = ''
      install -Dm755 build/apple-music-worker "$out/system/bin/apple-music-worker"
    '';
  };
in
  stdenv.mkDerivation {
    pname = "wrapper-v2";
    inherit version src;
    nativeBuildInputs = [python3];
    dontConfigure = true;
    dontBuild = true;
    # The Android worker must retain its linker layout and /system/lib64 path.
    dontPatchELF = true;
    dontStrip = true;
    doCheck = false;
    installPhase = ''
      mkdir -p "$out/bin" "$out/libexec" "$out/system/bin" "$out/system/usr/share/zoneinfo"
      ln -s ${supervisor}/bin/wrapperd "$out/bin/wrapperd"
      ln -s ${launcher}/bin/worker-launch "$out/libexec/worker-launch"
      cp ${worker}/system/bin/apple-music-worker "$out/system/bin/apple-music-worker"
      cp vendor/android-system/x86_64/usr/share/zoneinfo/tzdata "$out/system/usr/share/zoneinfo/tzdata"
      # The same metadata tools/prepare_rootfs.py writes into a staged rootfs.
      python3 -c '
      import json, sys
      sys.path.insert(0, "tools")
      from architecture import load_profile
      p = load_profile("x86_64")
      keys = ("architecture", "profile", "context_profile", "context_supported")
      print(json.dumps({k: p[k] for k in keys}, sort_keys=True))
      ' > "$out/worker-profile.json"
    '';
    meta = {
      description = "Native wrapper-v2 supervisor and Android worker";
      license = lib.licenses.unlicense;
      platforms = ["x86_64-linux"];
      mainProgram = "wrapperd";
    };
  }
