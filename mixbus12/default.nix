{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:
pkgs.callPackage ./mixbus12.nix {}
