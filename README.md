# NixCon 2020 talk

This is @balsoft 's talk about Nix flakes, to be presented on NixCon
2020.

## Building

This talk itself is a flake which you can build with

```
nix build github:serokell/nixcon2020-talk
```

The presentation is `presentation.pdf`, speaker notes are in
`speaker-notes.pdf`, and a compiled HTML article is in `article.html`.

If you wish to play around with this talk, clone it locally and run `nix
develop`; you will be thrown in a shell with all the required
dependencies including fonts. You can then run `make` to build all the
artifacts or `make autoreload` to start automatically rebuilding the
presentation. I have been writing it while having it open in Okular,
which automatically reloads PDF documents when they change.

### Without flakes

```
nix-build https://github.com/serokell/nixcon2020-talk/archive/master.tar.gz
```
