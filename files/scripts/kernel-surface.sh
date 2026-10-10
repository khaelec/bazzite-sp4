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
SURFACE_REPO_URL="https://pkg.surfacelinux.com/fedora/${FEDORA_SURFACE_REPO}/"
SURFACE_KEY_URL="https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc"

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

echo "::group::Import the linux-surface signing key"
rpm --import "${SURFACE_KEY_URL}" || true
echo "::endgroup::"

echo "::group::Inspect existing repos"
ls -la /etc/yum.repos.d/ || true
echo "--- pre-existing linux-surface repo (if any) ---"
cat /etc/yum.repos.d/linux-surface.repo 2>/dev/null || echo "(none)"
echo "::endgroup::"

echo "::group::Install kernel-surface and Surface userspace"
# Use an ad-hoc repo definition (--repofrompath) with a UNIQUE id, because the
# Bazzite base image may already define a "linux-surface" repo. Exact --exclude
# names keep Fedora's kernel out without matching kernel-surface*.
dnf -y install --refresh --allowerasing --setopt=install_weak_deps=False \
    --repofrompath="surface-sp4,${SURFACE_REPO_URL}" \
    --enablerepo=surface-sp4 \
    --exclude=kernel --exclude=kernel-core --exclude=kernel-modules \
    --exclude=kernel-modules-core --exclude=kernel-modules-extra \
    kernel-surface \
    kernel-surface-modules-extra-matched \
    iptsd \
    libwacom-surface
echo "::endgroup::"

echo "::group::Disable repos whose local GPG key file is missing"
# bootc-image-builder depsolve reads every enabled repo; some Bazzite repos
# (e.g. terra-mesa) reference a file:// GPG key that is not present, which makes
# ISO generation fail. Disable any such repo. Installed packages are unaffected.
for repo in /etc/yum.repos.d/*.repo; do
    [ -e "${repo}" ] || continue
    missing=""
    for path in $(grep -o 'file://[^[:space:]]*' "${repo}" 2>/dev/null | sed 's#^file://##'); do
        [ -f "${path}" ] || missing="${path}"
    done
    if [ -n "${missing}" ]; then
        echo "$(basename "${repo}"): missing GPG key ${missing} -> enabled=0"
        sed -i 's/^enabled=1/enabled=0/' "${repo}"
    fi
done
echo "::endgroup::"

echo "::group::Regenerate the ostree initramfs for the new kernel"
VER="$(ls -1 /usr/lib/modules | head -n1)"
export DRACUT_NO_XATTR=1
dracut --kver "${VER}" --force --add ostree --no-hostonly --reproducible \
    "/usr/lib/modules/${VER}/initramfs.img"
echo "::endgroup::"

echo "::group::Cleanup"
dnf clean all
echo "::endgroup::"

echo "linux-surface kernel baked in: ${VER}"
