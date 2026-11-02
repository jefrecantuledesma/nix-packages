{ lib
, callPackage
, symlinkJoin
}:

let
  # Every app is released from its own repo (github.com/storytold/<name>) with
  # identically laid out Linux tarballs, so one builder covers all of them.
  # Hashes are the sha256 digests GitHub publishes for each release asset.
  apps = lib.mapAttrs
    (pname: app: callPackage ./craft-app.nix {
      inherit pname;
      inherit (app) version description;
      hashes = removeAttrs app [ "version" "description" ];
    })
    {
      cadcraft = {
        version = "0.16.0";
        description = "Draft, dimension and plot 2D drawings; open DXF and DWG files";
        x86_64-linux = "sha256-FJggs9Dh5ymiJW40RSO5gFhx057jnJ4IX1B3B/c8y9Q=";
        aarch64-linux = "sha256-M4dtowkdZpiM+sGYpGez4Y57yRwAUuNkFuiGo9sYlts=";
      };
      deckcraft = {
        version = "0.14.1";
        description = "Create and present slide decks";
        x86_64-linux = "sha256-6Gx/oOy1XxpVPuQluT3P3IBrezeY8nK0Hx0f90rFwSo=";
        aarch64-linux = "sha256-6lZZF0/oAHNv1qnml7EGxN6WL+AJRnB7v4hMI+JuyBw=";
      };
      designcraft = {
        version = "0.16.0";
        description = "Lay out magazines, books and print documents";
        x86_64-linux = "sha256-pIb8Q83I8kXtr3N8uxyaMoYO4YqNyhuv4IERAU4vFXY=";
        aarch64-linux = "sha256-0NtHFRzyYSMLMYeCip74B8xu3cJ2+FrRfIHV27eAmAA=";
      };
      effectcraft = {
        version = "0.20.0";
        description = "Motion graphics and visual effects compositor";
        x86_64-linux = "sha256-JXMQCgos4HppJXvaf6an1SUtO00y3+86H20slby42iM=";
        aarch64-linux = "sha256-zcH8u4zCDLoyi4t522n330Wb4yx1GHrAWuITj+S0IFA=";
      };
      figcraft = {
        version = "0.14.0";
        description = "Design and prototype user interfaces";
        x86_64-linux = "sha256-DqSJzimSOK+WEGlAzdtCCRw+uhCcBf34Q7Tn+OuXCCk=";
        aarch64-linux = "sha256-F4Sej+5/pmVeAu8HHif3vbft0AGRcs0ujjUjIEyrBTU=";
      };
      filmcraft = {
        version = "0.16.0";
        description = "Edit video, color and sound";
        x86_64-linux = "sha256-WIOQ7uXX4WNPBXlMT4d93ylJTZz3RAURHWfBbL4hWuk=";
        aarch64-linux = "sha256-irIMMOU9ZYbD25UTPFRuRWL0e5RYm3YQRh9DUaKmMI4=";
      };
      gridcraft = {
        version = "0.15.0";
        description = "Calculate, analyse and chart data in workbooks";
        x86_64-linux = "sha256-aBD4znOUtafN+vOYOCV7Y4Tc65+DJQJNR124le5Z2qo=";
        aarch64-linux = "sha256-kLKyFhNUYwm77TA2WRS6nCDdb30XWsfe1+J7xo5lU5o=";
      };
      lightcraft = {
        version = "0.17.0";
        description = "Organise photos and develop raw files, non-destructively";
        x86_64-linux = "sha256-0Yf1oVktSGYiDE0SfW5aPaT/p8lmzIffj0nnNcB88sE=";
        aarch64-linux = "sha256-bCmOaGFrtxoaGPb60R/ykp9gynhEqvbLLVqk2xlcUgM=";
      };
      pdfcraft = {
        version = "0.17.0";
        description = "Read, organize, combine, split and secure PDFs";
        x86_64-linux = "sha256-+YFKegr3e5Ba26HDB5yu3uU3WGeXBDz1r5UDkU9qvsU=";
        aarch64-linux = "sha256-Ma7V5NfLwb8Nix2gZZ3LDGzWEUvVeDwP2quxbSmic70=";
      };
      photocraft = {
        version = "0.19.0";
        description = "Edit photos and layered PSD documents";
        x86_64-linux = "sha256-EjOFsXMKzhjxK8D0lGBuakzT9KuJH5MDbNTnG4rqcPc=";
        aarch64-linux = "sha256-WUjo8Qw8AgqoyIA/GpA4ov+03ajrsbEpiByKQWstSK4=";
      };
      soundcraft = {
        version = "0.16.0";
        description = "Record, edit and mix audio and MIDI";
        x86_64-linux = "sha256-Jcawy4kkGY8i46bydx19zJ4EGjJEpL5EXL3p0A59wZ4=";
        aarch64-linux = "sha256-ppGjmZKemj0qOcIQcEVUiHvEbQe13mhHTkb1q8IIlXc=";
      };
      vectorcraft = {
        version = "0.20.0";
        description = "Draw and edit vector illustrations, SVG and PDF";
        x86_64-linux = "sha256-042D2eWf3PehAEFOIrMJQJT+T+LdQ6EF8EKXgBJhDoY=";
        aarch64-linux = "sha256-bFVXKfzqqn/uPhvZrcNxXUBabUPR9vA2zODSDxCq0/8=";
      };
      wordcraft = {
        version = "0.14.0";
        description = "Write and design documents; open and save Word files";
        x86_64-linux = "sha256-MBDaPTUtlSVuyaF6A5ZigKHUG6CdDr5WmvIwkti2SYc=";
        aarch64-linux = "sha256-oC4+8+qzZayjbFpqC4sAqSUlYskKt9qIS4PvcB366PA=";
      };
    };
in

# The whole suite in one package; each app is also reachable on its own,
# e.g. `nix-build artcraft -A photocraft`.
symlinkJoin {
  name = "artcraft-apps";
  paths = builtins.attrValues apps;

  passthru = apps;

  meta = with lib; {
    description = "ArtCraft suite of open-source creative and office apps";
    homepage = "https://getartcraft.com/apps";
    license = with licenses; [ mit asl20 ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
