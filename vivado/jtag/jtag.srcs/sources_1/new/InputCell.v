`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/05/2023 10:09:08 AM
// Design Name: 
// Module Name: InputCell
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


module InputCell( 
    input  i_Pin,
    input  i_FromPreviousBSCell,
    input  i_ShiftDR,
    input  i_ShiftEnable,
    input  i_UpdateDR,
    input  i_InputEnable,
    input  i_TCK,
    output o_Pin,
    output o_ToNextBSCell
);
                
    reg r_CaptReg;      
    reg r_toSystem;
    
    wire w_SelectedCapture = i_ShiftDR? i_FromPreviousBSCell: i_Pin;
    wire w_SelectedOutput  = i_UpdateDR? i_Pin: r_CaptReg;
    
    always @ (posedge i_TCK)
        if(i_ShiftEnable) r_CaptReg <= w_SelectedCapture;
    
    always @ (posedge i_TCK)
        if (i_InputEnable) r_toSystem <= w_SelectedOutput;
    
    assign o_Pin = r_toSystem;
    assign o_ToNextBSCell = r_CaptReg;

endmodule
