{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, xz
, libx11
, libxcb
, libxext
, libxinerama
, libxrandr
, libxrender
, alsa-lib
, libjack2
, pipewire
, libpulseaudio
, libGL
, freetype
}:

stdenv.mkDerivation rec {
  pname = "harrison-mixbus";
  version = "12.1.0";

  src = fetchurl {
    url = "https://eu1.download.solidstatelogic.com/Mixbus%2012/Mixbus-${version}-x86_64.tar";
    hash = "sha256-GHXI2TxOqA7jJmZHveDSeEVoGhJ2l7Nscmq7SsX9vzw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    xz
  ];

  # autoPatchelfHook searches these for .so files to satisfy NEEDED entries
  buildInputs = [
    libx11      # libX11.so.6
    libxcb      # libxcb.so.1, libxcb-render.so.0, libxcb-shm.so.0
    libxext     # libXext.so.6
    libxinerama # libXinerama.so.1
    libxrandr   # libXrandr.so.2
    libxrender  # libXrender.so.1
    alsa-lib    # libasound.so.2 (ALSA audio backend)
    libjack2    # libjack.so.0 (satisfies any direct NEEDED entries)
    libpulseaudio # libpulse.so.0 (PulseAudio audio backend)
    libGL       # libGL.so.1 (LV2 GUI plugins + xjremote)
  ];

  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack

    # The source tar contains a single Makeself .run installer
    tar -xf $src

    # Read the script line count from the .run header (text-only first 50 lines),
    # then extract the XZ-compressed inner archive that begins immediately after
    runfile=$(ls *.run)
    skip=$(head -n 50 "$runfile" | grep -m1 '^skip=' | cut -d'"' -f2)
    tail -n +$((skip + 1)) "$runfile" | xz -dc | tar -xf -

    # Extract the actual application bundle
    tar -xf Mixbus_x86_64-${version}.tar

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Keep the bundle self-contained under opt/ so its bundled libs, fonts and
    # helper tools (harvid, xjremote, ...) don't collide with Mixbus 11 when
    # both are installed into the same profile.
    bundle="$out/opt/mixbus12"
    mkdir -p "$bundle" "$out/bin"
    cp -r Mixbus_x86_64-${version}/. "$bundle/"

    # The uninstaller targets a /opt install and is meaningless here
    rm -f "$bundle/bin/Mixbus-${version}.uninstall.sh"

    # The bundled FreeType predates 2.11 (no FT_Get_Paint). Mixbus puts its lib
    # dir on LD_LIBRARY_PATH, so plugins built against a modern FreeType (JUCE 8:
    # drumlabooh, ...) bind to the old copy and fail with "undefined symbol:
    # FT_Get_Paint". FreeType keeps ABI within soname 6, so swap in nixpkgs' copy.
    ln -sf ${freetype}/lib/libfreetype.so.6 "$bundle/lib/libfreetype.so.6"

    # Wrap the launcher so the JACK backend's dlopen("libjack.so.0") finds
    # Pipewire's JACK shim rather than searching system paths (which don't
    # exist on Nix). Pipewire's shim speaks Pipewire natively, so the JACK
    # backend will see Pipewire as the JACK server.
    # The launcher also runs `pipewire --version` to decide whether to set
    # PIPEWIRE_MIDI_BROKEN, so make sure a pipewire binary is reachable
    # (suffixed, so the system's own pipewire wins when present).
    for prog in mixbus12 mixbus12-export mixbus12-lua mixbus12-new_empty_session mixbus12-new_session; do
      makeWrapper "$bundle/bin/$prog" "$out/bin/$prog" \
        --prefix LD_LIBRARY_PATH : "${pipewire.jack}/lib" \
        --suffix PATH : "${lib.makeBinPath [ pipewire ]}"
    done

    for size in 16 22 32 48 256; do
      install -Dm644 "$bundle/share/resources/Mixbus-icon_''${size}px.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/mixbus12.png"
    done

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "mixbus12";
      desktopName = "Harrison Mixbus 12";
      genericName = "Digital Audio Workstation";
      comment = "Record, mix and master audio";
      exec = "mixbus12 %f";
      icon = "mixbus12";
      categories = [ "AudioVideo" "Audio" "Recorder" ];
      startupWMClass = "Mixbus-${version}";
    })
  ];

  meta = with lib; {
    description = "Harrison Mixbus professional digital audio workstation";
    homepage = "https://store.harrisonaudio.com/all-products/mixbus";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "mixbus12";
  };
}
