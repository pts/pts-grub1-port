/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2001   Free Software Foundation, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifdef FSYS_VSTAFS

#include "shared.h"
#include "filesys.h"
#include "vstafs.h"


static void get_file_info (int sector);
static struct dir_entry *vstafs_readdir (long sector);
static struct dir_entry *vstafs_nextdir (void);


#define FIRST_SECTOR	((struct first_sector *) FSYS_BUF)
#define FILE_INFO	((struct fs_file *) (int) FIRST_SECTOR + 8192)
#define DIRECTORY_BUF	((struct dir_entry *) (int) FILE_INFO + 512)

#define ROOT_SECTOR	1

/*
 * In f_sector we store the sector number in which the information about
 * the found file is.
 */
extern int filepos;
static int f_sector;

int 
vstafs_mount (void)
{
  int retval = 1;
  
  if ((need_check_slice_type()
       && current_slice != PC_SLICE_TYPE_VSTAFS)
      ||  ! devread (0, 0, BLOCK_SIZE, (char *) FSYS_BUF)
      ||  FIRST_SECTOR->fs_magic != 0xDEADFACE)
    retval = 0;
  
  return retval;
}

static void 
get_file_info (int sector)
{
  devread (sector, 0, BLOCK_SIZE, (char *) FILE_INFO);
}

static int curr_ext, current_direntry, current_blockpos;
static struct alloc *ax;

static struct dir_entry *
vstafs_readdir (long sector)
{
  /*
   * Get some information from the current directory
   */
  get_file_info (sector);
  if (FILE_INFO->type != 2)
    {
      errnum = ERR_FILE_NOT_FOUND;
      return 0;
    }
  
  ax = FILE_INFO->blocks;
  curr_ext = 0;
  devread (ax[curr_ext].a_start, 0, 512, (char *) DIRECTORY_BUF);
  current_direntry = 11;
  current_blockpos = 0;
  
  return &DIRECTORY_BUF[10];
}

static struct dir_entry *
vstafs_nextdir (void)
{
  if (current_direntry > 15)
    {
      current_direntry = 0;
      if (IU_COMPARE(++current_blockpos, >, (unsigned)(ax[curr_ext].a_len - 1)))
	{
	  current_blockpos = 0;
	  curr_ext++;
	}
      
      if (IU_COMPARE(curr_ext, <, FILE_INFO->extents))
	{
	  devread (ax[curr_ext].a_start + current_blockpos, 0,
		   512, (char *) DIRECTORY_BUF);
	}
      else
	{
	  /* errnum =ERR_FILE_NOT_FOUND; */
	  return 0;
	}
    }
  
  return &DIRECTORY_BUF[current_direntry++];
}

int 
vstafs_dir (char *dirname)
{
  char *fn, ch;
  struct dir_entry *d;
  /* int l, i, s; */
  
  /*
   * Read in the entries of the current directory.
   */
  f_sector = ROOT_SECTOR;
  do
    {
      if (! (d = vstafs_readdir (f_sector)))
	{
	  return 0;
	}
      
      /*
       * Find the file in the path
       */
      while (*dirname == '/') dirname++;
      fn = dirname;
      while ((ch = *fn) && ch != '/' && ! isspace (ch)) fn++;
      *fn = 0;
      
      do
	{
	  if (d->name[0] == 0 || d->name[0] & 0x80)
	    continue;
	  
#ifndef STAGE1_5
	  if (print_possibilities && ch != '/'
	      && (! *dirname || strcmp (dirname, d->name) <= 0))
	    {
	      if (print_possibilities > 0)
		print_possibilities = -print_possibilities;
	      
	      printf ("  %s", d->name);
	    }
#endif
	  if (! grub_strcmp (dirname, d->name))
	    {
	      f_sector = d->start;
	      get_file_info (f_sector);
	      filemax = FILE_INFO->len; 
	      break;
	    }
	}
      while ((d =vstafs_nextdir ()));
      
      *(dirname = fn) = ch;
      if (! d)
	{
	  if (print_possibilities < 0)
	    {
	      putchar ('\n');
	      return 1;
	    }
	  
	  errnum = ERR_FILE_NOT_FOUND;
	  return 0;
	}
    }
  while (*dirname && ! isspace (ch));
  
  return 1;
}

int 
vstafs_read (char *addr, int len)
{
  struct alloc *a;
  int size, ret = 0, offset, curr_len = 0;
  int extent_ext;
  char extent;
  int ext_size;
  char *curr_pos;
  
  get_file_info (f_sector);
  size = FILE_INFO->len-VSTAFS_START_DATA;
  a = FILE_INFO->blocks;
  
  if (filepos > 0)
    {
      if (IU_COMPARE(filepos, <, (unsigned)(a[0].a_len * 512 - VSTAFS_START_DATA)))
	{
	  offset = filepos + VSTAFS_START_DATA;
	  extent = 0;
	  curr_len = a[0].a_len * 512 - offset - filepos; 
	}
      else
	{
	  ext_size = a[0].a_len * 512 - VSTAFS_START_DATA;
	  offset = filepos - ext_size;
	  extent = 1;
	  do
	    {
	      curr_len -= ext_size;
	      offset -= ext_size;
	      ext_size = a[extent+1].a_len * 512;
	    }
	  while (1U  /* extent */ < FILE_INFO->extents &&
	         offset > ext_size);
	}
    }
  else
    {
      offset = VSTAFS_START_DATA;
      extent = 0;
      curr_len = a[0].a_len * 512 - offset;
    }
  
  curr_pos = addr;
  if (curr_len > len)
    curr_len = len;
  
  for (extent_ext=extent;
       IU_COMPARE(extent_ext, <, (unsigned)FILE_INFO->extents);
       curr_len = a[extent_ext].a_len * 512, curr_pos += curr_len, extent_ext++)
    {
      ret += curr_len;
      size -= curr_len;
      if (size < 0)
	{
	  ret += size;
	  curr_len += size;
	}
      
      devread (a[extent_ext].a_start,offset, curr_len, curr_pos);
      offset = 0;
    }
  
  return ret;
}

#endif /* FSYS_VSTAFS */
