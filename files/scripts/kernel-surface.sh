#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Bake the linux-surface kernel into a Bazzite (Fedora Atomic / bootc) image.
#
# Runs at image-build time (BlueBuild), NOT on a live system, which is why we
# can safely remove the base kernel with dnf and install kernel-surface.
# Approach mirrors ublue-os/bluefin and askpng/solarpowered.
#
# Fedora 43 is used because linux-surface does not yet publish an f44 repo.
# When https://pkg.surfacelinux.com/fedora/f44/ appears, bump FEDORA_SURFACE_REPO
# AND the base-image "image-version" in recipes/recipe.yml together.
# ---------------------------------------------------------------------------
set -euo pipefail

FEDORA_SURFACE_REPO="f43"

echo "::group::Configure dnf"
dnf -y install dnf-plugins-core --setopt=install_weak_deps=False
dnf -y config-manager setopt install_weak_deps=False
echo "::endgroup::"

echo "::group::Remove the Bazzite/OGC kernel"
# Only the runtime kernel packages. NOTE: never use a bare 'kernel*' glob here,
# because it also matches 'kernel-surface' which we install next.
dnf -y remove \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core \
    kernel-modules-extra \
    kernel-modules-akmod \
    kernel-uki-virt \
    kernel-tools \
    kernel-tools-libs || true
rm -rf /usr/lib/modules/*
echo "::endgroup::"

echo "::group::Add the linux-surface repository (${FEDORA_SURFACE_REPO})"
cat > /etc/yum.repos.d/linux-surface.repo <<EOF
[linux-surface]
name=linux-surface
baseurl=https://pkg.surfacelinux.com/fedora/${FEDORA_SURFACE_REPO}/
enabled=1
skip_if_unavailable=0
gpgkey=https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc
gpgcheck=1
enabled_metadata=1
type=rpm-md
repo_gpgcheck=0
EOF
echo "--- /etc/yum.repos.d/linux-surface.repo ---"
cat /etc/yum.repos.d/linux-surface.repo
echo "--- enabled repos ---"
dnf repolist --enabled || true
echo "--- available kernel-surface ---"
dnf --refresh list --available kernel-surface || true
echo "::endgroup::"

echo "::group::Install kernel-surface and Surface userspace"
# Exclude Fedora's own kernel by EXACT name so dnf cannot pull it back in as a
# dependency; these exact names do not match kernel-surface*.
dnf -y install --allowerasing --setopt=install_weak_deps=False \
    --exclude=kernel --exclude=kernel-core --exclude=kernel-modules \
    --exclude=kernel-modules-core --exclude=kernel-modules-extra \
    kernel-surface \
    kernel-surface-modules-extra-matched \
    iptsd \
    libwacom-surface
echo "::endgroup::"

echo "::group::Regenerate the ostree initramfs for the new kernel"
VER="$(ls -1 /usr/lib/modules | head -n1)"
export DRACUT_NO_XATTR=1
dracut --kver "${VER}" --force --add ostree --no-hostonly --reproducible \
    "/usr/lib/modules/${VER}/initramfs.img"
echo "::endgroup::"

echo "::group::Cleanup"
rm -f /etc/yum.repos.d/linux-surface.repo
dnf clean all
echo "::endgroup::"

echo "linux-surface kernel baked in: ${VER}"
