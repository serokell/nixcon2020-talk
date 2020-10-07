---
title: Nix Flakes in production
subtitle: What? Why? How?
author: Alexander Bantyev @balsoft
institute: serokell.io
date: 2020-10-16
aspectratio: 169
mainfont: Catamaran
monofont: Ubuntu Mono
sansfont: Oswald
theme: Serokell
header-includes:
  - \usepackage[outputdir=_output]{minted}
  - \usemintedstyle{native}
---



  
About this presentation
-----------------------

::: notes
Hi, I'm Alexander Bantyev, known online as @balsoft, and I write Nix at
Serokell. Lately, we have started switching pipelines for our production
systems to flakes, and I would like to explain why and share some of my
experiences and thoughts on the matter.
:::

You may find sources for this talk at
**<https://github.com/serokell/nixcon2020-talk>** .

I encourage you to build it and follow along by yourself.

::: notes
This talk is separated into three sections, each one a bit more advanced
than the last. I hope that it will be useful to three categories of
people:

-   those who are familiar with the basics of nix but haven't heard
    about flakes;
-   those who have heard of flakes flakes, but never used them for
    anything practical;
-   those who are using flakes for their personal projects and are
    looking to expand the usage to their workplace.
:::

What are those flakes again?
============================

RFC
---

::: notes
Flakes were proposed in [RFC 49](https://github.com/NixOS/rfcs/pull/49),
the RFC is accepted already and the work on flakes is ongoing in Nix'
master branch. I believe they are going to be released as part of Nix
3.0 release.
:::

<https://github.com/NixOS/rfcs/pull/49>

### Abstract

> Flakes allow hermetic, reproducible evaluation of multi-repository Nix
> projects; impose a discoverable, standard structure on Nix projects;
> and replace previous mechanisms such as Nix channels and the Nix
> search path.

Ok, but what are they?
----------------------

::: notes
A flake is basically a directory that contains `flake.nix` at the root.
That's it. The repository that this talk is built from is a flake.
`nixpkgs` is a flake. `nix` itself is a flake. Flakes also tend to
contain a `flake.lock` file in them.
:::

> A flake is a directory that contains a file named `flake.nix` in the
> root directory

### Examples of flakes

-   nixpkgs
-   Nix
-   This presentation

And what's in those files?
--------------------------

::: notes
`flake.nix` is a file defining an attribute set with various attribute.
Most notable are `description` (a string), `inputs` (an attrset) and
`outputs` (a function of `inputs`). `flake.lock` is a JSON file pinning
versions and checksums of all the `inputs`.
:::

### `flake.nix`

```nix
{
  description = "<...>";
  inputs = { nixpkgs = <...>; };
  outputs = { self, nixpkgs }: { <...> };
}
```

### `flake.lock`

```json
{
    "nodes": <...>,
    "root": "root",
    "version": 7
}
```

Why would one use them for production?
======================================
What qualities do we need from nix in our production projects?
--------------------------------------------------------------

::: notes
Now that you know what a flake is, we can move on to the next question:
Why would one use them in a production environment? But first, let's look
at our requirements to understand what problems we're trying to solve.
:::


-   Reproducible

    ::: notes
    at both evaluation and build time: whether it's a developer
    building the project on their computer or a CI build, the output
    must be as similar as possible;
    :::

-   Easy to use

    ::: notes
    Developers with little nix experience need to be able to easily
    update dependencies and build their project;
    :::

-   Cross-platform

    ::: notes
    Our developers use all three major OSs and we need to support all of
    those.
    :::

::: notes
So, to understand why we are excited about flakes, let's take a look at
the alternatives. We'll use a simplified version of this talk's nix expression
as an example.
:::

Alternatives: Channels
----------------------

::: notes 
Channels are a simple idea: a separate command, `nix-channel`,
downloads tarballs, unpacks and places them somewhere in `NIX_PATH`.

-   Benefits
    -   Easy to write simple standalone packages with use of
        `import <nixpkgs> { }`;
    -   Easy to update dependencies;
    -   Easy to override dependencies:
        `NIX_PATH=nixpkgs=/path/to/nixpkgs ...`.
-   Drawbacks
    -   Stateful: requires that `nix-channel` is ran before building
        anything;
    -   Not composable: channels can't depend on other channels
    -   Not reproducible at all: unless you explicitly mention the
        nixpkgs commit that you are using, there is no way to
        reproducibly build the package.
:::

### Set up (for every user that wants to build your package)

    $ nix-channel --add \
      https://github.com/serokell/nixpkgs/archive/master.tar.gz nixpkgs
    $ nix-channel --update

### `default.nix`

```nix
let pkgs = import <nixpkgs> { }; in pkgs.callPackage ./talk.nix { }
```

### Update (stateful)

    $ nix-channel --update

### Override

    $ NIX_PATH=nixpkgs=/path/to/nixpkgs nix-build


Alternatives: Pinning with fetchTarball
---------------------------------------

::: notes
If you dislike the idea of your package depending on a stateful, mutable
channel -- you can easily pin your dependencies with `builtins` (either
`fetchTarball` or `fetchGit`).

-   Benefits
    -   Somewhat reproducible: unless you accidentally use channels or
        import some impure location, your users will get results similar
        to yours;
    -   Somewhat composable: packages you use may use the same method to
        get their dependencies;
    -   Stateless: doesn't require people building your package to
        perform any additional actions other than `nix-build`.
-   Drawbacks
    -   Cumbersome: requires manually updating versions of dependencies
        by figuring out commits and hashes and then editing the sources;
:::


### Set up (or update/override)
   
    # Go to github and get the commit you want, then paste it accordingly below
    $ nix-prefetch-url \
        https://github.com/serokell/nixpkgs/archive/1e22f760.tar.gz
    # Paste the output to sha256 argument of fetchTarball

::: block
### `default.nix`
```nix
let nixpkgs = builtins.fetchTarball {
  url = "https://github.com/serokell/nixpkgs/archive/1e22f760.tar.gz";
  sha256 = "0sfklpvmq9d4j81x886v9n6n176m9hxp0zi1hzkhv4gip185932j";
}; pkgs = import nixpkgs { }; in pkgs.callPackage ./talk.nix { }
```
:::

-   No way to easily update or override inputs (requires changing the
    file manually)


Alternatives: Niv
-----------------

::: notes
In summer 2019, @nmattia started work on Niv, a project which promises
"Easy dependency management for Nix projects". And it does deliver on
that promise. We have switched most of our projects to use Niv before we
started experimenting with flakes, and that wasn't any time wasted because
transtitioning from Niv to flakes is easier than transitioning from
channels to flakes.

-   Benefits
    -   Somewhat reproducible: unless you accidentally use channels or
        import some impure location, your users will get evaluation
        results similar to yours;
    -   Somewhat composable: packages you use may use the same method to
        get their dependencies;
    -   Stateless: doesn't require people building your package to
        perform any additional actions other than `nix-build`.
-   Drawbacks
    -   Requires a separate tool -- Niv, which means no integration with
        the rest of the ecosystem;
:::

### Set up (while creating the package)

    $ niv init
    $ niv add nixos/nixpkgs

### `default.nix`

```nix
let sources = import ./nix/sources.nix; pkgs = import sources.nixpkgs { };
in pkgs.callPackage ./talk.nix { }
```

### Update

    $ niv update nixpkgs

### Override

    $ niv update nixpkgs -a owner=serokell -a repo=nixpkgs

Actually...
-----------

Common drawbacks:

-   Lack of standard structure;

    ::: notes
    There is no standard format for `default.nix`, meaning that every
    project implements their own. I have seen `default.nix` with a
    single derivation, an attrset of derivations, a list of derivations,
    a `callPackage`-able expression, and even a mess of derivations and
    attrsets. Some projects have multiple entry points. All of this
    makes the life of a user painful. This contradicts the "Ease of
    use" requirement;
    :::

-   Extreme reliance on `nixpkgs`;

    ::: notes 
    Nixpkgs is *the* nix repository. Most `nix-*` tools implicitly
    use nixpkgs in some way. This is bad for projects that simply can't be
    added to nixpkgs (e.g. closed-source, proprietary, trifling, company-specific,
    etc) because they require extra fiddling to work with default tooling.
    This contradicts the "Ease of use" requirement 
    :::

-   No simple way to enforce hermetic evaluation;

    ::: notes
    While pinning with fetchTarball or Niv do *help* you get
    reproducible evaluations, they don't enforce it. You can still
    accidentally use `<nixpkgs>` somewhere, thus ruining
    reproducibility. It doesn't help that `nixpkgs` uses
    `builtins.currentSystem` to guess the system we're building for,
    which means the derivations produced by the same nix expression on
    Linux and Mac are going to be different. This contradicts the
    "Cross-platform" and "Ease of use" requirements
    :::

-   No integration with the rest of Nix.

    ::: notes
    There is no way to easily override inputs from the `nix-` commands.
    This contradicts the "Ease of use" requirement
    :::

Enter Flakes
------------

::: notes
As you might have guessed, flakes solve all of these problems.

-   Impose a standard structure on `flake.nix`.
-   Remove any reliance on `nixpkgs` in tooling.
-   Enforce hermetic evaluation by removing `NIX_PATH` and
    `builtins.currentSystem` among other things.
-   Integrate tightly with other nix tooling.
:::

### `flake.nix`
```nix
{
  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
  };
  outputs = { self, nixpkgs }: {
    defaultPackage = builtins.mapAttrs
      (_: pkgs: pkgs.callPackage ./talk.nix { })
      nixpkgs.legacyPackages;
  };
}
```

::: notes
There's quite a lot happening in this file, and we'll get back to what
everything means later in the talk. For now, note that we specify inputs
by describing their locations but not their versions (those are pinned
automatically by nix in `flake.lock` -- remember that?), and that `outputs`
depend on the inputs. Also note how we never use `builtins.currentSystem`
and instead map over all the possible systems provided by `nixpkgs`, meaning
you can evaluate a derivation for any platform from any platform easily,
and that we never use `<nixpkgs>` or other impure things.
:::

<!-- Actual framebreaks are broken in minted; this will do for now -->
## 

### Set up (not required, it just copies a skeleton for flake.nix to the project)

    $ nix flake init

### Update

    $ nix flake update --update-input nixpkgs
    # or
    $ nix build . --update-input nixpkgs

### Override

    $ nix flake update --override-input nixpkgs ../nixpkgs
    # or
    $ nix build . --override-input nixpkgs ../nixpkgs

New `nix` command UI
--------------------

::: notes
Apart from differences in evaluation and structure of the files, flakes
also change the interface of `nix`. Old interface (`nix-` commands) is
still available for compatibility purposes.
:::

::: columns

:::: column
### Old

    nix-build -A foo
    nix-shell -p foo
    nix-shell "<nixpkgs>" -A foo
    nix-env -iA nixos.foo
    nix-env -f . -iA foo
    nix-instantiate -A foo

::::

:::: column
### New

    nix build .#foo
    nix shell nixpkgs#foo
    nix develop nixpkgs#foo
    nix profile install nixpkgs#foo
    nix profile install .#foo
    nix eval .#foo

::::

:::

Flake references
----------------

::: notes
Before flakes, building projects without cloning them was verbose and
inconsistent. Now all the nix command accept a flake reference, which is
usually shorter and clearer than the old tarball link. This also means
you can now easily fetch private repos without resorting to `-E`.
:::

### Before

    $ nix-shell https://github.com/serokell/xrefcheck/archive/master.tar.gz \
        -A xrefcheck
    $ nix-shell -p "(import (builtins.fetchGit \
        https://example.com/private/repo)).something"

### Now

    $ nix shell github:serokell/xrefcheck/flake
    $ nix shell git+https://example.com/private/repo#something

Summary
-------

::: notes
To reiterate, flakes solve many problems we were facing with nix, which
is why we've decided to use them for many of our projects.
:::

-   Hermetic and reproducible evaluation
-   Intuitive, consistent, less verbose user interface
-   (Meta-)dependency management integrated directly into nix commands



How to use flakes right now?
============================

Quick start
-----------

::: notes 
Now that I have explained the *what* and the *why*, it's time for the *how*. In this section, I will explain the basics of how to get up and running with flakes and integrate them into your existing infrastructure. 
:::

### Get Nix 3.0-pre

::: notes 
If you want to create or modify flakes easily, you will have to get a version
of Nix that supports them. The easiest option is to get `nixUnstable` from
nixpkgs. 
:::

    $ nix-shell -p nixUnstable
    $ nix --version
    nix (Nix) 3.0pre20200829_f156513

### Read Eelco's blog posts

-   [tweag.io/blog/2020-05-25-flakes](https://www.tweag.io/blog/2020-05-25-flakes/)
-   [tweag.io/blog/2020-06-25-eval-cache](https://www.tweag.io/blog/2020-06-25-eval-cache/)
-   [tweag.io/blog/2020-07-31-nixos-flakes](https://www.tweag.io/blog/2020-07-31-nixos-flakes/)


Writing flakes
--------------

::: notes 
There is quite a lot of information about flakes on the web,
but I haven't found much advice on how to actually write or integrate flakes
into already existing projects. I would like to remedy that by explaining
what everything means in a flake and sharing my experience of flakifying
the infrastructure. 
:::

### Initialize our first flake

::: notes
Let's initialize our first flake:
:::

    $ mkdir my-first-flake && cd my-first-flake
    $ nix flake init
    $ git init && git add --all # flake.nix must be in git index
    $ cat flake.nix

::: notes
And take a look at what's inside:
:::

### `flake.nix`
```nix
{
  description = "A very basic flake";
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
    defaultPackage.x86_64-linux = self.packages.x86_64-linux.hello;
  };
}
```

::: notes

Let's go through what every part of that file means. First of all, there
is `description`, and I'm pretty sure we all understand what this is for.
Next, there is `outputs`, which is a function of `inputs`. It returns the
attrset of, well, outputs. There are some attributes that are known to
nix (both `packages` and `defaultPackage` are standard), but you may also
provide your own.

The argument of `outputs` is the attrset of `inputs`. `self` is always
an input, and it refers to this very flake, `nixpkgs` is an "indirect"
input (meaning its value is taken from a flake registry and not from `inputs`
attribute of this flake; don't worry about it too much, it is the same
as specifying `inputs.nixpkgs.url = "github:nixos/nixpkgs"`).

As you can see, all the flake outputs are available as top-level attributes
of those corresponding inputs. However, you actually can also access other
flake attributes, such as `description` or `inputs`. And, if you cast any
of the input to a string, it will be the path to that flake's source.

Anyways, let's look at the first line of `outputs`. Let's go over what
everything means here. `packages` is an attribute set, where attribute
names are platforms and values are attribute sets of derivations. `legacyPackages`
is an attribute designed specifically for nixpkgs: it's an attrset where
once again platforms are names, but values are arbitrary attribute sets.
In case of `nixpkgs`, `legacyPackages` exports all of the packages we know
and love from `nixpkgs` arranged as usual for every platform it supports.
So, this line actually means "this flake exports `hello` for platform `x86_64-linux`,
by taking `hello` for `x86_64-linux` from nixpkgs".

Let's go over the next line. `defaultPackages` is an attrset where names
are -- you guessed it -- platforms, and values are derivations. This might
be a bit hard to comprehend at first since we're used to seeing attribute
names roughly match package names in nixpkgs, but if you think about it
for a second it makes sense to do this for a default package. `self.packages.x86_64-linux.hello`
is pretty easy to understand -- it is one of the outputs from this very
flake. So, what this line means is that the default package of this flake
for `x86_64-linux` is `hello`.

Notice how the `x86_64-linux` is specified explicitly here. This means
that this flake will only provide outputs for this particular platform.
This is not really good for being cross-platform, you might think. Actually,
while this way of specifying systems is somewhat more verbose, it's also
much easier for the user to choose for which platform they want to evaluate
and build. Combined with remote builders, this is a very powerful feature
of flakes. For example, provided a flake actually provides an `aarch64`
version of a package, a user on `x86_64` NixOS may very easily build a
native package for `aarch64` by using `boot.binfmt.emulatedSystems`.

:::

## 

::: notes
Now that we understand what every part of that file means, it's time to use it.
:::

### Use it!

    $ nix build
    warning: Git tree '/home/balsoft/projects/my-first-flake' is dirty
    warning: creating lock file '/.../my-first-flake/flake.lock'

::: notes
As you can see, when we build our flake for the first time, it downloads
the latest versions of all the inputs and pins them in `flake.lock`. It
also warns us that the git tree is dirty: that's so that we always know
if what we're building will be reproducible if someone fetches the same
commit as we are on or not.
:::
    
    $ # Is actually "sugar" for
    $ nix build .#defaultPackage.x86_64-linux

::: notes 
By default, `nix build` will try to build `defaultPackage.$CURRENT_PLATFORM`,
but we can also tell it to build that explicitly.

Note that the second time around, nix doesn't download anything, nor does
it build anything. In fact, it doesn't even evaluate anything because of
evaluation caching!
:::

    $ ./result/bin/hello
    Hello, world!
    $ nix shell
    $ # Same as
    $ nix shell .#defaultPackage.x86_64-linux

::: notes
We can also open a shell with `hello` package available.
:::

    $ hello
    Hello, world!
    
## 

### Examine it

    $ nix flake list-inputs
    warning: Git tree '/<...>/my-first-flake' is dirty
    git+file:///<...>/my-first-flake
    └───nixpkgs: github:NixOS/nixpkgs/f26dcb48507bedfe704ca4374808ee725eae69bc

    $ nix flake show
    warning: Git tree '/<...>/my-first-flake' is dirty
    git+file:///<...>/my-first-flake
    ├───defaultPackage
    │   └───x86_64-linux: package 'hello-2.10'
    └───packages
        └───x86_64-linux
            └───hello: package 'hello-2.10'


Provide outputs for all systems
-------------------------------

### `flake.nix`

```nix
{
  # <...>
  outputs = { self, nixpkgs }: {
    packages = builtins.mapAttrs (system: pkgs: { hello = pkgs.hello; })
      nixpkgs.legacyPackages;

    defaultPackage =
      builtins.mapAttrs (_: packages: packages.hello) self.packages;
  };
}

```

::: notes
Let's improve the flake by providing outputs for all the inputs supported
by nixpkgs. Going forward, I'll skip parts that stay the same and only
show the changes.

What does the `packages` declaration means? Well, we use `mapAttrs` function
to map over all of the platforms supported by `nixpkgs` (remember that
attributes of `legacyPackages` are per-platform packagesets). `mapAttrs`
takes a function of two arguments: attribute name (it's the name of the
platform in our case) and value (it's the packageset). Now, for every platform
we generate an attribute set of packages, with just one attribute -- `hello`,
which takes `hello` from the packageset for the corresponding platform.

`defaultPackage` declaration is fairly similar: map over all the platforms
in `packages` of this very flake and for every platform, return `hello`
from that package set.
:::

## 

### Try building for another platform

    $ nix build .#packages.x86_64-darwin.hello

::: notes
Surprisingly, it builds! Well, it's not actually that surprising: after
all, hydra builds quite a lot of packages for Darwin which are subsequently
made available for substitution. `hello` is clearly one of them.
:::

    $ ./result/bin/hello
    zsh: exec format error: ./result/bin/hello

::: notes
Well, it doesn't actually run, but this is expected -- after all, we're
on a different platform!
:::

Add a runnable "application"
----------------------------

### `flake.nix`

```nix
{
  outputs = { self, nixpkgs }: {
    # <...>
    defaultApp = builtins.mapAttrs (system: package: {
      type = "app";
      program = "${package}/bin/hello";
    }) self.defaultPackage;
  };
}
```

::: notes
Let's expand our flake by adding an application which will run our default
package, `hello`. `defaultApp` and `apps` are analogous to `defaultPackage`
and `packages`, but instead of derivations they have attrsets of form `{
type = "app", program }`. So, once again, we map over `defaultPackage`
of this very flake and return the attrset of correct form for every platform.
:::

### Run

    $ nix run
    Hello, world!

Add a test
----------


### `flake.nix`

```nix
{
  outputs = { self, nixpkgs }: {
    # <...>
    checks = builtins.mapAttrs (system: pkgs: {
      helloOutputCorrect = pkgs.runCommand "hello-output-correct" { } ''
        HELLO_OUTPUT="$(${self.packages.${system}.hello}/bin/hello)"
        echo "Hello output is: $HELLO_OUTPUT"
        EXPECTED="Hello, world!"
        echo "Expected: $EXPECTED"
        [[ "$HELLO_OUTPUT" == "$EXPECTED" ]] && touch $out
      '';
    }) nixpkgs.legacyPackages;
  };
}
```

::: notes
`checks` is analogous to `packages`, but the derivations are supposed to
be checks and not packages (pretty obvious, huh?). Here, we map over `nixpkgs.legacyPackages`
again and actually use platform's name to take the `hello` package from
this flake for the correct platform.
:::

## 

### Let's check!

    $ nix flake check -L
    
::: notes
`nix flake check` checks that all of the known outputs are of correct format
and also runs all the checks for the current platform. `-L` flag (which
all nix command accept) displays all of the build logs (they are hidden
by default now and are only shows in case of failure).
:::

    hello-output-correct> Hello output is: Hello, world!
    hello-output-correct> Expected: Hello, world!

### Let's break it and try to check

    $ sed "s/Hello, world/hello world/" -i flake.nix

::: notes
Let's replace the expected test output with an incorrect one
:::

    $ nix flake check
    error: --- Error --- nix
    error: --- Error --- nix-daemon
    builder for '/nix/store/....drv' failed with exit code 1; last 2 log lines:
    Hello output is: Hello, world!
    Expected: hello world!

::: notes
As you can see, a check fails and `nix flake check` errors out.
:::

    $ sed "s/hello world/Hello, world/" -i flake.nix
    
::: notes
Let's be good and fix our tests again!
:::

Package a local application
---------------------------

::: notes
Now that we know how to describe various outputs for flakes, let's
replace GNU Hello from nixpkgs with our own, simple implementation.
:::

### `hello.hs`

```haskell
main :: IO ()
main = putStrLn "Hello, world!"
```

### `hello.nix`

```nix
{ stdenv, ghc }:
stdenv.mkDerivation {
  name = "my-hello";
  nativeBuildInputs = [ ghc ];
  src = ./hello.hs;
  buildCommand = ''
    mkdir -p $out/bin
    ghc $src -o $out/bin/hello
  '';
}
```

::: notes
This is a pretty standard `callPackage`able derivation; it has a single
`stdenv` dependency and just uses gcc to build our simple executable.
:::

## 

### `flake.nix`

```nix
{
  outputs = { self, nixpkgs }: {
    packages = builtins.mapAttrs
      (system: pkgs: { hello = pkgs.callPackage ./hello.nix { }; })
      nixpkgs.legacyPackages;

    # <...>
  };
}
```

::: notes
We just replace `pkgs.hello` with `callPackage ./hello.nix { }` and now
we're using our own hello world implementation! Let's see if it works:
:::

### Does it work?

    $ nix build
    error: --- SysError --- nix
    getting status of '/nix/store/.../hello.nix': No such file or directory
    (use '--show-trace' to show detailed location information)

::: notes
This fails because neither `hello.nix` or `hello.c` are added to git index,
and thus Nix just filters them out before evaluation. Let's add everything
to the index and try again.
:::

## 

### Does it work?

    $ git add --all
    $ nix build
    $ ./result/bin/hello
    Hello, world!
    $ nix flake check
    $ nix run
    Hello, world!

::: notes
It does!
:::

Add an overlay
--------------

::: notes
While it's great to provide a ready-to-use derivation as an output of our
flake, it would also be nice to provide an overlay that can be used with
various versions of nixpkgs.
:::

### `flake.nix`

```nix
{
  outputs = { self, nixpkgs }: {
    # <...>
    overlays.hello = final: prev: {
      hello = final.callPackage ./hello.nix { };
    };
    overlay = self.overlays.hello;
  };
}
```

::: notes
`overlays` is an attribute set of overlays, which must take two arguments:
`final` and `prev`. `overlay` is an overlay.
:::

Shipping a NixOS module
-----------------------

::: notes
Now that we have our application packaged, let's write a NixOS module for
it.
:::

### `module.nix`

```nix
{ lib, pkgs, config, ... }: let cfg = config.services.hello; in {
  options.services.hello = {
    enable = lib.mkEnableOption "a program which displays a greeting";
    program = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
    };
  };
  config.systemd.services.hello = lib.mkIf cfg.enable {
    path = [ cfg.package ];
    serviceConfig.Type = "oneshot";
    script = "hello";
  };
}
```

## 

::: notes
This is a very simple module that adds a one-shot systemd service which
runs our application.
:::

### `flake.nix`

```nix
{
  outputs = { self, nixpkgs }: {
    # <...>
    nixosModules.hello = import ./module.nix;
  };
}
```

Add a `--version` flag
----------------------

::: notes
Let's add a `--version` flag to our `hello` that tells us from which git
revision the executable was build. I'm not going to explain the changes
to Haskell side of things -- just know that it reads the `VERSION` environment
variable at build time to get the current version.
:::

### `hello.hs`

```haskell
{-# LANGUAGE TemplateHaskell, LambdaCase #-}

import Language.Haskell.TH.Syntax (liftString, runIO)
import System.Environment (getEnv, getArgs)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (join)

main :: IO ()
main = getArgs >>= \case
  [] -> putStrLn "Hello, world"
  ["--version"] -> putStrLn version
  ["-v"] -> putStrLn version
  otherwise -> error "Unknown command-line arguments!"
  where version = $(join $ liftIO $ liftString <$> getEnv "VERSION")
```

## 

### `hello.nix`

```nix
{ stdenv, ghc, version ? "unknown" }:
stdenv.mkDerivation {
  # <...>
  VERSION = version;
}
```

::: notes
Here, we add a `VERSION` argument to `mkDerivation`, which sets an env
variable inside the build.
:::

## 

### `flake.nix`

```nix
{
  outputs = {self, nixpkgs}: {
    packages = builtins.mapAttrs (system: pkgs: {
      hello = pkgs.callPackage ./hello.nix {
        version = ''
          Hello ${self.rev or self.lastModifiedDate},
          nixpkgs ${nixpkgs.rev or nixpkgs.lastModifiedDate}'';
      };
    }) nixpkgs.legacyPackages;
    # <...>
  };
}
```

::: notes
Here, we use the fact that evaluated flakes include some information about
their source as attribute. In particular, `git` flakes provide infomation
about their revision when they aren't dirty and about last file modification
time when they are. We use this to provide information about both this
flake itself and nixpkgs in the `--version` output of our program.
:::

## 

### Try it

    $ nix run . -- --version
    warning: Git tree '/.../my-first-flake' is dirty
    Hello 20201007165440,
    nixpkgs 84d74ae9c9cbed73274b8e4e00be14688ffc93fe

::: notes
Because our tree is currently dirty, it shows a date for the Hello itself
and the revision for nixpkgs. Great!
:::

Publish our flake
-----------------

::: notes
Now that we have our very own "Hello" flake, let's publish it so that people
can use it!
:::

### Publish

    $ cd ..; mv my-first-flake hello-flake; cd hello-flake
    $ # Create a new repo on your favorite hosting site
    $ git remote add origin ssh://git@example.com/you/hello-flake.git
    $ git commit -m "Initial commit"
    $ git push --set-upstream-to origin master

### Use it

    $ nix run git+ssh://git@example.com/you/hello-flake.git
    Hello, world!
    $ # Note: if you don't want to publish your repo, try
    $ nix run github:balsoft/hello-flake

Wait, unstable Nix is not an option for CI/developers!
----------------------------------------------------

::: notes
You might say. Well, that is true, but fear not -- Eelco has a solution:
`flake-compat`, a compatibility layer which allows you to use flakes from
old, non-flake nix. You still need a newer Nix version to be able to manipulate
flake dependencies, but your users don't.
:::


### `default.nix`

```nix
(import (fetchTarball
  "https://github.com/edolstra/flake-compat/archive/master.tar.gz") {
    src = builtins.fetchGit ./.;
  }).defaultNix
```

### Build it!

    $ nix --version
    nix (Nix) 2.3.7
    $ nix-build

    
Deploy the application
----------------------

::: notes
Now that we have published our application, let's say we want to deploy
it somewhere.

It's actually quite a common situation for software companies: you are
developing an open-source project, and you want to host it on your server.
Including server definitions in the project itself is pretty bad since
you want other people to use the project and they will no doubt have their
own deployments. So, let's create a new "infra" project and define a NixOS
system there. 
:::

### Create an `infra` repo

    $ mkdir hello-infra
    $ cd hello-infra
    $ git init

### `flake.nix`

```nix
{
  description = "Deployment infrastructure for hello-flake";
  inputs = {
    hello.url = "git+ssh://example.com/you/hello-flake.git";
    hello.inputs.nixpkgs.follows = "nixpkgs";
    # flake = true;
  };
  # <...>
}
```

::: notes

Let's go over what's happening here. `inputs.hello.url` tells nix that
our flake has an input (dependency) named `hello` and that it should be
fetched from the place where we put it earlier. Nix will fetch that input
if you don't have a `flake.lock` file before even beginning to evaluate
`outputs`. When the version is pinned in the lockfile, it won't fetch the
source again unless needed by an output you're currently building.

`inputs.hello.inputs.nixpkgs.follows` tells Nix that it should substitute
whichever nixpkgs version this `hello-infra` flake uses for whatever `hello-flake`
has in its lockfile. This allows us to avoid duplicating nixpkgs versions,
but removes some of the reproducibility.

We may also specify `flake = true`, but that is the default. If you set
`flake = false`, Nix will not interpret that input as a flake and it may
only be used to get the source, and not the outputs. This is useful to
fetch dependencies which don't have `flake.nix` at the root (yet).

:::

## 

::: notes
Now let's write a description of our server. First, let's start with the
shim that we'll use to deploy it to a nixos container. NixOS helpfully
breaks the evaluation when we forget to define a bootloader or a root filesystem.
Neither of those are needed by a container.
:::

### `shim.nix`

```nix
{
  boot.loader.systemd-boot.enable = true;

  fileSystems."/" = {
    device = "/dev/sdZ0";
    fsType = "btrfs";
  };
}
```

## 

### `flake.nix`

```nix
{
  # <...>
  outputs = { self, nixpkgs, hello }: {
    nixosConfigurations.hello = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ hello.nixosModules.hello ./shim.nix
        {
          nixpkgs.overlays = [ hello.overlay ];
          services.hello.enable = true;
        }
      ];
    };
  };
}
```

::: notes

Let's go over what's happening here line-by-line again. `nixosConfigurations.hello`
specifies a NixOS system named `hello`. `nixos-rebuild` will use your hostname
when choosing from `nixosConfigurations` if you don't tell it to use a
specific one, so this can be thought of as the hostname.

`nixpkgs.lib.nixosSystem` is a nixpkgs function that takes some
arguments (you can read it's source to find out which) and outputs an
evaluated NixOS system. Here, we're going to specify `system`
(remember, flakes require explicitly specifying it every time!) and
`modules`. `modules` is a list of NixOS modules -- it has the same
semantics as `inputs` in your `configuration.nix`.  Here, we pass it
`hello.nixosModules.hello` (which is a function), `./shim.nix` (a path
to a nix file exporting an attrset) and an attrset. In this attrset,
we make sure to include `hello.overlay` in the list of nixpkgs
overlays and also enable our service.

:::

## 

### Deploy to a container

::: notes 
Now that we have our infra flake, let's test it out in a `nixos-container`!
If you have recent enough nixpkgs on your system and have Nix 3.0 in `PATH`,
`nixos-container` is already flake-aware. So, we create the container,
telling it to use `hello` configuration from `.` flake.
:::

    $ # Remember update nixpkgs to 20.03, 20.09 or unstable
    $ # Alternatively,
    $ nix shell nixpkgs#nixos-container
    $ sudo nixos-container create --flake .#hello hello
    $ # To update, replace "create" with "update"
    $ sudo nixos-container start hello
    ^C/run/current-system/sw/bin/nixos-container: failed to start container
    
::: notes 
Let's attempt to start our new container.

It may timeout (for a reason unrelated to flakes), so you can just kill
it after 5-10 seconds of initilization
:::

    $ sudo nixos-container root-login hello

::: notes
Let's now log into our container!
:::

    [root@nixos:~]# systemctl restart hello
    [root@nixos:~]# journalctl -u hello
    Oct 06 19:47:40 nixos systemd[1]: Starting hello.service...
    Oct 06 19:47:40 nixos hello-start[375]: Hello, world!
    Oct 06 19:47:40 nixos systemd[1]: hello.service: Succeeded.
    Oct 06 19:47:40 nixos systemd[1]: Finished hello.service.

::: notes
As you can see, our service works.
:::

Deploying to real systems
-------------------------

::: notes
Obviously, `nixos-container` is not suited for production use, and you
want to deploy your software to a real machine. Worry not, there are multiple
ways to do that. I won't go into too much detail on any of those because
I think they are mostly well-documented enough as-is.
:::

-   `nixos-rebuild`

    ::: notes
    With Nix 3.0, `nixos-rebuild` is flake-aware.
    :::    
    
-   https://github.com/notgne2/deploy-rs
    
    ::: notes
    At Serokell, we have been trying to come up with the perfect deployment
    tool for as long as we are running NixOS. We ended up with a very simple
    solution that uses one of flake's outputs to determine what to deploy and
    where. It's inspired by `nix-simple-deploy`, but has a couple additional
    features and a different interface. Mika, the developer of this tool, will
    give a talk about 
    :::

-   https://github.com/misuzu/nix-simple-deploy

    ::: notes
    A simple tool written in Rust that copies profiles to the target server
    and activates them.
    :::

-   etc

    ::: notes
    Most tools that you know and love today are either already compatible
    with flakes or will be compatible soon. After all, if nothing else works,
    you can just build the flake and then point those tools at the `result`
    symlink!
    :::

Small tips and tricks
---------------------

::: notes 

While using flakes, I have read some of Nix' source code and found some
features which are quite non-obvious and obscure. Here, I present some
of my findings to you so that you can use those features too!

:::

### Override dependency of dependency

    $ nix build --override-inputs hello-flake/nixpkgs ../nixpkgs

::: notes
Sometimes, you need to override dependency of a dependency -- use `dependency/dependency`
(may be nested) to achieve this.
:::

### Update all dependencies to latest versions

    $ nix flake update --recreate-lock-file

### Forcefully re-fetch the latest version of a flake

    $ nix flake update github:you/your-flake

Thank you for your attention
----------------------------

This talk was inspired and funded by **[Serokell](https://serokell.io/)**.

Big Thank you to @notgne2, @zhenyavinogradov, @jollheef, @manpages, Denis
Oleynikov and Alexander Rukin for support, proof-reading and help with
design.

The names and logo for Serokell are trademark of Serokell OÜ.

Fonts used in this presentation are taken from [Google Font Library](https://fonts.google.com)
and are licensed under Open Font License.

- **Catamaran** by Pria Ravichandran
- **Oswald** by Vernon Adams
- **Ubuntu Mono** by Dalton Maag

Theme is [beamer-theme-serokell](https://github.com/serokell/beamer-theme-serokell),
which is based on [The Nord Beamer Theme](https://github.com/junwei-wang/beamerthemeNord).
