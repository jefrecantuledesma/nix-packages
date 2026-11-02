{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, addDriverRunpath
, makeWrapper
, alsa-lib
, dbus
, libGL
, libx11
, libxcursor
, libxi
, libxrender
, libxcb
, libxkbcommon
, libva
, vulkan-loader
, wayland
, xdg-utils
, zenity
, pname
, version
, hashes
, description
}:

let
  # The release tarballs are named after the Nix system's CPU: x86_64, aarch64
  arch = stdenv.hostPlatform.parsed.cpu.name;
in

stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-${arch}.tar.gz";
    hash = hashes.${stdenv.hostPlatform.system}
      or (throw "${pname}: unsupported system ${stdenv.hostPlatform.system}");
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # autoPatchelfHook searches these for .so files to satisfy NEEDED entries
  buildInputs = [
    alsa-lib                  # libasound.so.2 (SoundCraft links it directly)
    (lib.getLib stdenv.cc.cc) # libgcc_s.so.1
  ];

  # The apps are winit + wgpu + egui, which dlopen() their windowing and GPU
  # libraries at runtime rather than linking them, so they never show up as
  # NEEDED entries. autoPatchelfHook adds these to every binary's RPATH.
  runtimeDependencies = [
    alsa-lib          # libasound.so.2 (audio playback)
    (lib.getLib dbus) # libdbus-1.so.3 (XDG portals: file chooser, open-with)
    libGL             # libEGL.so.1 (wgpu GL fallback, via libglvnd)
    libx11            # libX11.so.6, libX11-xcb.so.1
    libxcursor        # libXcursor.so.1
    libxi             # libXi.so.6
    libxrender        # libXrender.so.1 (LightCraft, PdfCraft)
    libxcb            # libxcb.so.1
    libxkbcommon      # libxkbcommon.so.0, libxkbcommon-x11.so.0
    (lib.getLib libva) # libva.so.2, libva-drm.so.2 (FilmCraft hardware video decode)
    vulkan-loader     # libvulkan.so.1 (wgpu's primary backend)
    wayland           # libwayland-client.so.0, libwayland-egl.so.1
  ];

  # FilmCraft also dlopens NVIDIA's libcuda, libnvcuvid and libnvidia-encode
  # for hardware video decode/encode; those come from the host's GPU driver.
  appendRunpaths = [ "${addDriverRunpath.driverLink}/lib" ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # The tarball is already an FHS tree: bin/ and share/{applications,icons,mime,...}.
    # Some also ship an install.sh that copies themselves into ~/.local; leave it out.
    mkdir -p "$out"
    cp -r bin share "$out/"

    runHook postInstall
  '';

  # File dialogs go through the XDG desktop portal first and fall back to
  # zenity; links are opened with xdg-open. Suffixed so the system's own
  # copies win when present.
  postFixup = ''
    for prog in "$out"/bin/*; do
      wrapProgram "$prog" \
        --suffix PATH : "${lib.makeBinPath [ zenity xdg-utils ]}"
    done
  '';

  meta = with lib; {
    inherit description;
    homepage = "https://getartcraft.com/apps/${pname}";
    downloadPage = "https://github.com/storytold/${pname}/releases";
    license = with licenses; [ mit asl20 ];
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = pname;
  };
}
