GMP_VER=6.1.1
GMP_URL=https://ftp.gnu.org/gnu/gmp/gmp-$(GMP_VER).tar.bz2
GMP_TAR=gmp-$(GMP_VER).tar.bz2
GMP_DIR=gmp-$(GMP_VER)
GMP_SUM=a8109865f2893f1373b0a8ed5ff7429de8db696fc451b1036bd7bdf95bbeffd6

MPFR_VER=3.1.4
MPFR_URL=https://ftp.gnu.org/gnu/mpfr/mpfr-$(MPFR_VER).tar.bz2
MPFR_TAR=mpfr-$(MPFR_VER).tar.bz2
MPFR_DIR=mpfr-$(MPFR_VER)
MPFR_SUM=d3103a80cdad2407ed581f3618c4bed04e0c92d1cf771a65ead662cc397f7775

MPC_VER=1.0.3
MPC_URL=https://ftp.gnu.org/gnu/mpc/mpc-$(MPC_VER).tar.gz
MPC_TAR=mpc-$(MPC_VER).tar.gz
MPC_DIR=mpc-$(MPC_VER)
MPC_SUM=617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3

BINUTILS_VER=2.27
BINUTILS_URL=https://ftp.gnu.org/gnu/binutils/binutils-$(BINUTILS_VER).tar.bz2
BINUTILS_TAR=binutils-$(BINUTILS_VER).tar.bz2
BINUTILS_DIR=binutils-$(BINUTILS_VER)
BINUTILS_PATCHES=local/patches/binutils.patch local/patches/binutils-2.27_fixup.patch
BINUTILS_SUM=369737ce51587f92466041a97ab7d2358c6d9e1b6490b3940eb09fb0a9a6ac88

GCC_VER=6.2.0
GCC_URL=https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VER)/gcc-$(GCC_VER).tar.bz2
GCC_TAR=gcc-$(GCC_VER).tar.bz2
GCC_DIR=gcc-$(GCC_VER)
GCC_PATCHES=local/patches/gcc.patch
GCC_SUM=9944589fc722d3e66308c0ce5257788ebd7872982a718aa2516123940671b7c5

BASEDIR=$(shell pwd)
TOOLCHAIN_DIR=$(BASEDIR)/toolchain
TARGET=xtensa-elf
DL_DIR=$(TOOLCHAIN_DIR)/dl
BUILD_DIR=$(TOOLCHAIN_DIR)/build

all: toolchain

# 1: package name
# 2: configure arguments
# 3: make command
define Common/Compile
	mkdir -p $(BUILD_DIR)/$($(1)_DIR)
	+cd $(BUILD_DIR)/$($(1)_DIR) && \
	$(DL_DIR)/$($(1)_DIR)/configure \
		--prefix=$(TOOLCHAIN_DIR)/inst \
		$(2) && \
	$(3)
endef

define GMP/Compile
	$(call Common/Compile,GMP, \
		--disable-shared --enable-static, \
		$(MAKE) && $(MAKE) check && $(MAKE) -j1 install \
	)
endef

define MPFR/Compile
	$(call Common/Compile,MPFR, \
		--disable-shared --enable-static \
		--with-gmp=$(TOOLCHAIN_DIR)/inst, \
		$(MAKE) && $(MAKE) check && $(MAKE) -j1 install \
	)
endef

define MPC/Compile
	$(call Common/Compile,MPC, \
		--disable-shared --enable-static \
		--with-gmp=$(TOOLCHAIN_DIR)/inst \
		--with-mpfr=$(TOOLCHAIN_DIR)/inst, \
		$(MAKE) && $(MAKE) check && $(MAKE) -j1 install \
	)
endef

define BINUTILS/Compile
	$(call Common/Compile,BINUTILS, \
		--target=$(TARGET) \
		--disable-werror, \
		$(MAKE) && $(MAKE) -j1 install \
	)
endef

define GCC/Compile
	$(call Common/Compile,GCC, \
		--target=$(TARGET) \
		--enable-languages=c \
		--disable-libssp \
		--disable-shared \
		--disable-libquadmath \
		--with-gmp=$(TOOLCHAIN_DIR)/inst \
		--with-mpfr=$(TOOLCHAIN_DIR)/inst \
		--with-mpc=$(TOOLCHAIN_DIR)/inst \
		--with-newlib, \
		$(MAKE) && $(MAKE) -j1 install \
	)
endef

# 1: package name
# 2: dependencies on other packages
define Build
$(DL_DIR)/$($(1)_TAR):
	mkdir -p $(DL_DIR)
	wget -N -P $(DL_DIR) $($(1)_URL)
	printf "%s  %s\n" $($(1)_SUM) $$@ | shasum -a 256 -c

$(DL_DIR)/$($(1)_DIR)/.prepared: $(DL_DIR)/$($(1)_TAR)
	tar -C $(DL_DIR) -x$(if $(findstring bz2,$($(1)_TAR)),j,z)f $(DL_DIR)/$($(1)_TAR)
	$(if $($(1)_PATCHES), \
		cat $($(1)_PATCHES) | \
		patch -p1 -d $(DL_DIR)/$($(1)_DIR))
	touch $$@

$(1)_DEPENDS = $(foreach pkg,$(2),$(BUILD_DIR)/$($(pkg)_DIR)/.built)
$(BUILD_DIR)/$($(1)_DIR)/.built: $(DL_DIR)/$($(1)_DIR)/.prepared $$($(1)_DEPENDS)
	mkdir -p $(BUILD_DIR)/$($(1)_DIR)
	$($(1)/Compile)
	touch $$@

clean-dl-$(1):
	rm -rf $(DL_DIR)/$($(1)_DIR)

toolchain: $(BUILD_DIR)/$($(1)_DIR)/.built
clean-dl: clean-dl-$(1)
download: $(DL_DIR)/$($(1)_DIR)/.prepared

endef

all: toolchain firmware
toolchain-clean:
	rm -rf $(TOOLCHAIN_DIR)/build $(TOOLCHAIN_DIR)/inst
clean-dl:
download:
toolchain:

clean:
	$(MAKE) -C target_firmware clean

firmware: toolchain
	+$(MAKE) -C target_firmware

.PHONY: all toolchain-clean clean clean-dl download toolchain firmware

$(eval $(call Build,GMP))
$(eval $(call Build,MPFR,GMP))
$(eval $(call Build,MPC,GMP MPFR))
$(eval $(call Build,BINUTILS))
$(eval $(call Build,GCC,MPC MPFR))
