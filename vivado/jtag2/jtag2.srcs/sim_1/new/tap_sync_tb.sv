`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/08/2023 03:11:25 PM
// Design Name: 
// Module Name: tap_sync_tb
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


module tap_sync_tb(

    );
    
    // Global control
    reg i_clk = 1'b0;
    reg i_rstn = 1'b0;
    // TAP
    reg i_trst = 1'b0;
    reg i_tck = 1'b0;
    reg i_tms = 1'b0;
    reg i_tdi = 1'b0;
    // Sync port
    wire o_sync_trst;
    wire o_sync_tck_raising;
    wire o_sync_tck_failling;
    wire o_sync_tms;
    wire o_sync_tdi;
    
    tap_sync udt(.*); 
        
    always #1 i_clk = ~i_clk;    
    
    always @(posedge i_clk) i_tck = ~i_tck;
    
    initial
    begin
        #2 i_rstn = 1'b1;
        #2 @(posedge i_tck) i_tms <= 1'b1;
        #2 @(posedge i_tck) i_tms <= 1'b0;
        #2 @(posedge i_tck) i_tdi <= 1'b1;
        #2 @(posedge i_tck) i_tdi <= 1'b0;
        #100 $stop;
    end    
      
endmodule
