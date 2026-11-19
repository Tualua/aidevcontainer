#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

pkgs=()
[ "${COMPUTE:-true}" = true ] && pkgs+=(intel-opencl-icd libze-intel-gpu1 libze1 ocl-icd-libopencl1)
[ "${MEDIA:-true}"   = true ] && pkgs+=(intel-media-va-driver-non-free libva-drm2 vainfo)
[ "${DEVEL:-false}"  = true ] && pkgs+=(libze-dev opencl-headers ocl-icd-opencl-dev)
[ "${TOOLS:-true}"   = true ] && pkgs+=(clinfo intel-gpu-tools)
[ ${#pkgs[@]} -gt 0 ] && apt_install "${pkgs[@]}"
apt_cleanup

getent group render >/dev/null || groupadd -r render
usermod -aG video,render "$REMOTE_USER"
install -m 0755 "$(dirname "$0")/aidev-device-groups" /usr/local/bin/aidev-device-groups
