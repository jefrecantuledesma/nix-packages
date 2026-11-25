{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:
pkgs.callPackage ./mixbus11.nix {}
