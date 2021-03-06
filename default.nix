{ hostPkgs ? import <nixpkgs> { }

, fetched ? s: (hostPkgs.nix-update-source.fetch s).src

, pkgs ? import (fetched ./pin.json) { }

}:
with pkgs.lib;
let

  dhall-to-cabal-resources = pkgs.stdenv.mkDerivation {
    name = "dhall-to-cabal-resources";
    src = pkgs.haskellPackages.dhall-to-cabal.src;
    installPhase = "cp -r dhall $out";
  };

  hs-tools = { haskell, mkDerivation, stdenv, cabal-install, apply-refact
    , hdevtools, Glob, hindent, fswatch, hlint, relude, shake, Cabal
    , fix-imports, ghcid, typed-process, optparse-applicative, unix
    , cabal-helper, dhall }:
    let
      ghcide = (import (builtins.fetchTarball
        "https://github.com/hercules-ci/ghcide-nix/tarball/master")
        { }).ghcide-ghc865;
      ormolu = let
        source = pkgs.fetchFromGitHub {
          owner = "tweag";
          repo = "ormolu";
          rev = "f83f6fd1dab5ccbbdf55ee1653b24595c1d653c2";
          sha256 = "1hs7ayq5d15m9kxwfmdac3p2i3s6b0cn58cm4rrqc4d447yl426y";
        };
      in (import source { }).ormolu;

    in mkDerivation {
      pname = "dummy";
      version = "";
      src = "";
      libraryHaskellDepends = [ cabal-install dhall ormolu hlint ghcide ghcid ];
      description = "";
      license = stdenv.lib.licenses.mit;
    };

  hslib = rec {
    filter = path:
      builtins.filterSource (path: _:
        (baseNameOf path != ".hdevtools.sock") && (baseNameOf path != ".ghc.*")
        && (baseNameOf path != "result") && (baseNameOf path != "README")
        && (baseNameOf path != "dist")) path;
  };
  unbreak = x:
    x.overrideAttrs (attrs: { meta = attrs.meta // { broken = false; }; });
  callPackage = pkgs.lib.callPackageWith pkgs;

  cabalFile = dhallSpec:
    pkgs.runCommand "cabalFile" { } ''
      export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
      export LANG=en_US.UTF-8
      cp ${dhallSpec} cabal.dhall
      substituteInPlace cabal.dhall --replace "= ./dhall-to-cabal" "= ${dhall-to-cabal-resources}"
      ${haskellPackages.dhall-to-cabal}/bin/dhall-to-cabal <<< ./cabal.dhall --output-stdout > $out
    '';

  patchedSrc = source: dhallFile:
    pkgs.runCommand "patchedSrc" { } ''
      mkdir -p $out
      cp -r ${source}/* $out
      chmod -R +rw $out
      cp ${cabalFile dhallFile} $out/monitor.cabal
      chmod +rw $out/monitor.cabal
    '';

  haskellPackages = pkgs.haskellPackages.override {
    overrides = self: super:
      with pkgs.haskell.lib; rec {
        dhall = super.dhall_1_24_0;
        monitor = self.callCabal2nix "monitor.cabal"
          (patchedSrc ./. ./monitor.dhall) { };
      };
  };

  monitor = haskellPackages.monitor;
in {
  inherit monitor;

  monitor-docker = pkgs.dockerTools.buildImage {
    name = "monitor";
    config = {
      Cmd = [ "${monitor}/bin/monitor" ];
      ExposedPorts = {
        "8080/tcp" = {};
      };
      WorkingDir = "/data";
      Volumes = {
        "/data" = {};
      };
    };
  };

  hack = pkgs.haskellPackages.shellFor {
    packages = p: [
      haskellPackages.monitor
      (haskellPackages.callPackage hs-tools { })
    ];
    withHoogle = true;
    #buildInputs = [ ];
    shellHook = ''
      export NIX_GHC="${haskellPackages.monitor.env.NIX_GHC}"
      export NIX_GHCPKG="${haskellPackages.monitor.env.NIX_GHCPKG}"
      export NIX_GHC_DOCDIR="${haskellPackages.monitor.env.NIX_GHC_DOCDIR}"
      export NIX_GHC_LIBDIR="${haskellPackages.monitor.env.NIX_GHC_LIBDIR}"
      export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
      export LANG=en_US.UTF-8
      cp $CABALFILE monitor.cabal
      ln -s ${dhall-to-cabal-resources} dhall-to-cabal
      chmod +rw monitor.cabal
    '';
    CABALFILE = cabalFile ./monitor.dhall;
  };
}
