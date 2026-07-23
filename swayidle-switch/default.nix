{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./swayidle-switch.nix {}
