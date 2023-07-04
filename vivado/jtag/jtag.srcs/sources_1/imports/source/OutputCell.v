`timescale 1ns/1ps

module OutputCell( 
	input  i_FromCore,
	input  i_FromPreviousBSCell,
	input  i_CaptureDR,
	input  i_ShiftDR,
	input  i_UpdateDR,
	input  i_extest,
	input  i_TCK,
	output o_ToNextBSCell,
	output o_Pin
);

    reg CaptReg;
    reg ShiftedControl;
    
    reg ToNextBSCell;
    
    always @ (posedge i_TCK)
        if(i_CaptureDR | i_ShiftDR) 
            CaptReg <= i_CaptureDR? i_FromCore : i_FromPreviousBSCell;
   
    always @ (posedge i_TCK)
        if(i_UpdateDR) ShiftedControl<=ToNextBSCell;
    
    assign o_ToNextBSCell = CaptReg;
    assign o_Pin = i_extest? ShiftedControl : i_FromCore;

endmodule