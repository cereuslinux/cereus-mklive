DATECODE:=$(shell date -u "+%Y.%m.%d")
SHELL=/bin/bash

T_LIVE_ARCHS=i686 x86_64{,-musl}

T_PLATFORMS=rpi-{armv{6,7}l,aarch64}{,-musl} GCP{,-musl} pinebookpro{,-musl}
T_ARCHS=i686 x86_64{,-musl} armv{6,7}l{,-musl} aarch64{,-musl}

T_SBC_IMGS=rpi-{armv{6,7}l,aarch64}{,-musl} pinebookpro{,-musl}
T_CLOUD_IMGS=GCP{,-musl}

T_PXE_ARCHS=x86_64{,-musl}

LIVE_ARCHS:=$(shell echo $(T_LIVE_ARCHS))
LIVE_FLAVORS:=base xfce lxqt cinnamon plasma fluxbox i3wm lxde
ARCHS:=$(shell echo $(T_ARCHS))
PLATFORMS:=$(shell echo $(T_PLATFORMS))
SBC_IMGS:=$(shell echo $(T_SBC_IMGS))
CLOUD_IMGS:=$(shell echo $(T_CLOUD_IMGS))
PXE_ARCHS:=$(shell echo $(T_PXE_ARCHS))

ALL_LIVE_ISO=$(foreach arch,$(LIVE_ARCHS), $(foreach flavor,$(LIVE_FLAVORS),cereus-beta-live-$(arch)-$(flavor)-$(DATECODE).iso))
ALL_ROOTFS=$(foreach arch,$(ARCHS),cereus-beta-$(arch)-ROOTFS-$(DATECODE).tar.xz)
ALL_PLATFORMFS=$(foreach platform,$(PLATFORMS),cereus-beta-$(platform)-PLATFORMFS-$(DATECODE).tar.xz)
ALL_SBC_IMAGES=$(foreach platform,$(SBC_IMGS),cereus-beta-$(platform)-$(DATECODE).img.xz)
ALL_CLOUD_IMAGES=$(foreach cloud,$(CLOUD_IMGS),cereus-beta-$(cloud)-$(DATECODE).tar.gz)
ALL_PXE_ARCHS=$(foreach arch,$(PXE_ARCHS),cereus-beta-$(arch)-NETBOOT-$(DATECODE).tar.gz)

SUDO := sudo

REPOSITORY := https://repo-default.voidlinux.org/current
XBPS_REPOSITORY := -r $(REPOSITORY) -r $(REPOSITORY)/musl -r $(REPOSITORY)/aarch64
COMPRESSOR_THREADS:=$(shell nproc)

all:

README.md: README.md.in build-x86-images.sh mklive.sh mkrootfs.sh
	printf '<!-- DO NOT EDIT, generated by make README.md -->\n\n' > README.md
	cat README.md.in >> README.md
	for script in build-x86-images mklive mkrootfs; do \
		printf '### %s.sh\n\n```\n' "$${script}" >> README.md ; \
		"./$${script}.sh" -h 2>/dev/null >> README.md ; \
		printf '```\n\n' >> README.md ; \
	done

build-x86-images.sh: mklive.sh

checksum: distdir-$(DATECODE)
	cd distdir-$(DATECODE)/ && sha256 * > sha256sum.txt

distdir-$(DATECODE):
	mkdir -p distdir-$(DATECODE)

dist: distdir-$(DATECODE)
	mv cereus*$(DATECODE)* distdir-$(DATECODE)/

live-iso-all: $(ALL_LIVE_ISO)

live-iso-all-print:
	@echo $(ALL_LIVE_ISO) | sed "s: :\n:g"

cereus-beta-live-%.iso: build-x86-images.sh
	@[ -n "${CI}" ] && printf "::group::\x1b[32mBuilding $@...\x1b[0m\n" || true
	$(SUDO) ./build-x86-images.sh -r $(REPOSITORY) -t $*
	@[ -n "${CI}" ] && printf '::endgroup::\n' || true

