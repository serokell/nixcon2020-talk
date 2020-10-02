---
title: Nix Flakes in production
subtitle: What? Why? How?
author: Alexander Bantyev @balsoft
institute: serokell.io
date: 2020-10-16
slidelevel: 3
aspectratio: 169
mainfont: Catamaran
monofont: Ubuntu Mono
sansfont: Oswald
theme: Serokell
---

About this presentation
-----------------------

::: notes
Hi! I'm Alexander Bantyev, known online as @balsoft, and I write Nix at
Serokell. Lately, we have started switching pipelines for our production
systems to flakes, and I would like to explain why and share some of my
experiences and thoughts on the matter.
:::

You may find sources for this talk at
**<https://github.com/serokell/nixcon2020-talk>** .

I encourage you to build it and follow along by yourself!

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

```
{
  description = "<...>";
  inputs = { nixpkgs = <...>; };
  outputs = { self, nixpkgs }: { <...> };
}
```

### `flake.lock`

``` {.json}
{
  "nodes": <...>,
  "root": "root",
  "version": 7
}
```


Why would one use them for production?
======================================

::: notes
Now that you know what a flake is, we can move on to the next question:
Why would one use them in a production environment? There are two parts
to this question: Is there even a point? And aren't flakes unstable
right now? Answers are "Yes" and "Kind of". But first, let's look at our
requirements to understand what problems we're trying to solve.
:::

### What are the benefits? Is there a point in using flakes?

Yes! There are three main benefits: uniform user interface, hermetic
evaluation and integration with the rest of Nix.

### Aren't flakes unstable and dangerous?

Yes and no. Nix 3.0 is currently pretty unstable, but flakes themselves
work pretty well; besides, you don't actually have to use Nix 3 to get
most benefits of flakes! (more on that later)

What qualities do we need from nix in our production projects?
--------------------------------------------------------------

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
the alternatives.
:::

Alternatives: Channels
----------------------

::: notes
Channels are a very simple idea: a separate command, `nix-channel`,
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

    $ nix-channel --add https://nixos.org/channels/nixos-20.09 nixos
    $ nix-channel --update

### `default.nix`

```
let pkgs = import <nixpkgs> { }; in pkgs.callPackage ./talk.nix { }
```

### Update (stateful)

    $ nix-channel --update

### Override

    NIX_PATH=nixpkgs=/path/to/nixpkgs nix-build

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

-   No way to easily update or override inputs (requires changing the
    file manually)

### Set up (or update/override)

    # Go to github and get the commit you want, then paste it accordingly below
    $ nix-prefetch-tarball \
        https://github.com/nixos/nixpkgs/archive/66a26e65.tar.gz
    # Paste the output to sha256 argument of fetchTarball

:::

::: block
### `default.nix`


```
let nixpkgs = builtins.fetchTarball {
  url = "https://github.com/nixos/nixpkgs/archive/66a26e65.tar.gz";
  sha256 = "1hdk7frf66if9b35f0xhjs2322y280k2kivpzkfc5s1lc16kzkdp";
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
that promise.

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

```
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
    Nixpkgs is *the* nix repository. Most `nix-*` tools implicitly use
    nixpkgs in some way. This is bad for projects that simply can't be
    added to nixpkgs (e.g. closed-source, proprietary, not very
    important, company-specific, etc) because they require extra
    fiddling to work with default tooling. This contradicts the "Ease
    of use" requirement
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
```
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };
  outputs = { self, nixpkgs }: {
    defaultPackage = builtins.mapAttrs
      (_: pkgs: pkgs.callPackage ./talk.nix { })
      nixpkgs.legacyPackages;
  };
}
```

------------------------------------------------------------------------

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

  **Old**                   **New (flakes)**
  ------------------------- -----------------------------------
  `nix-build -A foo`        `nix build .#foo`
  `nix-shell -p foo`        `nix shell nixpkgs#foo`
  `nix-shell -A foo`        `nix develop .#foo`
  `nix-env -iA nixos.foo`   `nix profile install nixpkgs#foo`
  `nix-env -f . -iA foo`    `nix profile install .#foo`

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
Now that I hopefully have explained the *what* and the *why*, it's time
for the *how*. In this section, I will explain the basics of how to get
up and running with flakes and integrate them into your existing
infrastructure.
:::

### Get Nix 3.0-pre

::: notes
First of all, if you want to create or modify flakes easily, you will
have to get a version of Nix that supports them. The easiest option is
to get `nixUnstable` from nixpkgs.
:::

```
$ nix-shell -p nixUnstable
$ nix --version
nix (Nix) 3.0pre20200829_f156513
```

### Read Eelco's blog posts

-   [tweag.io/blog/2020-05-25-flakes](https://www.tweag.io/blog/2020-05-25-flakes/)
-   [tweag.io/blog/2020-06-25-eval-cache](https://www.tweag.io/blog/2020-06-25-eval-cache/)
-   [tweag.io/blog/2020-07-31-nixos-flakes](https://www.tweag.io/blog/2020-07-31-nixos-flakes/)

