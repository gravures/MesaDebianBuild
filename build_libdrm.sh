#!/bin/bash

libdrm_branch=${libdrm_branch:-"libdrm-2.4.114"}
libdrm_repo=${libdrm_repo:-"https://gitlab.freedesktop.org/mesa/drm.git"}
base_dir=${base_dir:-"${HOME}/Mesa"}
src_dir=${src_dir:-"${base_dir}/${libdrm_branch}"}
build_dir=${build_dir:-"${src_dir}/build"}
patches_dir=${patches_dir:-"${src_dir}/patches"}
cpuarch=${cpuarch:-"native"} # Zen 3 by default. Change to your arch or "native" accordingly.

build_32=${build_32:-false} 
build_debug=${build_debug:-false}
verbose=${verbose:-false}
update_sources=${update_sources:-true}
reset_sources=${reset_sources:-true}
apply_patches=${apply_patches:-true}

dest_dir=${dest_dir:-"/opt"}
libdrm_dir=${libdrm_dir:-"${dest_dir}/${libdrm_branch}"}


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
   echo "src_dir: ${src_dir}"
   echo "build_dir: ${build_dir}"
   echo "dest_dir: ${dest_dir}"
   
   sudo mkdir -p ${libdrm_dir}
   sudo rm -rfv ${libdrm_dir}/*

   ensure sudo apt-get install build-essential git

   mkdir -p ${src_dir}
   cd $(dirname "$src_dir")
   git clone "$libdrm_repo" $(basename "$src_dir")
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

   git checkout $libdrm_branch

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

   ensure sudo apt-get build-dep libdrm2 libdrm-common libdrm-intel1 libdrm-amdgpu1 libdrm-nouveau2 libdrm-radeon1  
}

function prepare_32() {
   echo ""
   echo "==== Preparing 32-bit build ===="
   # TODO: all this needs a working method in Debian
   echo "Not supported now"
   return
}

configure_64() {
   echo ""
   echo "==== Configuring 64-bit build ===="
   cd "$build_dir"

   local build_type='plain'
   local debug_flags=''
   local ndebug=true
   local strip_option='--strip'

   if $build_debug; then
      build_type='debug'
      debug_flags='-g'
      ndebug=false
      strip_option=''
   fi

   local native_config
   read -r -d '' native_config <<EOF
[binaries]
cmake = '/usr/bin/false'
EOF

   export CFLAGS="-march=${cpuarch} ${debug_flags} -O2 -fdebug-prefix-map=${HOME}/build=. -fstack-protector-strong -Wformat -Werror=format-security -Wall"
   export CPPFLAGS="-Wdate-time -D_FORTIFY_SOURCE=2"
   export CXXFLAGS="-march=${cpuarch} ${debug_flags} -O2 -fdebug-prefix-map=${HOME}/build=. -fstack-protector-strong -Wformat -Werror=format-security -Wall"
   export LDFLAGS="-Wl,-z,relro"

   LC_ALL=C.UTF-8 meson setup "$src_dir" \
--wrap-mode=nodownload \
--buildtype=$build_type \
$strip_option \
--native-file=<(echo "$native_config") \
--prefix="$libdrm_dir" \
--sysconfdir=/etc \
--localstatedir=/var \
--libdir="${arch_dir["64"]}" \
-Damdgpu=enabled \
-Dintel=enabled \
-Dnouveau=enabled \
-Dradeon=enabled \
-Dvmwgfx=disabled \
-Dman-pages=disabled \
-Dvalgrind=disabled \
-Dfreedreno-kgsl=false \
-Dinstall-test-programs=false \
-Dudev=false \
-Dtests=false

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
  DESTDIR="$libdrm_dir" LC_ALL=C.UTF-8 sudo ninja install
}

function clean_64() {
   ensure sudo apt-get autoremove --purge
}

function clean_32() {
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
