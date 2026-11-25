{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, which
, xxd
, cairo
, libX11
, libsndfile
, libjack2
, lv2
}:

stdenv.mkDerivation rec {
  pname = "toneshifteq";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "brummer10";
    repo = "ToneShiftEQ";
    tag = "v${version}";
    hash = "sha256-y85UbyIbkFS8UDxzLg23nPQyqS/GRX1VEcVg5Rr/9Go=";
    fetchSubmodules = true; # libxputty (GUI toolkit, built statically)
  };

  nativeBuildInputs = [
    pkg-config
    which # libxputty's makefile uses `which xxd` to pick its resource embedder
    xxd
  ];

  buildInputs = [
    cairo
    libX11
    libsndfile
    libjack2
    lv2
  ];

  enableParallelBuilding = false; # the makefiles force -j 1 on sub-makes anyway

  # The makefile installs into ~/.lv2, ~/.clap, ~/bin etc. unless run as root,
  # so spell out every destination explicitly.
  installFlags = [
    "PREFIX=${placeholder "out"}"
    "EXE_INSTALL_DIR=${placeholder "out"}/bin"
    "LV2_INSTALL_DIR=${placeholder "out"}/lib/lv2"
    "CLAP_INSTALL_DIR=${placeholder "out"}/lib/clap"
    "VST3_INSTALL_DIR=${placeholder "out"}/lib/vst3"
  ];

  # The desktop entry and icon are also only installed when run as root.
  postInstall = ''
    install -Dm644 EQ12/Resources/toneshifteq.desktop -t $out/share/applications
    install -Dm644 EQ12/Resources/toneshifteq.svg -t $out/share/icons/hicolor/scalable/apps
  '';

  meta = with lib; {
    description = "12-band parametric/dynamic EQ with FFT and biquad engines (standalone, LV2, CLAP, VST3)";
    homepage = "https://github.com/brummer10/ToneShiftEQ";
    license = licenses.bsd3;
    platforms = platforms.linux;
    mainProgram = "toneshifteq";
  };
}
