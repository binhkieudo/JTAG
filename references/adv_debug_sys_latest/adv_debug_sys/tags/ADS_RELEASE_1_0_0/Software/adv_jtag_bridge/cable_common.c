/* cable_common.c -- Interface to the low-level cable drivers
   Copyright (C) 2001 Marko Mlinar, markom@opencores.org
   Copyright (C) 2004 Gy�rgy Jeney, nog@sdf.lonestar.org
   Copyright (C) 2008 Nathan Yawn, nathan.yawn@opencores.org
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */



#include <stdio.h>
#include <string.h>


#include "cable_common.h"
#include "cable_parallel.h"
#include "cable_sim.h"
#include "cable_usbblaster.h"
#include "cable_xpc_dlc9.h"
#include "errcodes.h"

#define debug(...)   //fprintf(stderr, __VA_ARGS__ )

static struct jtag_cable {  // 'static' keyword hides this from other files
  const char *name;
  int (*inout_func)(uint8_t, uint8_t *);
  int (*out_func)(uint8_t);
  int (*init_func)();
  void (*wait_func)();
  int (*opt_func)(int, char *);
  int (*bit_out_func)(uint8_t);
  int (*bit_inout_func)(uint8_t, uint8_t *);
  int (*stream_out_func)(uint32_t *, int, int);
  int (*stream_inout_func)(uint32_t *, uint32_t *, int, int);
  const char *opts;
  const char *help;
} jtag_cables[] = {
  { "rtl_sim", 
    cable_rtl_sim_inout, 
    cable_rtl_sim_out, 
    cable_rtl_sim_init, 
    NULL, 
    cable_rtl_sim_opt,
    cable_common_write_bit,
    cable_common_read_write_bit,
    cable_common_write_stream, 
    cable_common_read_stream,
    "d:",
    "-d [directory] Directory in which gdb_in.dat/gdb_out.dat may be found\n" },
  { "vpi", 
    cable_vpi_inout, 
    cable_vpi_out, 
    cable_vpi_init, 
    cable_vpi_wait, 
    cable_vpi_opt,
    cable_common_write_bit,
    cable_common_read_write_bit,
    cable_common_write_stream, 
    cable_common_read_stream,
    "s:p:",
    "-p [port] Port number that the VPI module is listening on\n\t-s [server] Server that the VPI module is running on\n" },
  { "xpc3", 
    cable_xpc3_inout, 
    cable_xpc3_out, 
    cable_parallel_init, 
    cable_parallel_phys_wait, 
    cable_parallel_opt,
    cable_common_write_bit,
    cable_common_read_write_bit,
    cable_common_write_stream, 
    cable_common_read_stream, 
    "p:",
    "-p [port] Which port to use when communicating with the parport hardware (eg. 0x378)\n" },
  { "xess", 
    cable_xess_inout, 
    cable_xess_out, 
    cable_parallel_init, 
    cable_parallel_phys_wait, 
    cable_parallel_opt,
    cable_common_write_bit,
    cable_common_read_write_bit,
    cable_common_write_stream, 
    cable_common_read_stream, 
    "p:",
    "-p [port] Which port to use when communicating with the parport hardware (eg. 0x378)\n" },
  { "usbblaster", 
    cable_usbblaster_inout, 
    cable_usbblaster_out, 
    cable_usbblaster_init, 
    NULL, 
    cable_usbblaster_opt,
    cable_common_write_bit,
    cable_common_read_write_bit,
    cable_usbblaster_write_stream, 
    cable_usbblaster_read_stream,
    "",
    "no options\n" },
  { "xpc_usb", 
    cable_xpcusb_inout, 
    cable_xpcusb_out, 
    cable_xpcusb_init, 
    NULL, 
    cable_xpcusb_opt,
    cable_common_write_bit,
    cable_xpcusb_read_write_bit,
    cable_common_write_stream, 
    cable_common_read_stream, 
    "",
    "no options\n" },
  { NULL, NULL, NULL, NULL } };

static struct jtag_cable *jtag_cable_in_use = NULL; /* The currently selected cable */


/////////////////////////////////////////////////////////////////////////////////////
// Cable subsystem / init functions


/* Selects a cable for use */
int cable_select(const char *cable)
{
  int i;

  for(i = 0; jtag_cables[i].name; i++) {
    if(!strcmp(cable, jtag_cables[i].name)) {
      jtag_cable_in_use = &jtag_cables[i];
      return APP_ERR_NONE;
    }
  }

  return APP_ERR_CABLE_INVALID;
}

/* Calls the init function of the cable 
 */
int cable_init()
{
  return jtag_cable_in_use->init_func();
}

/* Parses command-line options specific to the selected cable */
int cable_parse_opt(int c, char *str)
{
  return jtag_cable_in_use->opt_func(c, str);
}

const char *cable_get_args()
{
  if(jtag_cable_in_use != NULL)
    return jtag_cable_in_use->opts;
  else
    return NULL;
}

/* Prints a (short) useage message for each available cable */
void cable_print_help()
{
  int i;
  printf("Available cables: ");

  for(i = 0; jtag_cables[i].name; i++) {
    if(i)
      printf(", ");
    printf(jtag_cables[i].name);
  }

  printf("\n\nOptions availible for the cables:\n");
  for(i = 0; jtag_cables[i].name; i++) {
    if(!jtag_cables[i].help)
      continue;
    printf("  %s:\n    %s", jtag_cables[i].name, jtag_cables[i].help);
  }
}


