{ lib
, rustPlatform
, fetchzip
}:

rustPlatform.buildRustPackage rec {
  pname = "pipewire-eq-switcher";
  version = "1.0.0";

  src = fetchzip {
    url = "https://github.com/jefrecantuledesma/pipewire-eq-switcher/archive/refs/heads/main.tar.gz";
    hash = "sha256-HkfJEqNyzMp82Uj7JcbMQVrQtXgT50yYNYIF17a87TE=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  meta = with lib; {
    description = "CLI tool for switching between PipeWire EQ configurations";
    homepage = "https://github.com/jefrecantuledesma/pipewire-eq-switcher";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "pipewire-eq-switcher";
  };
}
