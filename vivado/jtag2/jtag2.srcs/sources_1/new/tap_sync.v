`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/08/2023 02:57:40 PM
// Design Name: 
// Module Name: tap_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tap_sync(
    // Global control
    input i_clk,
    input i_rstn,
    // TAP
    input i_trst,
    input i_tck,
    input i_tms,
    input i_tdi,
    // Sync port
    output o_sync_trst,
    output o_sync_tck_raising,
    output o_sync_tck_failling,
    output o_sync_tms,
    output o_sync_tdi   
);

    reg [2:0] r_sync_trst;
    reg [2:0] r_sync_tck;
    reg [2:0] r_sync_tms;
    reg [2:0] r_sync_tdi;
    
    always @(posedge i_clk)
        if (!i_rstn)
        begin
            r_sync_trst <= 3'b000;
            r_sync_tck  <= 3'b000;
            r_sync_tms  <= 3'b000;
            r_sync_tdi  <= 3'b000;
        end
        else
        begin
            r_sync_trst <= {r_sync_trst[1:0], i_trst};
            r_sync_tck  <= {r_sync_tck[1:0], i_tck};
            r_sync_tms  <= {r_sync_tms[1:0], i_tms};
            r_sync_tdi  <= {r_sync_tdi[1:0], i_tdi};
        end

    assign o_sync_trst = |r_sync_trst[2:1];
    assign o_sync_tck_raising = r_sync_tck[2:1] == 2'b01;
    assign o_sync_tck_failling = r_sync_tck[2:1] == 2'b10;
    assign o_sync_tms = r_sync_tms[2];
    assign o_sync_tdi = r_sync_tdi[2];
    
endmodule
