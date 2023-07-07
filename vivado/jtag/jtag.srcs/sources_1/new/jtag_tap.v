`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/05/2023 10:04:05 PM
// Design Name: 
// Module Name: jtag_tap
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


module jtag_tap(
    // JTAG pins
    input   i_tms,      // JTAG test mode select pad
    input   i_tck,      // JTAG test clock pad
    input   i_trstn,     // JTAG test reset pad
    input   i_tdi,     // JTAG test data input pad
    output  o_tdo,      // JTAG test data output pad
    output  o_tdoEnable    // Output enable for JTAG test data output pad 
);

    /**********************************************************************************
    *                                                                                 *
    *   TAP State Machine:                                                            *
    *                                                                                 *
    **********************************************************************************/
    parameter STATE_test_logic_reset = 4'hF; // 4'b1111
    parameter STATE_run_test_idle    = 4'hC; // 4'b1100
    // dr state
    parameter STATE_select_dr_scan   = 4'h7; // 4'b0111
    parameter STATE_capture_dr       = 4'h6; // 4'b0110
    parameter STATE_shift_dr         = 4'h2; // 4'b0010
    parameter STATE_exit1_dr         = 4'h1; // 4'b0001
    parameter STATE_pause_dr         = 4'h3; // 4'b0011
    parameter STATE_exit2_dr         = 4'h0; // 4'b0000
    parameter STATE_update_dr        = 4'h5; // 4'b0101
    // ir state
    parameter STATE_select_ir_scan   = 4'h4; // 4'b0100
    parameter STATE_capture_ir       = 4'hE; // 4'b1110
    parameter STATE_shift_ir         = 4'hA; // 4'b1010
    parameter STATE_exit1_ir         = 4'h9; // 4'b1001
    parameter STATE_pause_ir         = 4'hB; // 4'b1011
    parameter STATE_exit2_ir         = 4'h8; // 4'b1000
    parameter STATE_update_ir        = 4'hD; // 4'b1101

    reg [3:0]state, next;
    
    always @(posedge )

endmodule