rootfs-all: $(ALL_ROOTFS)

rootfs-all-print:
	@echo $(ALL_ROOTFS) | sed "s: :\n:g"

cereus-beta-%-ROOTFS-$(DATECODE).tar.xz: mkrootfs.sh
	@[ -n "${CI}" ] && printf "::group::\x1b[32mBuilding $@...\x1b[0m\n" || true
	$(SUDO) ./mkrootfs.sh $(XBPS_REPOSITORY) -x $(COMPRESSOR_THREADS) -o $@ $*
	@[ -n "${CI}" ] && printf '::endgroup::\n' || true

platformfs-all: $(ALL_PLATFORMFS)

platformfs-all-print:
	@echo $(ALL_PLATFORMFS) | sed "s: :\n:g"

.SECONDEXPANSION:
cereus-beta-%-PLATFORMFS-$(DATECODE).tar.xz: cereus-beta-$$(shell ./lib.sh platform2arch %)-ROOTFS-$(DATECODE).tar.xz mkplatformfs.sh
	@[ -n "${CI}" ] && printf "::group::\x1b[32mBuilding $@...\x1b[0m\n" || true
	$(SUDO) ./mkplatformfs.sh $(XBPS_REPOSITORY) -x $(COMPRESSOR_THREADS) -o $@ $* cereus-beta-$(shell ./lib.sh platform2arch $*)-ROOTFS-$(DATECODE).tar.xz
	@[ -n "${CI}" ] && printf '::endgroup::\n' || true

images-all: platformfs-all images-all-sbc images-all-cloud

images-all-sbc: $(ALL_SBC_IMAGES)

images-all-sbc-print:
	@echo $(ALL_SBC_IMAGES) | sed "s: :\n:g"

images-all-cloud: $(ALL_CLOUD_IMAGES)

images-all-print:
	@echo $(ALL_SBC_IMAGES) $(ALL_CLOUD_IMAGES) | sed "s: :\n:g"

cereus-beta-%-$(DATECODE).img.xz: cereus-beta-%-PLATFORMFS-$(DATECODE).tar.xz mkimage.sh
	@[ -n "${CI}" ] && printf "::group::\x1b[32mBuilding $@...\x1b[0m\n" || true
	$(SUDO) ./mkimage.sh -x $(COMPRESSOR_THREADS) -o $(basename $@) cereus-beta-$*-PLATFORMFS-$(DATECODE).tar.xz
	@[ -n "${CI}" ] && printf '::endgroup::\n' || true

# Some of the images MUST be compressed with gzip rather than xz, this
# rule services those images.
cereus-beta-%-$(DATECODE).tar.gz: cereus-beta-%-PLATFORMFS-$(DATECODE).tar.xz mkimage.sh
	@[ -n "${CI}" ] && printf "::group::\x1b[32mBuilding $@...\x1b[0m\n" || true
	$(SUDO) ./mkimage.sh -x $(COMPRESSOR_THREADS) cereus-beta-$*-PLATFORMFS-$(DATECODE).tar.xz
	@[ -n "${CI}" ] && printf '::endgroup::\n' || true

pxe-all: $(ALL_PXE_ARCHS)

pxe-all-print:
	@echo $(ALL_PXE_ARCHS) | sed "s: :\n:g"

cereus-beta-%-NETBOOT-$(DATECODE).tar.gz: cereus-beta-%-ROOTFS-$(DATECODE).tar.xz mknet.sh
	@[ -n "${CI}" ] && printf "::group::\x1b[32mBuilding $@...\x1b[0m\n" || true
	$(SUDO) ./mknet.sh cereus-beta-$*-ROOTFS-$(DATECODE).tar.xz
	@[ -n "${CI}" ] && printf '::endgroup::\n' || true

.PHONY: all checksum dist live-iso-all live-iso-all-print rootfs-all-print rootfs-all platformfs-all-print platformfs-all pxe-all-print pxe-all
