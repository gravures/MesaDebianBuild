# Mesa Library Build Scripts for Debian

## About

**build_mesa.sh** will install necessary dependencies, build the mesa library and install it in an alternate location (by default it will be: /opt/mesa-{branch}). It will not replace the default system wise version, so it's safe to install for testing newer versions of **Mesa** unavailable in **Debian** repository.

This script has been tested in **Debian** 11 (Bullseye) and was able to build the latest **mesa** library version (at this time the 22.3 branch).  Depending on your **Debian** version, **Mesa** targeted version and mesa drivers build options you could encounter errors in the configuration stage of this script. Essentially this will be due to obsolete dependencies, look at the output to find which library should be updated.

## Installation

#### Building for Mesa 21.3 branch

Make sure deb-src section is configured for your Debian distro in your apt sources. That's needed to install build development packages.

This will build the Mesa-21.3 branch by default.

```bash
git clone https://github.com/gravures/MesaDebianBuild.git
cd  MesaDebianBuild
chmod +x build_mesa.sh
./build_mesa.sh
```

> notes: with Debian Bullseye mesa-21.3.9 is the latest version you could build with the libdrm version provided by the system. 

#### Building for Mesa 22.0 branch and later

You will need at least libdrm-2.4.107 or higher. **build_libdrm.sh** will build this library in version 2.4.114 by default and install it in your /opt directory. Those lines will built libdrm first and mesa library against this new version.  

```bash
chmod +x build_libdrm.sh
./build_libdrm.sh
libdrm=/opt/libdrm-2.4.114 mesa_branch=22.0 ./build_mesa.sh
```

#### Configuration

Obviously don't hesitate to edit those scripts to override build option like branch, build directory or installation directory. You can also prepend the options before calling the script like this:

```bash
libdrm_branch=libdrm-2.4.107 dest_dir=/usr/local ./build_libdrm.sh
```

**mesa_branch** and **libdrm_branch** works for tags and specific hash commits too. 

For mesa specific driver build options you should edit the script directly. Look at [meson_options.txt · main · Mesa / mesa · GitLab](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/meson_options.txt) to see all the available options.



> beginning with the 22.0 branch the mesa dri drivers are no more supported, this is why the list is left empty here.



Options set in build_mesa.sh are essentially targeted at testing the mesa-vulkan driver. Mesa is a complex collections of drivers and it's over the scope of this documentation to cover all the situations. Please consult the Mesa documentation and try to adapt this script to your needs.

## 

## Usage

#### with system libdrm

```bash
#!/bin/bash

MESA_LIB=/opt/mesa-22.1
export LIBGL_DRIVERS_PATH=$MESA_LIB/x86_64
export EGL_DRIVERS_PATH=$LIBGL_DRIVERS_PATH
export LD_LIBRARY_PATH=$LIBGL_DRIVERS_PATH:$LD_LIBRARY_PATH
export VK_ICD_FILENAMES=$MESA_LIB/share/vulkan/icd.d/intel_icd.x86_64.json

# Print some info about rdivers
glxinfo | grep string
vulkaninfo | grep Version
vulkaninfo | grep driver

# Path to your executable
/usr/bin/vkcube
```

#### with custom libdrm

```bash
#!/bin/bash

LIB_DRM=/opt/libdrm-2.4.114
MESA_LIB=/opt/mesa-22.1
export LIBGL_DRIVERS_PATH=$MESA_LIB/x86_64
export EGL_DRIVERS_PATH=$LIBGL_DRIVERS_PATH
export LD_LIBRARY_PATH=$LIB_DRM/x86_64:$LIBGL_DRIVERS_PATH:$LD_LIBRARY_PATH
export VK_ICD_FILENAMES=$MESA_LIB/share/vulkan/icd.d/intel_icd.x86_64.json

# Print some info about rdivers
glxinfo | grep string
vulkaninfo | grep Version
vulkaninfo | grep driver

# Path to your executable
vkcube
```

# 

# 
