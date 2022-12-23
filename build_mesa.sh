#!/bin/bash

mesa_branch=${mesa_branch:-"21.3"}
mesa_repo=${mesa_repo:-"https://gitlab.freedesktop.org/mesa/mesa.git"}
base_dir=${base_dir:-"${HOME}/Mesa"}
src_dir=${src_dir:-"${base_dir}/mesa-${mesa_branch}"}
build_dir=${build_dir:-"${src_dir}/build"}
patches_dir=${patches_dir:-"${src_dir}/patches"}
llvm_ver=${llvm_ver:-"13"}
cpuarch=${cpuarch:-"native"} # Zen 3 by default. Change to your arch or "native" accordingly.

libdrm=${libdrm:-""}
build_32=${build_32:-false} # Debian Mesa 32-bit cross compilation is currently broken
build_debug=${build_debug:-false}
verbose=${verbose:-false}
update_sources=${update_sources:-true}
reset_sources=${reset_sources:-true}
apply_patches=${apply_patches:-true}

dest_dir=${dest_dir:-"/opt"}
if [[ "$mesa_branch" != "mesa"* ]]; then
   mesa_dir=${mesa_dir:-"${dest_dir}/mesa-${mesa_branch}"}
else
   mesa_dir=${mesa_dir:-"${dest_dir}/${mesa_branch}"}
fi

arch_dir["32"]="x86"
arch_dir["64"]="x86_64"

function assert() {
   rc=$1
   message="$2"
   if ((rc != 0)); then
      echo $message
      exit $rc
   fi
}

function ensure() {
   local rc=1
   while (($rc != 0)); do
      $@
      rc=$?
      if (($rc != 0)); then
         sleep 1
      fi
   done
}

