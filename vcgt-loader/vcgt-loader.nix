{ lib
, rustPlatform
}:

rustPlatform.buildRustPackage {
  pname = "vcgt-loader";
  version = "0.1.0";

  # The source lives right here rather than in its own repo
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "Load an ICC profile's vcgt calibration curves into a wlroots output's gamma table";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "vcgt-loader";
  };
}