/////////////////////////////////////////////////////////////////////////////////
// Cable API Functions

int cable_write_stream(uint32_t *stream, int len_bits, int set_last_bit) {
  return jtag_cable_in_use->stream_out_func(stream, len_bits, set_last_bit);
}

int cable_read_write_stream(uint32_t *outstream, uint32_t *instream, int len_bits, int set_last_bit) {
  return jtag_cable_in_use->stream_inout_func(outstream, instream, len_bits, set_last_bit);
}

int cable_write_bit(uint8_t packet) {
  return jtag_cable_in_use->bit_out_func(packet);
}

int cable_read_write_bit(uint8_t packet_out, uint8_t *bit_in) {
  return jtag_cable_in_use->bit_inout_func(packet_out, bit_in);
}


/////////////////////////////////////////////////////////////////////////////////////
// Common functions which may or may not be used by individual drivers


/* Note that these make no assumption as to the starting state of the clock,
 * and they leave the clock HIGH.  But, these need to interface with other routines (like
 * the byte-shift mode in the USB-Blaster), which begin by assuming that a new
 * data bit is available at TDO, which only happens after a FALLING edge of TCK.
 * So, routines which assume new data is available will need to start by dropping
 * the clock.
 */
int cable_common_write_bit(uint8_t packet) {
  uint8_t data = TRST_BIT;  // TRST is active low, don't clear unless /set/ in 'packet'
  int err = APP_ERR_NONE;

  /* Write data, drop clock */
  if(packet & TDO) data |= TDI_BIT;
  if(packet & TMS) data |= TMS_BIT;
  if(packet & TRST) data &= ~TRST_BIT;

  err |= jtag_cable_in_use->out_func(data);
  if (jtag_cable_in_use->wait_func != NULL) jtag_cable_in_use->wait_func();

  /* raise clock, to do write */
  err |= jtag_cable_in_use->out_func(data | TCLK_BIT);
   if (jtag_cable_in_use->wait_func != NULL) jtag_cable_in_use->wait_func();  

  return err;
}

int cable_common_read_write_bit(uint8_t packet_out, uint8_t *bit_in) {
  uint8_t data = TRST_BIT;  //  TRST is active low, don't clear unless /set/ in 'packet'
  int err = APP_ERR_NONE;

  /* Write data, drop clock */
  if(packet_out & TDO) data |= TDI_BIT;
  if(packet_out & TMS) data |= TMS_BIT;
  if(packet_out & TRST) data &= ~TRST_BIT;

  err |= jtag_cable_in_use->out_func(data);  // drop the clock to make data available, set the out data
  if (jtag_cable_in_use->wait_func != NULL) jtag_cable_in_use->wait_func();
  err |= jtag_cable_in_use->inout_func((data | TCLK_BIT), bit_in);  // read in bit, clock high for out bit.
  if (jtag_cable_in_use->wait_func != NULL) jtag_cable_in_use->wait_func();

  return err;
}


/* Writes bitstream via bit-bang. Can be used by any driver which does not have a high-speed transfer function.
 * Transfers LSB to MSB of stream[0], then LSB to MSB of stream[1], etc.
 */
int cable_common_write_stream(uint32_t *stream, int len_bits, int set_last_bit) {
  int i;
  int index = 0;
  int bits_this_index = 0;
  uint8_t out;
  int err = APP_ERR_NONE;

  debug("writeSrrm%d(", len_bits);
  for(i = 0; i < len_bits - 1; i++) {
    out = (stream[index] >> bits_this_index) & 1;
    err |= cable_write_bit(out);
    debug("%i", out);
    bits_this_index++;
    if(bits_this_index >= 32) {
      index++;
      bits_this_index = 0;
    }
  }
  
  out = (stream[index] >>(len_bits - 1)) & 0x1;
  if(set_last_bit) out |= TMS;
  err |= cable_write_bit(out);
  debug("%i)\n", out);
  return err;
}

/* Gets bitstream via bit-bang.  Can be used by any driver which does not have a high-speed transfer function.
 * Transfers LSB to MSB of stream[0], then LSB to MSB of stream[1], etc.
 */
int cable_common_read_stream(uint32_t *outstream, uint32_t *instream, int len_bits, int set_last_bit) {
  int i;
  int index = 0;
  int bits_this_index = 0;
  uint8_t inval, outval;
  int err = APP_ERR_NONE;

  instream[0] = 0;

  debug("readStrm%d(", len_bits);
  for(i = 0; i < (len_bits - 1); i++) {      
    outval = (outstream[index] >> bits_this_index) & 0x1;
    err |= cable_read_write_bit(outval, &inval);
    debug("%i", inval);
    instream[index] |= (inval << bits_this_index);
    bits_this_index++;
    if(bits_this_index >= 32) {
      index++;
      bits_this_index = 0;
      instream[index] = 0;  // It's safe to do this, because there's always at least one more bit
    }   
  }
  
  if (set_last_bit)
    outval = ((outstream[index] >> (len_bits - 1)) & 1) | TMS;
  else
    outval = (outstream[index] >> (len_bits - 1)) & 1; 
  
  err |= cable_read_write_bit(outval, &inval);
  debug("%i", inval);
  instream[index] |= (inval << bits_this_index);  

  debug(") = 0x%lX\n", instream[0]);
  
  return err;
}