function common_prepare() {
   echo ""
   echo "=== Common setup ===="
   sudo mkdir -p ${mesa_dir}
   sudo rm -rfv ${mesa_dir}/*

   ensure sudo apt-get install build-essential git

   mkdir -p ${src_dir}
   cd $(dirname "$src_dir")
   git clone "$mesa_repo" $(basename "$src_dir")
   cd "$src_dir"

   # If updating, reset is enforced regardless of the $reset_sources, to avoid possible merging confusion
   if $reset_sources || $update_sources; then
     git reset --hard HEAD
     git clean -df
   fi

   if $update_sources; then
     git checkout main
     git pull --rebase --prune
   fi

   git checkout $mesa_branch

   if $apply_patches; then
      mkdir -p "$patches_dir"
      for patch in ${patches_dir}/*; do
        patch -p 1 < ${patch}
        assert $? "Failed to apply patch ${patch}"
      done
   fi

   mkdir -p "$build_dir"
   rm -rfv ${build_dir}/*
}

function prepare_64() {
   echo ""
   echo "=== Preparing 64-bit build ===="

   ensure sudo apt-get build-dep mesa
   ensure sudo apt-get install llvm-${llvm_ver}-dev libclang-${llvm_ver}-dev
}

function prepare_32() {
   echo ""
   echo "==== Preparing 32-bit build ===="
   # TODO: all this needs a working method in Debian
   echo "Not supported now"
   return
     
   ensure sudo apt-get install llvm-${llvm_ver}-dev:i386 libclang-${llvm_ver}-dev:i386 gcc-multilib g++-multilib libdrm-dev:i386 libexpat1-dev:i386 libxcb-dri3-dev:i386 libxcb-present-dev:i386 libxshmfence-dev:i386 libxext-dev:i386 libxdamage-dev:i386 libx11-xcb-dev:i386 libxcb-glx0-dev:i386 libxcb-dri2-0-dev:i386 libxxf86vm-dev:i386 libwayland-dev:i386 libsensors4-dev:i386 libelf-dev:i386 zlib1g-dev:i386 libglvnd-core-dev:i386
}

configure_64() {
   echo ""
   echo "==== Configuring 64-bit build ===="
   cd "$build_dir"

   local build_type='plain'
   local debug_flags=''
   local ndebug=true
   local strip_option='--strip'
   
   if ! [$libdrm = ""]; then
      echo "alternate libdrm path: ${libdrm}"
      export LD_LIBRARY_PATH="${libdrm}/x86_64:$LD_LIBRARY_PATH"
      export LIBRARY_PATH="${libdrm}/x86_64:$LIBRARY_PATH"
      export C_INCLUDE_PATH="${libdrm}/include:$C_INCLUDE_PATH"
      export PKG_CONFIG_PATH="${libdrm}/x86_64/pkgconfig:$PKG_CONFIG_PATH"
      ld_libdrm="-L${libdrm}/x86_64"
      include="-I${libdrm}/include"
   else
      ld_libdrm=""
      include=""
   fi

   if $build_debug; then
      build_type='debug'
      debug_flags='-g'
      ndebug=false
      strip_option=''
   fi

   local native_config
   read -r -d '' native_config <<EOF
[binaries]
llvm-config = '/usr/bin/llvm-config-${llvm_ver}'
cmake = '/usr/bin/false'
EOF

   export CFLAGS="${include}-march=${cpuarch} ${debug_flags} -O2 -fdebug-prefix-map=${HOME}/build=. -fstack-protector-strong -Wformat -Werror=format-security -Wall"
   export CPPFLAGS="${include} -Wdate-time -D_FORTIFY_SOURCE=2"
   export CXXFLAGS="-march=${cpuarch} ${debug_flags} -O2 -fdebug-prefix-map=${HOME}/build=. -fstack-protector-strong -Wformat -Werror=format-security -Wall"
   export LDFLAGS="${ld_libdrm} -Wl,-z,relro"

   LC_ALL=C.UTF-8 meson setup "$src_dir" \
--wrap-mode=nodownload \
--buildtype=$build_type \
$strip_option \
--native-file=<(echo "$native_config") \
--prefix="$mesa_dir" \
--sysconfdir=/etc \
--localstatedir=/var \
--libdir="${arch_dir["64"]}" \
-Dplatforms="['x11']" \
-Ddri3=enabled \
-Ddri-drivers="[]" \
-Ddri-drivers-path="${arch_dir["64"]}" \
-Dglvnd=true \
-Dglx-direct=true \
-Dshared-glapi=enabled \
-Dgles1=disabled \
-Dgles2=enabled \
-Dvulkan-drivers="['auto']" \
-Dvulkan-layers="['device-select','overlay']" \
-Dvulkan-beta=false \
-Db_ndebug=$ndebug \
-Dgbm=enabled \
-Dlmsensors=enabled \
-Dllvm=enabled \
-Dshared-llvm=auto \
-Dgallium-drivers="['auto']" \
-Dgallium-d3d10umd=false \
-Dgallium-nine=true \
-Dgallium-va=disabled \
-Dgallium-omx=disabled \
-Dgallium-extra-hud=false \
-Dgallium-vdpau=disabled \
-Dva-libs-path="${arch_dir["64"]}" \
-Dshader-cache=true \
-Dshader-cache-default=true \
-Dvalgrind=false

   assert $? "Configure failed!"
}

configure_32() {
   echo ""
   echo "==== Configuring 32-bit ===="
   echo "Not supported now"
   return
}

function build() {
   echo ""
   echo "==== Building... ===="
   cd "$build_dir"

   if $verbose; then
      LC_ALL=C.UTF-8 ninja -v
   else
      LC_ALL=C.UTF-8 ninja
   fi

   assert $? "build failed!"
}

function publish() {
  echo ""
  echo "==== Publishing... ===="
  cd "$build_dir"
  DESTDIR="$mesa_dir" LC_ALL=C.UTF-8 sudo ninja install
}

function clean_64() {
   ensure sudo apt-get purge llvm-${llvm_ver}-dev libclang-${llvm_ver}-dev
   ensure sudo apt-get autoremove --purge
}

function clean_32() {
   ensure sudo apt-get purge llvm-${llvm_ver}-dev:i386 libclang-${llvm_ver}-dev:i386 libsensors4-dev:i386
   ensure sudo apt-get autoremove --purge
}

################################################

shopt -s nullglob
common_prepare

prepare_64
configure_64
build
publish
clean_64

if ! $build_32; then
   exit
fi

prepare_32
configure_32
build
publish
clean_32
