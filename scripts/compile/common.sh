#!/bin/bash -e

# functions
fix_zero_value_flag() {
  flag=$1
  var="ENABLE_$flag"
  if [[ ${!var} == 0 ]]; then unset "$var"; fi
}

process_switch_options() {
  flag=$1
  var="ENABLE_$flag"
  if [[ ${!var} ]]; then
    suffix="ON"
  else
    suffix="OFF"
  fi
  var2="SWITCH_COMMON_CFLAGS_${flag}_${suffix}"
  readonly "SWITCH_COMMON_CFLAGS_${flag}"="${!var2}"
  var2="SWITCH_BUILD_WEBKIT_OPTIONS_${flag}_${suffix}"
  readonly "SWITCH_BUILD_WEBKIT_OPTIONS_${flag}"="${!var2}"
  var2="SWITCH_BUILD_WEBKIT_CMAKE_ARGS_${flag}_${suffix}"
  readonly "SWITCH_BUILD_WEBKIT_CMAKE_ARGS_${flag}"="${!var2}"
  var2="SWITCH_JSC_CFLAGS_${flag}_${suffix}"
  readonly "SWITCH_JSC_CFLAGS_${flag}"="${!var2}"
}

if ! [[ $ROOTDIR ]]; then ROOTDIR=`pwd`; fi
ARCH=$JSC_ARCH

TARGETDIR=$ROOTDIR/build/target

# platform specific settings
CROSS_COMPILE_PLATFORM_arm="arm-linux-androideabi"
CROSS_COMPILE_PLATFORM_arm64="aarch64-linux-android"
CROSS_COMPILE_PLATFORM_x86="i686-linux-android"
CROSS_COMPILE_PLATFORM_x86_64="x86_64-linux-android"
CROSS_COMPILE_PLATFORM_CC_arm="armv7a-linux-androideabi"
CROSS_COMPILE_PLATFORM_CC_arm64="$CROSS_COMPILE_PLATFORM_arm64"
CROSS_COMPILE_PLATFORM_CC_x86="$CROSS_COMPILE_PLATFORM_x86"
CROSS_COMPILE_PLATFORM_CC_x86_64="$CROSS_COMPILE_PLATFORM_x86_64"

# arch
var="CROSS_COMPILE_PLATFORM_$JSC_ARCH"
CROSS_COMPILE_PLATFORM=${!var}
var="CROSS_COMPILE_PLATFORM_CC_$JSC_ARCH"
CROSS_COMPILE_PLATFORM_CC=${!var}${ANDROID_API}
TOOLCHAIN_PLATFORM=$(ls -1 $ANDROID_NDK/toolchains/llvm/prebuilt | head -1)
TOOLCHAIN_DIR="$ANDROID_NDK/toolchains/llvm/prebuilt/$TOOLCHAIN_PLATFORM/"

# settings
PLATFORM_CFLAGS_arm=" \
-march=armv7-a \
-mfloat-abi=softfp \
-mfpu=neon \
-mthumb \
"
PLATFORM_LDFLAGS_arm=" \
-march=armv7-a \
-Wl,--fix-cortex-a8 \
"
JNI_ARCH_arm=armeabi-v7a

PLATFORM_LDFLAGS_arm64=""
JNI_ARCH_arm64=arm64-v8a

PLATFORM_CFLAGS_x86=" \
-march=i686 \
-mtune=intel \
-mssse3 \
-mfpmath=sse \
-m32 \
"
PLATFORM_LDFLAGS_x86=""
JNI_ARCH_x86=x86

PLATFORM_CFLAGS_x86_64=" \
-march=x86-64 \
-msse4.2 \
-mpopcnt \
-m64 \
-mtune=intel \
"
PLATFORM_LDFLAGS_x86_64=""
JNI_ARCH_x86_64=x86_64

# arch
var="PLATFORM_CFLAGS_$JSC_ARCH"
PLATFORM_CFLAGS=${!var}
var="PLATFORM_LDFLAGS_$JSC_ARCH"
PLATFORM_LDFLAGS=${!var}
var="JNI_ARCH_$JSC_ARCH"
JNI_ARCH=${!var}

# options flags
# INTL
SWITCH_COMMON_CFLAGS_INTL_OFF="-DUCONFIG_NO_COLLATION=1 -DUCONFIG_NO_FORMATTING=1"
SWITCH_BUILD_WEBKIT_OPTIONS_INTL_OFF="--no-intl"
SWITCH_BUILD_WEBKIT_OPTIONS_INTL_ON="--intl"

# switches
fix_zero_value_flag "INTL"
process_switch_options "INTL"

# checks
err=false
if ! [[ $ANDROID_API_FOR_ABI_32 ]]; then echo "set ANDROID_API_FOR_ABI_32 to the minimum supported Android platform version for arm and x86 (e.g. 16)"; err=true; fi
if ! [[ $ANDROID_API_FOR_ABI_64 ]]; then echo "set ANDROID_API_FOR_ABI_64 to the minimum supported Android platform version for arm64 and x86_64 (e.g. 21)"; err=true; fi
if ! [[ $FLAVOR ]]; then echo "set FLAVOR to the name of the flavor"; err=true; fi
if ! [[ $CROSS_COMPILE_PLATFORM ]]; then echo "set JSC_ARCH to one of {arm,arm64,x86,x86_64}"; err=true; fi
if ! [[ $ANDROID_HOME ]]; then echo "set ANDROID_HOME to android sdk dir"; err=true; fi
if ! [[ $ANDROID_NDK ]]; then echo "set ANDROID_NDK to android ndk dir"; err=true; fi

if [[ $err = true ]]; then exit 1; fi

####

COMMON_LDFLAGS=" \
-fuse-ld=gold \
-Wl,--icf=safe \
-Wl,-z,noexecstack \
-Wl,--gc-sections \
-Wl,--exclude-libs,libgcc.a \
-Wl,--exclude-libs,libunwind.a \
-Wl,--no-undefined \
"

COMMON_CFLAGS=" \
-fstack-protector \
-ffunction-sections \
-fomit-frame-pointer \
-fno-strict-aliasing \
-fexceptions \
-frtti \
-funwind-tables \
-DPIC \
-fPIC \
-fvisibility=hidden \
-DNDEBUG \
-DCUSTOMIZE_REACT_NATIVE \
$SWITCH_COMMON_CFLAGS_INTL \
"

COMMON_CXXFLAGS=" \
--std=c++11 \
"

ICU_CFLAGS="$COMMON_CFLAGS $PLATFORM_CFLAGS -Oz"
ICU_CXXFLAGS="$COMMON_CXXFLAGS $ICU_CFLAGS -Oz"
ICU_LDFLAGS="$COMMON_LDFLAGS $PLATFORM_LDFLAGS -s"

JSC_LDFLAGS="$COMMON_LDFLAGS"
JSC_CFLAGS="$COMMON_CFLAGS -DU_STATIC_IMPLEMENTATION=1 -DU_SHOW_CPLUSPLUS_API=0"

INSTALL_DIR=$ROOTDIR/build/compiled/$JNI_ARCH
mkdir -p $INSTALL_DIR
