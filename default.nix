{ nixpkgs ? import <nixpkgs> {}, compiler ? "default", profiling ? false }:

let

  inherit (nixpkgs) pkgs;

  f = import ./hpython.nix;

  haskellPackages =
    ((if compiler == "default"
      then pkgs.haskellPackages
      else pkgs.haskell.packages.${compiler})).override {
       overrides = self: super: {
         mkDerivation = expr:
           super.mkDerivation (expr // { enableLibraryProfiling = profiling; });
         megaparsec = self.megaparsec_7_0_5;
       };
     };

  drv = haskellPackages.callPackage f {};

in

  drv
