CROSS_FLAGS = ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

all: recovery-pinephone.img.xz recovery-pinetab.img.xz

recovery-pinephone.img: initramfs-pine64-pinephone.gz kernel-sunxi.gz dtbs/sunxi/sun50i-a64-pinephone.dtb
	@echo "MKFS  $@"
	@rm -f $@
	@truncate --size 40M $@
	@mkfs.ext4 $@
	@mkdir mnt
	@sudo mount $@ mnt

	@sudo cp kernel-sunxi.gz mnt/vmlinuz
	@sudo cp dtbs/sunxi/sun50i-a64-pinephone.dtb mnt/dtb
	@sudo cp initramfs-pine64-pinephone.gz mnt/initrd.img

	@sudo umount $@
	@rm -r mnt

recovery-pinetab.img: initramfs-pine64-pinetab.gz kernel-sunxi.gz dtbs/sunxi/sun50i-a64-pinetab.dtb
	@echo "MKFS  $@"
	@rm -f $@
	@truncate --size 40M $@
	@mkfs.ext4 $@
	@mkdir mnt
	@sudo mount $@

	@cp kernel-sunxi.gz mnt/vmlinuz
	@cp dtbs/sunxi/sun50i-a64-pinetab.dtb mnt/dtb
	@cp initramfs-pine64-pinetab.gz mnt/initrd.img

	@sudo umount $@
	@rm -r mnt

%.img.xz: %.img
	@echo "XZ    $@"
	@xz -c $< > $@

initramfs/bin/e2fsprogs: src/e2fsprogs/e2fsck
	@echo "MAKE  $@"
	(cd src/e2fsprogs && ./configure CFLAGS='-g -O2 -static' CC=aarch64-linux-gnu-gcc  --host=aarch64-linux-gnu)
	@$(MAKE) -C src/e2fsprogs/e2fsck e2fsck.static
	@$(MAKE) -C src/e2fsprogs/misc mke2fs.static tune2fs.static
	@cp src/e2fsprogs/e2fsck/e2fsck.static initramfs/bin/e2fsck
	@cp src/e2fsprogs/misc/mke2fs.static initramfs/bin/mke2fs
	@cp src/e2fsprogs/misc/tune2fs.static initramfs/bin/tune2fs

initramfs/bin/busybox: src/busybox src/busybox_config
	@echo "MAKE  $@"
	@mkdir -p build/busybox
	@cp src/busybox_config build/busybox/.config
	@$(MAKE) -C src/busybox O=../../build/busybox $(CROSS_FLAGS)
	@cp build/busybox/busybox initramfs/bin/busybox

splash/%.ppm.gz: splash/%.ppm
	@echo "GZ    $@"
	@gzip < $< > $@

initramfs-%.cpio: initramfs/bin/busybox initramfs/bin/e2fsprogs initramfs/init initramfs/system-image-upgrader initramfs/init_functions.sh splash/%.ppm.gz splash/%-error.ppm.gz
	@echo "CPIO  $@"
	@rm -rf initramfs-$*
	@cp -r initramfs initramfs-$*
	@cp src/info-$*.sh initramfs-$*/info.sh
	@cp splash/$*.ppm.gz initramfs-$*/splash.ppm.gz
	@cp splash/$*-error.ppm.gz initramfs-$*/error.ppm.gz
	@cp src/info-$*.sh initramfs-$*/info.sh
	@cd initramfs-$*; find . | cpio -H newc -o > ../$@

initramfs-%.gz: initramfs-%.cpio
	@echo "GZ    $@"
	@gzip < $< > $@

kernel-sunxi.gz: src/linux_config
	@echo "MAKE  $@"
	@mkdir -p build/linux-sunxi
	@mkdir -p dtbs/sunxi
	@cp src/linux_config build/linux-sunxi/.config
	@$(MAKE) -C src/linux O=../../build/linux-sunxi $(CROSS_FLAGS) olddefconfig
	@$(MAKE) -C src/linux O=../../build/linux-sunxi $(CROSS_FLAGS)
	@cp build/linux-sunxi/arch/arm64/boot/Image.gz $@
	@cp build/linux-sunxi/arch/arm64/boot/dts/allwinner/*.dtb dtbs/sunxi/

.PHONY: clean cleanfast

cleanfast:
	@rm -rvf build
	@rm -vf *.img
	@rm -vf *.img.xz
	@rm -vf *.apk
	@rm -vf *.bin
	@rm -vf *.cpio
	@rm -vf *.gz
	@rm -vf *.scr
	@rm -vf splash/*.gz

clean: cleanfast
	@rm -vf kernel*.gz
	@rm -vf initramfs/bin/busybox
	@rm -vrf dtbs
