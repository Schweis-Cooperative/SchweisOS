# schweisos-branding

`schweisos-branding` provides minimal SchweisOS visual identity assets for
runtime consumers such as KDE System Information, icon themes, and generic
desktop logo lookup.

The package intentionally does not configure wallpapers, themes, boot artwork,
Plymouth, SDDM themes, installer branding, or KDE defaults. Other owners may
consume the installed assets for approved user-facing features; those owners
remain responsible for their own behavior and validation.

## Ownership

- The single canonical source is `branding/assets/logo/schweisos.png`.
- Runtime-ready assets are installed by this package.
- Distribution identity metadata remains owned by `schweisos-release`.
- Repository trust remains owned by `schweisos-keyring`.

## Installed assets

```text
/usr/share/schweisos/branding/schweisos.png
/usr/share/icons/hicolor/1024x1024/apps/schweisos.png
/usr/share/pixmaps/schweisos.png
/usr/share/licenses/schweisos-branding/BRAND-ASSETS.md
```

The hicolor and pixmaps paths are package-owned relative symlinks to the
canonical runtime payload under `/usr/share/schweisos/branding/`; the package
does not install three independent image copies.

`/usr/lib/schweisos-release/os-release` uses `LOGO=schweisos`; this package
provides the matching icon name without changing the operating-system identity
contract.
