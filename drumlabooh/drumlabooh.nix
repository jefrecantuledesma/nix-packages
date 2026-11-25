{ lib
, stdenv
, fetchzip
, cmake
, pkg-config
, alsa-lib
, freetype
, fontconfig
, libX11
, libXcomposite
, libXcursor
, libXext
, libXinerama
, libXrandr
, libXrender
, libGL
}:

let
  juceSrc = fetchzip {
    url = "https://github.com/juce-framework/JUCE/archive/refs/tags/8.0.11.tar.gz";
    hash = "sha256-sUxPFxQ/Q1ESlp6tdGI8hGkc3szYkFwBO8xARg2JiR4=";
  };

  drumSkladSrc = fetchzip {
    url = "https://github.com/psemiletov/drum_sklad/archive/refs/tags/4.0.0.zip";
    hash = "sha256-PPaswQSdadkxuXGSQ01Bs/FMoZN2Gy6XJJK5NIUdxNQ=";
  };
in

stdenv.mkDerivation rec {
  pname = "drumlabooh";
  version = "13.0.0";

  src = fetchzip {
    url = "https://github.com/psemiletov/drumlabooh/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-DC7Syy3pj7kwwp/cmsmRqvcuKp5drT0OLLZq8p7hUyo=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    alsa-lib
    freetype
    fontconfig
    libX11
    libXcomposite
    libXcursor
    libXext
    libXinerama
    libXrandr
    libXrender
    libGL
  ];

  # The CMakeLists.txt links juce::juce_recommended_lto_flags, which compiles
  # objects as LTO IR. Binutils ar doesn't have the GCC LTO plugin, so the
  # resulting shared-code static library is unreadable at link time, causing
  # every JUCE symbol to appear as undefined. Strip the flag before CMake sees it.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "juce::juce_recommended_lto_flags" "" \
      --replace-fail "_artefacts/LV2/" "_artefacts/Release/LV2/" \
      --replace-fail "_artefacts/VST3/" "_artefacts/Release/VST3/"

    # Drumlabooh only scans a hardcoded list of FHS paths (/usr/share/drumlabooh-kits,
    # ~/drum_sklad, etc.) for drum kits; it has no notion of the Nix store. The kits
    # this derivation installs end up at $out/share/drumlabooh-kits, which is never in
    # that list, so the plugin can't find them. Bake the store path into the scan list.
    substituteInPlace Source/kits.cpp \
      --replace-fail \
        'v_kits_locations.push_back ("/usr/share/drumlabooh-kits");' \
        'v_kits_locations.push_back ("/usr/share/drumlabooh-kits");
  v_kits_locations.push_back ("'"$out"'/share/drumlabooh-kits");'
  '';

  cmakeFlags = [
    "-DFETCHCONTENT_SOURCE_DIR_JUCE=${juceSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_DRUM_SKLAD=${drumSkladSrc}"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DINSTALLKITS=ON"
    "-DMULTI=ON"
  ];

  meta = with lib; {
    description = "LV2/VST3 drum machine plugin built with JUCE";
    homepage = "https://psemiletov.github.io/drumlabooh/";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
