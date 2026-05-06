# VOID SHIFT — Flutter

Gravity-flipping arcade survival game. Tap to flip gravity. Survive the void.

## Stack
- **Flutter 3.22** (Dart)
- **Custom Canvas renderer** — no game engine dependency
- **GitHub Actions** — auto-builds web + APK on every push

## Quick Deploy

### Web (Free — GitHub Pages)
1. Push this repo to GitHub (`kevinleestites2-dev/voidshift`)
2. Go to repo Settings → Pages → Source: `gh-pages` branch
3. GitHub Actions builds automatically → live at `https://kevinleestites2-dev.github.io/voidshift/`

### Android APK (Sideload on Red Magic — Free)
1. Push to GitHub
2. Actions tab → click the latest run → download `voidshift-debug.apk`
3. Install on your phone

### Play Store (Requires $25 Google Play Developer account)
See `docs/play-store-deploy.md`

## Submit to CrazyGames
- Build web version
- Go to crazygames.com/developer → Submit Game
- Upload the `build/web/` folder as a zip
- Category: Arcade
- Tags: gravity, arcade, survival, casual

## Submit to Poki
- Email: developers@poki.com
- Subject: "VOID SHIFT — Gravity Arcade Submission"
- Attach: web build zip + screenshots

## Submit to itch.io
- Go to itch.io/game/new
- Upload web build
- Set price: Free (with donations enabled)
- Tags: arcade, gravity, survival, mobile
