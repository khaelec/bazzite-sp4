# Bazzite for the Surface Pro 4 (linux-surface kernel baked in)

This is a **BlueBuild** project that produces a custom **Bazzite** image with the
real **[linux-surface](https://github.com/linux-surface/linux-surface) kernel**
compiled in, so a Microsoft **Surface Pro 4** gets working touchscreen, pen,
Type Cover, sensors, Wi-Fi and Bluetooth out of the box.

## Why this exists

- Bazzite's current official build matrix has **no Surface variant**.
- The old `ghcr.io/ublue-os/bazzite-gnome-surface` image is stale (Fedora 38).
- Bazzite's default **OGC kernel carries *some* Surface patches** but not the full
  linux-surface set, and you cannot install `kernel-surface` on a live Bazzite
  system because the OGC kernel "override" on `kernel-modules` blocks it.
- The clean fix is to bake the linux-surface kernel in at **image-build time**,
  which is what this project does.
- linux-surface currently publishes a **Fedora 43** repo only (f44 does not exist
  yet), so the image is based on Bazzite's `stable-43` tag.

## What it builds

| | |
| --- | --- |
| Base | `ghcr.io/ublue-os/bazzite:stable-43` (KDE Plasma; use `bazzite-gnome` for GNOME) |
| Kernel | `kernel-surface` from `pkg.surfacelinux.com/fedora/f43` |
| Extra | `iptsd`, `libwacom-surface`, `kernel-surface-modules-extra-matched` |
| Output image | `ghcr.io/<your-github-user>/bazzite-sp4:latest` |

## Requirements

- A free **GitHub account** (to run the build in GitHub Actions).
- The **Surface Pro 4** with Secure Boot disabled, or set to *"Microsoft & 3rd
  party CA"* (hold **Volume Up** + press **Power** to enter Surface UEFI).

---

## Option A — Quickest: rebase onto the existing community Surface image

If you just want *something* working and don't need the full linux-surface
kernel, you can rebase onto Bazzite's existing Surface image (KDE, built by the
community, may lag):

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/ublue-os/bazzite-surface:latest
systemctl reboot
```

Caveat: that image uses Bazzite's OGC kernel (Surface *patches* merged), **not**
the linux-surface kernel, so SP4 touch/pen may still be missing. Use Option B for
guaranteed linux-surface support.

---

## Option B — Build your own image with the linux-surface kernel (recommended)

### 1. Put this project in a GitHub repo

Create a new **public** GitHub repository (e.g. `bazzite-sp4`) and push the
contents of this folder to it:

```bash
git init
git add .
git commit -m "Bazzite Surface Pro 4 image"
git branch -M main
git remote add origin https://github.com/<your-user>/bazzite-sp4.git
git push -u origin main
```

### 2. Let GitHub Actions build it

The included workflow (`.github/workflows/build.yml`) builds on every push and
daily. Watch it under the repo's **Actions** tab. First build takes ~20–40 min.
When it finishes, your image is published to
`ghcr.io/<your-user>/bazzite-sp4:latest`.

Make the package public: **GitHub → your profile → Packages → bazzite-sp4 →
Package settings → Change visibility → Public** (so `rpm-ostree` can pull it).

### 3. Get it onto the Surface — pick one:

**3a. Install official Bazzite first, then rebase (easiest, no ISO needed)**

1. Download the normal Bazzite **KDE** ISO from <https://download.bazzite.gg>
   and flash it with Ventoy, balenaEtcher or Rufus.
2. Install it on the Surface Pro 4 and boot into it.
3. Rebase onto your custom image and reboot:

   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/<your-user>/bazzite-sp4:latest
   systemctl reboot
   ```

4. Confirm the Surface kernel is active — the output must contain `surface`:

   ```bash
   uname -r
   ```

**3b. Build a bootable ISO directly (put it on a USB)**

After the image build succeeds, run the **build-iso** workflow (Actions tab →
*build-iso* → *Run workflow*). It uses `bootc-image-builder` to turn the image
into a bootable ISO and uploads it as an artifact. Download it, flash it to a
USB stick, and boot the Surface from it.

### 4. (Optional) Sign the image

By default the build is **unsigned** (the workflow passes `--no-sign`), which is
why the rebase command above uses `ostree-unverified-registry:`. To sign:

1. `cosign generate-key-pair` (on any machine) → produces `cosign.key` / `cosign.pub`.
2. Add the contents of `cosign.key` as a repo secret named `SIGNING_SECRET`.
3. In `.github/workflows/build.yml`: **delete** the `build_opts: "--no-sign"`
   line and **uncomment** the `cosign_private_key:` line.
4. Uncomment the `signing` module in `recipes/recipe.yml`.
5. Re-run the build, then rebase with
   `ostree-image-signed:docker://ghcr.io/<your-user>/bazzite-sp4:latest`.

---

## Using GNOME instead of KDE

This project builds **KDE Plasma** (`ghcr.io/ublue-os/bazzite`). To build GNOME
instead, in `recipes/recipe.yml` change:

```yaml
base-image: ghcr.io/ublue-os/bazzite
```

to:

```yaml
base-image: ghcr.io/ublue-os/bazzite-gnome
```

(KDE Plasma has a more Windows-like layout; GNOME is a bit more touch-friendly.
Both run Wayland, which the linux-surface touch stack wants.)

## Keeping it up to date

- The workflow rebuilds **daily**, so you get new linux-surface kernels and
  Bazzite updates automatically. Rebase/`rpm-ostree upgrade` picks them up.
- When linux-surface publishes an **f44** repo, bump **both**:
  - `image-version` in `recipes/recipe.yml` → `stable` (or `stable-44`)
  - `FEDORA_SURFACE_REPO` in `files/scripts/kernel-surface.sh` → `f44`

## Known caveats on the Surface Pro 4

- **Cameras** are still work-in-progress on Linux (front camera via `libcamera`
  only). Touch, pen, Type Cover, Wi-Fi, Bluetooth and sensors work.
- **Bazzite akmods** (e.g. the Xbox-controller driver) are built for the OGC
  kernel and won't apply to `kernel-surface`; those extras are simply absent.
  This does not affect normal use on a Surface.
- **Secure Boot**: disable it, or enrol the appropriate MOK, otherwise the
  unsigned/personal kernel will not boot.
- **Touch calibration**: if the touchscreen is offset, run `sudo iptsd-calibrate`
  (see the [iptsd wiki](https://github.com/linux-surface/iptsd/wiki/Calibrating-iptsd)).
- Tablet UX (small buttons, on-screen keyboard) is rough on any desktop Linux.
  Both KDE and GNOME run Wayland here; if touch feels cramped, GNOME is slightly
  friendlier and can be swapped with one line (see above).

## Files

| Path | Purpose |
| --- | --- |
| `recipes/recipe.yml` | BlueBuild recipe: base image + modules |
| `files/scripts/kernel-surface.sh` | Kernel swap: removes OGC kernel, installs `kernel-surface` |
| `.github/workflows/build.yml` | Builds & publishes the image to GHCR |
| `.github/workflows/build-iso.yml` | Turns the image into a bootable ISO artifact |
| `README.md` | This file |

## References

- linux-surface install guide: <https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup>
- BlueBuild docs: <https://blue-build.org/>
- Bazzite docs: <https://docs.bazzite.gg/>
