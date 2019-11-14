# very opinionated haskell project skeleton/toolchain.

Warning: not planning to maintain this.

This is a (pinned) [Nix](https://nixos.org)-provisioned setup for a haskell
project with the following tooling: [cabal](https://www.haskell.org/cabal/),
[ghcid](https://github.com/ndmitchell/ghcid),
[ghcide](https://github.com/digital-asset/ghcide),
[ormolu](https://github.com/tweag/ormolu),
[hlint](https://github.com/ndmitchell/hlint), and
[dhall-to-cabal](https://github.com/dhall-lang/dhall-to-cabal). It's goals are
reproducibility, maintainability, and hacking speed of a single software
artifact in a system-independent manner with a provisioned dev workflow\*. The
vim configuration from
[this](https://github.com/freuk/horror/releases/tag/hs-toolchain-compatible)
tooling provisioning strategy is compatible with this haskell setup.

Example use case: developing a haskell project directly onto some random
Nix-enabled x86 box whose global environment should not be polluted.

# Usage

If you don't have Nix yet, visit
[https://nixos.org/nix](https://nixos.org/nix).

## Release : 

The package is built using:

```
nix-build -A skeleton
```

## Hack: 

Optional: setup caches.

```
$ nix-env -iA cachix -f https://cachix.org/api/v1/install
$ cachix use hercules-ci
```

Enter `nix-shell`. You may then use the provisioned `ghcid`, `ghcide`,
`ormolu`, `hlint` and `cabal` executables from the repository root. This
nix-shell writes a local `.gitignore`-filtered cabal file upon starting. This
is unsightly, but not as troublesome as vendoring it and more elegant than
wrapping cabal commands through the entire toolchain, which would be otherwise
needed since `cabal` really insists on having its project configuration file at
the root of the project. 

Remaining redundant sources of information for the development environment are:
`hie.yaml` cradle rules (should evolve with your cabal file target names), and
`ghcid`/`ghcide`/`ormolu`/`cabal` CLI arguments. Those unfortunately need to
evolve with cabal modules and additional language extensions one enables - the
default configuration here enables tons of those, as well as a lot of ghc
warnings. In bash syntax, you can use the following:

- incremental build: `rm .ghc* && cabal v2-build skeleton`
- compiler feedback: `rm .ghc* && ghcid --command 'cabal v2-repl skeletonlib
  --ghc-options=-fno-code'`
- language server(hs): `rm .ghc* && ghcide` (for editor integration; your
  editor should launch `ghcide --lsp`.)
- formatting(hs): `ormolu -o -XTypeApplications < <file>` (this extension is
  the only one enabled here that needs to be passed, AFAIK.)
- linting(hs): `hlint <file>`
- formatting(dhall) `dhall format < <file>` 

The `rm .ghc*` preamble is used to remove all `.ghc.environment.*` files, which
cabal places at the root of the repository (see this
[issue](https://github.com/haskell/cabal/issues/4542)).

## Configuration:

Edit `default.nix`, `skeleton.dhall`. 

# Description

This setup uses `Nix` for (pinned) provisioning/package overlays,
`dhall-to-cabal` for build system configuration/haskell dependency list
generation (through `cabal2nix`). 

\*: It does not take into account other concerns, like variability in dev tools
among maintainers, compliance with other toolchains, ability to publish to
standard repositories like hackage, taste for simplicity, initial provisioning
time or legibility. More precisely, this lacks cabal version bounds, stack file
generation, CI tests for checking buildability with various other provisioning
methods, support for other LSP servers/tools, and so on. It's also cryptic for
some unfamiliar with either dhall or nix, and probably inconveniencing to
experienced users in general.
