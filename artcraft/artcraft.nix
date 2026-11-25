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
        version = "0.20.0";
        description = "Draft, dimension and plot 2D drawings; open DXF and DWG files";
        x86_64-linux = "sha256-UAWDN6wl9UL87yyDQxg1dtDEIKocfdYjEQvtiZ4sSOk=";
        aarch64-linux = "sha256-Zy+pAS4NBPdgU/ETfsrb/2IEDPnke4HL3JDPIZC77Ic=";
      };
      deckcraft = {
        version = "0.18.0";
        description = "Create and present slide decks";
        x86_64-linux = "sha256-0fEpr4wS8SULzBfbzbqsOAkAyROByEpK2m7ntICk2wY=";
        aarch64-linux = "sha256-t2xKDAnyIF1KbIpmnp+zb+Nr1U9Il8kf7hqONJUe/iE=";
      };
      designcraft = {
        version = "0.20.0";
        description = "Lay out magazines, books and print documents";
        x86_64-linux = "sha256-b3IQO2+iPct3vteUt6MBGJoqd6SMtjBadtvTMWmm6N4=";
        aarch64-linux = "sha256-1PEtAveq1lLRk+QDb1Umc56dsbPr0qdxmHB4mWo8yMs=";
      };
      effectcraft = {
        version = "0.24.0";
        description = "Motion graphics and visual effects compositor";
        x86_64-linux = "sha256-l7Ws6bjL44qF/k7dAuR+vfQnKTML0oC6IHTAiblrUCI=";
        aarch64-linux = "sha256-yjeZ8XIxZii2YacRGjnjk0VOodw4YmDo6HKIS+59cGw=";
      };
      figcraft = {
        version = "0.18.0";
        description = "Design and prototype user interfaces";
        x86_64-linux = "sha256-jHZKpXlYqkY0w/0taHk6f4jQsyZtH0pIe3inB607JRM=";
        aarch64-linux = "sha256-u0/lG0Qkli3rF1AwzQVIWxI40TPdwJ8RfK7gaHB6LqY=";
      };
      filmcraft = {
        version = "0.20.0";
        description = "Edit video, color and sound";
        x86_64-linux = "sha256-NUZdcb3hifUMrK8+T9icTKY3f6+OtI6qLwZbjlRZMjY=";
        aarch64-linux = "sha256-wp1dUxgHoVUSXyUmp6lglmsIbudXS+XTXXFzSXFAOMA=";
      };
      gridcraft = {
        version = "0.19.0";
        description = "Calculate, analyse and chart data in workbooks";
        x86_64-linux = "sha256-47HPSpJuKvp+isIukIt833uvYQO7RE+Za/oLw9iJrbY=";
        aarch64-linux = "sha256-HKRUu3OBPbzYtwThGYPOH+1Vm2PLlBjsB7zZcUASBtQ=";
      };
      lightcraft = {
        version = "0.21.0";
        description = "Organise photos and develop raw files, non-destructively";
        x86_64-linux = "sha256-fn2lU96hACaKBY8TXHxK0fT7drTYJC4U9w8W7YkllYA=";
        aarch64-linux = "sha256-I0cddfSYFPpzTZSpkNHmxhRBrvBAPnuUVxsJ6fsY9Rs=";
      };
      pdfcraft = {
        version = "0.21.0";
        description = "Read, organize, combine, split and secure PDFs";
        x86_64-linux = "sha256-eajHbiOtbmcd47hWpHaTavwAD4qn/v/xkNQ95i+jW6E=";
        aarch64-linux = "sha256-HNeaGE1YqiOS+9wAdWDjk5h42W8SssBslvTzhfxhPQk=";
      };
      photocraft = {
        version = "0.23.0";
        description = "Edit photos and layered PSD documents";
        x86_64-linux = "sha256-mFjuI0hU98OQ8+q0c0rqUxAMyRLCyNzqoClCe3XdIvg=";
        aarch64-linux = "sha256-LOiXgpLTFI4YUmtUC20M9eqbmkt4LTRcyk08A+i6dRw=";
      };
      soundcraft = {
        version = "0.20.0";
        description = "Record, edit and mix audio and MIDI";
        x86_64-linux = "sha256-zoR0Rz4+f+sidq8E/yBzLtY5EFXxiJE3eYNPUU7hpkg=";
        aarch64-linux = "sha256-1dp3ph6C05OWPlFVk3jvPQvtFQKjjnxuJyyS/GOlLeg=";
      };
      vectorcraft = {
        version = "0.24.0";
        description = "Draw and edit vector illustrations, SVG and PDF";
        x86_64-linux = "sha256-nGFxygB6b4NcNotZL+nukMmF1lBX7cnc0rxMTvxQrSs=";
        aarch64-linux = "sha256-3WF1ZjFsr3A4hN4e2/EJ9w3wPrlJ75NUYj6u1agivD4=";
      };
      wordcraft = {
        version = "0.18.0";
        description = "Write and design documents; open and save Word files";
        x86_64-linux = "sha256-8paT5gNt6UFWzvQrzb1kR4oa7C85akwqFaf3JT51kiY=";
        aarch64-linux = "sha256-o41h0cR9J0tgOMI9LbyuiCug17EAjAi2AdVq0aqlGCE=";
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
