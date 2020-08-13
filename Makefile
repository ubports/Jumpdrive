CROSS_FLAGS = ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

all: recovery-pinephone.img.xz recovery-pinetab.img.xz

recovery-pinephone.img: initramfs-pine64-pinephone.gz kernel-sunxi.gz dtbs/sunxi/sun50i-a64-pinephone-1.1.dtb
	@echo "MKFS  $@"
	@rm -f $@
	-sudo umount -f mnt-$@
	-sudo rmdir mnt-$@
	@truncate --size 40M $@
	@mkfs.ext4 $@
	@mkdir mnt-$@
	-sudo mknod -m 0660 "/tmp/recovery-pinephone-loop0" b 7 101
	-sudo losetup -d /tmp/recovery-pinephone-loop0
	@sudo losetup /tmp/recovery-pinephone-loop0 $@
	@sudo mount /tmp/recovery-pinephone-loop0 mnt-$@

	@sudo cp kernel-sunxi.gz mnt-$@/vmlinuz
	@sudo cp dtbs/sunxi/sun50i-a64-pinephone-1.1.dtb mnt-$@/dtb
	@sudo cp initramfs-pine64-pinephone.gz mnt-$@/initrd.img

	@sudo umount -f mnt-$@
	@sudo losetup -d /tmp/recovery-pinephone-loop0
	@sudo rm -f /tmp/recovery-pinephone-loop0
	@sudo rmdir mnt-$@

recovery-pinetab.img: initramfs-pine64-pinetab.gz kernel-sunxi.gz dtbs/sunxi/sun50i-a64-pinetab.dtb
	@echo "MKFS  $@"
	@rm -f $@
	-sudo umount -f mnt-$@
	-sudo rmdir mnt-$@
	@truncate --size 40M $@
	@mkfs.ext4 $@
	@mkdir mnt-$@
	-sudo mknod -m 0660 "/tmp/recovery-pinetab-loop0" b 7 105
	-sudo losetup -d /tmp/recovery-pinetab-loop0
	@sudo losetup /tmp/recovery-pinetab-loop0 $@
	@sudo mount /tmp/recovery-pinetab-loop0 mnt-$@

	@sudo cp kernel-sunxi.gz mnt-$@/vmlinuz
	@sudo cp dtbs/sunxi/sun50i-a64-pinetab.dtb mnt-$@/dtb
	@sudo cp initramfs-pine64-pinetab.gz mnt-$@/initrd.img

	@sudo umount -f mnt-$@
	@sudo losetup -d /tmp/recovery-pinetab-loop0
	@sudo rm -f /tmp/recovery-pinetab-loop0
	@sudo rmdir mnt-$@

%.img.xz: %.img
	@echo "XZ    $@"
	@xz -c $< > $@

initramfs/bin/e2fsprogs: src/e2fsprogs/e2fsck
	@echo "MAKE  $@"
	(cd src/e2fsprogs && ./configure CFLAGS='-g -O2 -static' LDFLAGS="-static" CC=aarch64-linux-gnu-gcc  --host=aarch64-linux-gnu)
	@$(MAKE) -C src/e2fsprogs
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

dtbs/sunxi/%.dtb: kernel-sunxi.gz
	@mkdir -p dtbs/sunxi
	@cp build/linux-sunxi/arch/arm64/boot/dts/allwinner/$(@F) $@

splash/%.ppm: splash/%.svg
	@echo "CONVERT	$@"
	@convert $< PPM:$@

splash/%.ppm.gz: splash/%.ppm
	@echo "GZ    $@"
	@gzip < $< > $@

initramfs-%.cpio: initramfs/bin/busybox initramfs/bin/e2fsprogs initramfs/init initramfs/system-image-upgrader initramfs/init_functions.sh splash/%-waiting.ppm.gz splash/%-update.ppm.gz splash/%-error.ppm.gz
	@echo "CPIO  $@"
	@rm -rf initramfs-$*
	@cp -r initramfs initramfs-$*
	@cp src/info-$*.sh initramfs-$*/info.sh
	@cp splash/$*-waiting.ppm.gz initramfs-$*/waiting.ppm.gz
	@cp splash/$*-update.ppm.gz initramfs-$*/update.ppm.gz
	@cp splash/$*-error.ppm.gz initramfs-$*/error.ppm.gz
	@cp splash/$*.conf initramfs-$*/etc/splash.conf
	@cp src/info-$*.sh initramfs-$*/info.sh
	@cd initramfs-$*; find . | cpio -H newc -o > ../$@

initramfs-%.gz: initramfs-%.cpio
	@echo "GZ    $@"
	@gzip < $< > $@

kernel-sunxi.gz: src/linux_config
	@echo "MAKE  $@"
	@mkdir -p build/linux-sunxi
	@cp src/linux_config build/linux-sunxi/.config
	@$(MAKE) -C src/linux O=../../build/linux-sunxi $(CROSS_FLAGS) olddefconfig
	@$(MAKE) -C src/linux O=../../build/linux-sunxi $(CROSS_FLAGS)
	@cp build/linux-sunxi/arch/arm64/boot/Image.gz $@

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
	@rm -vf splash/*.ppm
	@rm -vf splash/*.gz

clean: cleanfast
	@rm -vf kernel*.gz
	@rm -vf initramfs/bin/busybox
	@rm -vrf dtbs
	-sudo umount -f mnt-recovery-pinephone.img
	-sudo umount -f mnt-recovery-pinetab.img
	-sudo losetup -d /tmp/recovery-pinephone-loop0
	-sudo losetup -d /tmp/recovery-pinetab-loop0
	@sudo rm -f /tmp/recovery-pinephone-loop0
	@sudo rm -f /tmp/recovery-pinetab-loop0
	@sudo rm -rf mnt-recovery-pinephone.img
	@sudo rm -rf mnt-recovery-pinetab.img
