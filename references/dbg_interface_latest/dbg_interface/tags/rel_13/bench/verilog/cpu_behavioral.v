//////////////////////////////////////////////////////////////////////
////                                                              ////
//// cpu_behavioral.v                                             ////
////                                                              ////
////                                                              ////
////  This file is part of the SoC/OpenRISC Development Interface ////
////  http://www.opencores.org/projects/DebugInterface/           ////
////                                                              ////
////  Author(s):                                                  ////
////       Igor Mohor (igorm@opencores.org)                       ////
////                                                              ////
////                                                              ////
////  All additional information is avaliable in the README.txt   ////
////  file.                                                       ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 - 2004 Authors                            ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.1  2004/01/17 17:01:25  mohor
// Almost finished.
//
//
//
//
//
`include "timescale.v"
`include "dbg_cpu_defines.v"



module cpu_behavioral
                   (
                    // CPU signals
                    cpu_rst_i,
                    cpu_clk_o,
                    cpu_addr_i,
                    cpu_data_o,
                    cpu_data_i,
                    cpu_bp_o,
                    cpu_stall_i,
                    cpu_stall_all_i,
                    cpu_stb_i,
                    cpu_sel_i,
                    cpu_we_i,
                    cpu_ack_o,
                    cpu_rst_o
                   );


// CPU signals
input         cpu_rst_i;
output        cpu_clk_o;
input  [31:0] cpu_addr_i;
output [31:0] cpu_data_o;
input  [31:0] cpu_data_i;
output        cpu_bp_o;
input         cpu_stall_i;
input         cpu_stall_all_i;
input         cpu_stb_i;
input [`CPU_NUM -1:0]  cpu_sel_i;
input         cpu_we_i;
output        cpu_ack_o;
output        cpu_rst_o;

reg           cpu_clk_o;
reg    [31:0] cpu_data_o;

initial
begin
  cpu_clk_o = 1'b0;
  forever #5 cpu_clk_o = ~cpu_clk_o;
end


assign cpu_bp_o = 1'b0;

assign #200 cpu_ack_o = cpu_stall_i & cpu_stb_i;



always @ (posedge cpu_clk_o or posedge cpu_rst_i)
begin
  if (cpu_rst_i)
    cpu_data_o <= #1 32'h11111111;
  else if ((cpu_addr_i == 32'h32323232) & cpu_we_i & cpu_ack_o)
    cpu_data_o <= #1 cpu_data_i + 1'd1;
  else if ((cpu_addr_i == 32'h08080808) & cpu_we_i & cpu_ack_o)
    cpu_data_o <= #1 cpu_data_i + 2'd2;
end




endmodule

