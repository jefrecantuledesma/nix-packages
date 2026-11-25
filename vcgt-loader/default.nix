{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./vcgt-loader.nix {}
