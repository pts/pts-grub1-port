# pts-grub1-port: a reproducible source port of GRUB 0.97-29ubuntu68 (GRUB Legacy)

pts-grub1-port a port of GRUB 0.97--29ubuntu68 (GRUB Legacy) *stage1* and
*stage2* files to GCC 4.8.5, providing a reproducible build on Linux i386
and amd64.

To build pts-grub1-port, clone the Git repository, and run `./compile.sh`
(or `tools/busybox sh compile.sh`) on a Linux i386 or Linux amd64 system.
(Emulations, containers and WSL are also fine.) The output files are
*stage1/stage1* and *stage2/stage2*.

User-visible changes to GRUB 0.97-29ubuntu68:

* GRUB can see filesystems at the beginning of a HDD (without a partition).
* The commands *kernel --type=linux* and *kernel --type=biglinux* make GRUB
  recognize the image file as a Linux kernel rather than Multiboot if both
  headers are present.
* The commands *kernel --type=freebsd* and *kernel --type=biglinux* make
  GRUB recognize the image file as a FreeBSD a.out kernel or NetBSD a.out
  kernel rather than Multiboot if both a.out and Multiboot headers are
  present.
* GRUB (just like GRUB4DOS 0.4.4) can boot *chainloader* files longer than
  512 bytes; the limit is now 585 KiB.
* When booting in Linux mode (e.g. with *kernel --type=linux*), GRUB
  recognizes the [UKH](https://github.com/pts/ukh) header, and passes the
  boot device, boot partition number and boot hidden sector count (partition
  offset (LBA)). Prevously, none of these were passed in Linux mode. Please
  note that real Linux kernels are not affected, because they don't have the
  UKH header.
* Constently for booting Multiboot, Linux and *chainloader*, GRUB sets the
  boot device (BIOS boot drive number) and the boot partition passed to the
  kernel to currently active *root* device and partition (either by default,
  or set byte most recent *root* or *uuid* command). (Please note that the
  boot partition is still not passed for *chainloader*.) This matches what
  *boot* of *chainloader* has been doing.
* The menu is wider and taller on the 80x25 screen, similar to GRUB4DOS 0.4.4.
* Quiet mode is disabled by default (to match GRUB4DOS 0.4.4).
* The *quiet* command enables quiet boot mode. (Bugs fixed.)
* Bugfixes.

The goals of pts-grub1-port:

* (achieved) reproducible build: all tools are included (and statically
  linked) to rerun the build reproducible on Linux i386 and amd64 systems
* (achieved) fixing all GCC 4.8.5 warnings
* (achieved) fixing some bugs
* (achieved) adding small convenience features
* (achieved) optimizing *stage2* for size: reducing it from ~134 KiB to ~97 KiB
* creating a UPX-LZMA-compressed *stage2*: the goal is ~52 KiB

pts-grub1-port is based on:

* The latest release of GRUB 1
  ([grub-0.97.tar.gz](https://alpha.gnu.org/gnu/grub/grub-0.97.tar.gz)) on
  2005-05-07.
* The latest release of GRUB 1 Ubuntu patches
  ([grub_0.97-29ubuntu66.diff.gz](https://archive.ubuntu.com/ubuntu/pool/main/g/grub/grub_0.97-29ubuntu66.diff.gz))
  on 2016-02-07. These patches include filesystem UUID and GPT support.
* GCC 4.8.5 (on 2015-06-23): *cc1* C compiler programs.
* GNU Binutils 2.22 and 2.24: *as* assembler and *ld* linker programs.
* Busybox 1.37: *busybox* program with many tools including *sh*, *cat* and *dd*.
* [sstrip-ml](tools/sstrip-ml-v1.c): a custom ELF-32 program file stripping
  tool. This is used instead of `objcopy -O binary`, because it's much
  smaller.
