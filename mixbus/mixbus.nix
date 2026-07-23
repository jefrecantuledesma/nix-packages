{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
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
}:

let
  # Use the local tar if it exists next to this file; otherwise fetch from upstream.
  # This avoids re-downloading a large file you already have on disk.
  src =
    if builtins.pathExists ./Mixbus-11.3.0-x86_64.tar
    then ./Mixbus-11.3.0-x86_64.tar
    else fetchurl {
      url = "https://eu1.download.solidstatelogic.com/Mixbus%2011/Mixbus%2011.3/Mixbus-11.3.0-x86_64.tar";
      hash = "sha256-uxiNYZKuAbHXHaTIIVyZhUmj/pgDJfVHD7K5aSAs6EQ=";
    };
in

stdenv.mkDerivation rec {
  pname = "harrison-mixbus";
  version = "11.3.0";

  inherit src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
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

    mkdir -p "$out"
    cp -r Mixbus_x86_64-${version}/. "$out/"

    # Wrap the launcher so the JACK backend's dlopen("libjack.so.0") finds
    # Pipewire's JACK shim rather than searching system paths (which don't
    # exist on Nix). Pipewire's shim speaks Pipewire natively, so the JACK
    # backend will see Pipewire as the JACK server.
    wrapProgram "$out/bin/mixbus11" \
      --prefix LD_LIBRARY_PATH : "${pipewire.jack}/lib"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Harrison Mixbus professional digital audio workstation";
    homepage = "https://store.harrisonaudio.com/all-products/mixbus-11";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "mixbus11";
  };
}
