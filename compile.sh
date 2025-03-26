#! /bin/sh --
# by pts@fazekas.hu at Wed Mar 26 00:07:54 CET 2025
#
# !! fix: remaining instances of -Wsign-compare
# !! size optimization: write le64 in assembly: stage2/fsys_xfs.c
#

test "$0" = "${0%/*}" || cd "${0%/*}"
export LC_ALL=C  # For deterministic output. Typically not needed. Is it too late for Perl?
export TZ=GMT  # For deterministic output. Typically not needed. Perl respects it immediately.
if test "$1" != --sh-script; then export PATH=/dev/null/missing; exec tools/busybox sh "${0##*/}" --sh-script "$@"; exit 1; fi
shift
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

DFLAGS='-DHAVE_CONFIG_H -DSUPPORT_SERIAL=1 -DSUPPORT_HERCULES=1 -DFSYS_EXT2FS=1 -DFSYS_FAT=1 -DFSYS_FFS=1 -DFSYS_UFS2=1 -DFSYS_MINIX=1 -DFSYS_REISERFS=1 -DFSYS_VSTAFS=1 -DFSYS_JFS=1 -DFSYS_XFS=1 -DFSYS_ISO9660=1 -DUSE_MD5_PASSWORDS=1'
WFLAGS='-W -Wall -Werror-implicit-function-declaration -Wmissing-prototypes -Wunused -Wshadow -Wpointer-arith -Wundef -Wformat-security -Wno-sign-compare'
FFLAGS='-fno-pic -fno-stack-protector -fno-builtin -fno-strict-aliasing -fno-unwind-tables -fno-asynchronous-unwind-tables'  #  -fdata-sections -ffunction-sections !! ??
# Add -no-pie for newer GCCs.
LDFLAGS='-m elf_i386 -s -static -nostdlib -N'  # -Wl,--gc-sections !! ??
# -fno-reorder-functions would prevent GCC from putting some functions in
# .text.unlikely and .text.hot.
#
# -freorder-functions is the default with -Os in GCC 4.8.5. As long as the
# code in asm.S is emitted first, we are fine wither way.
OFLAGS='-m32 -march=i386 -falign-jumps=1 -falign-loops=1 -falign-functions=1 -mpreferred-stack-boundary=2 -Os'
IFLAGS='-nostdinc -I. -Istage1 -Istage2'  # For <config.h> and <stage1.h> and <shared.h> and <stdarg.h>.
PRE_STAGE2_OS='stage2/asm.o stage2/bios.o stage2/boot.o stage2/builtins.o stage2/char_io.o stage2/cmdline.o stage2/common.o stage2/console.o stage2/disk_io.o stage2/fsys_ext2fs.o stage2/fsys_fat.o stage2/fsys_ffs.o stage2/fsys_iso9660.o stage2/fsys_jfs.o stage2/fsys_minix.o stage2/fsys_reiserfs.o stage2/fsys_ufs2.o stage2/fsys_vstafs.o stage2/fsys_xfs.o stage2/gunzip.o stage2/hercules.o stage2/md5.o stage2/serial.o stage2/smp-imps.o stage2/stage2.o stage2/terminfo.o stage2/tparm.o'
SRCS='stage1/stage1.S stage2/asm.S stage2/bios.c stage2/boot.c stage2/builtins.c stage2/char_io.c stage2/cmdline.c stage2/common.c stage2/console.c stage2/disk_io.c stage2/fsys_ext2fs.c stage2/fsys_fat.c stage2/fsys_ffs.c stage2/fsys_iso9660.c stage2/fsys_jfs.c stage2/fsys_minix.c stage2/fsys_reiserfs.c stage2/fsys_ufs2.c stage2/fsys_vstafs.c stage2/fsys_xfs.c stage2/gunzip.c stage2/hercules.c stage2/md5.c stage2/serial.c stage2/smp-imps.c stage2/stage2.c stage2/terminfo.c stage2/tparm.c'
SRCS_LATE='stage2/start.S'  # Needs stage2/stage2_size.h.

Q=; V=-v; DDQ=

if test "$1" = -q; then Q=-q; DDQ=status=none; V=; shift; fi  # Quiet.

# busybox-minicc-1.21.1.upx wouldn't work, because it lacks the dd applet.

dd=dd  # BusyBox builtin applet.
as=tools/gaself32-2.24.upx
ld=tools/ld-2.22.upx
cc1=tools/cc1-4.8.5.upx
sstripml=tools/sstrip-ml-v1

cmd() {
  if test -z "$Q"; then (set -x && : "$@"); fi
  command "$@"
}

compile() {
  bf="${srcf%.*}"
  case "$srcf" in
   #*.c) "$GCC" $IFLAGS $FFLAGS $OFLAGS $DFLAGS $WFLAGS -c -o "$bf".o "$srcf" ;;
   *.c) cmd "$cc1" $IFLAGS $FFLAGS $OFLAGS $DFLAGS $WFLAGS -quiet -o "$bf".s "$srcf" ;;  # Removed: -auxbase-strip stage2/file.o -dumpbase file.c
   *.S) cmd "$cc1" $IFLAGS $FFLAGS $OFLAGS $DFLAGS $WFLAGS -E -lang-asm -fno-directives-only -quiet -o "$bf".s "$srcf" ;;
   *) echo "fatal: unknown ext: $srcf" >&2; exit 2 ;;
  esac
  "$as" $IFLAGS --32 -o "$bf".o "$bf".s
}

set -e

rm -f stage[12]/*.[opqrs] stage[12]/*.exec stage1/stage1 stage2/stage2 stage2/start stage2/pre_stage2 stage2/stage2_size.h

for srcf in $SRCS; do compile; done
cmd "$ld" $LDFLAGS -Ttext=0x7c00 -o stage1/stage1.exec stage1/stage1.o
cmd cat stage1/stage1.exec >stage1/stage1.r
cmd "$sstripml" $V stage1/stage1.r  # Strip ELF-32 section headers etc. from the end.
cmd "$dd" if=stage1/stage1.r of=stage1/stage1 skip=1 bs=512 $DDQ  # Strip the ELF-32 ehdr and phdr.
cmd "$ld" $LDFLAGS -Ttext=0x8200 -o stage2/pre_stage2.exec  $PRE_STAGE2_OS
cmd cat stage2/pre_stage2.exec >stage2/pre_stage2.r
cmd "$sstripml" $V stage2/pre_stage2.r  # Strip ELF-32 section headers etc. from the end.
cmd "$dd" if=stage2/pre_stage2.r of=stage2/pre_stage2 skip=1 bs=512 $DDQ  # Strip the ELF-32 ehdr and phdr.
rm -f stage2/stage2_size.h
set dummy $(ls -l stage2/pre_stage2)
echo "#define STAGE2_SIZE $6" >stage2/stage2_size.h
for srcf in $SRCS_LATE; do compile; done
cmd "$ld" $LDFLAGS -Ttext=0x8000 -o stage2/start.exec stage2/start.o
cmd cat stage2/start.exec >stage2/start.r
cmd "$sstripml" $V stage2/start.r  # Strip ELF-32 section headers etc. from the end.
cmd "$dd" if=stage2/start.r of=stage2/start skip=1 bs=512 $DDQ  # Strip the ELF-32 ehdr and phdr.
rm -f stage2/stage2
cmd cat stage2/start stage2/pre_stage2 >stage2/stage2

if test -z "$Q"; then
  cmd ls -ld stage1/stage1 stage2/stage2
fi

: "$0" OK.
