{ lib
, rustPlatform
, fetchFromGitHub
, makeWrapper
, procps
, util-linux
, swayidle
}:

rustPlatform.buildRustPackage {
  pname = "swayidle-switch";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "jefrecantuledesma";
    repo = "swayidle-switch";
    rev = "300b6767e71346ff209ccbfaebcae43f9e8d1e5d";
    hash = "sha256-XAuncV1km+BDc4HjRKAShIMGmM/w1DmVeKw4DXvYE/s=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
    printf '\n[[bin]]\nname = "swayidle-switch"\npath = "src/main.rs"\n' >> Cargo.toml
  '';

  postInstall = ''
    wrapProgram $out/bin/swayidle-switch \
      --prefix PATH : ${lib.makeBinPath [ procps util-linux swayidle ]}
  '';

  meta = with lib; {
    description = "Toggle swayidle on/off, reading the command from your Sway config";
    homepage = "https://github.com/jefrecantuledesma/swayidle-switch";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "swayidle-switch";
  };
}
