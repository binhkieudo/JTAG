`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/06/2023 11:49:06 PM
// Design Name: 
// Module Name: debug_dm
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


module debug_dm(
    // Global control
    input         i_clk,
    input         i_rstn,
    input         i_cpu_debug, // cpu in debug mode
    // Debug Module Interface (DMI)
    input         i_dmi_req_valid,
    output        o_dmi_req_ready,
    input  [5:0]  i_dmi_req_address,
    input  [1:0]  i_dmi_req_op,
    input  [31:0] i_dmi_req_data,
    output        o_dmi_rsp_valid,
    input         i_dmi_rsp_ready,
    output [31:0] o_dmi_rsp_data,
    output [1:0]  o_dmi_rsp_op,
    // Wishbone bus access
    output [31:0] o_bus_adr,
    output [31:0] o_bus_dat,
    output [3:0]  o_bus_sel,
    output 		  o_bus_we ,
    output        o_bus_cyc,
    input  [31:0] i_bus_rdt,
    input         i_bus_ack,
    // CPU control
    output o_cpu_ndmrstn,
    output o_cpu_req_halt    
);

    // DMI operations
    localparam DMI_OP_NOP     = 2'b00,
               DMI_OP_READ    = 2'b01,
               DMI_OP_WRITE   = 2'b10,
               DMI_OP_RESERVE = 2'B11;
               
    // DMI registers
    localparam DMI_ADDR_DATA0       = {2'b00, 4'b0100},
               DMI_ADDR_DMCONTROL   = {2'b01, 4'b0000},
               DMI_ADDR_DMSTATUS    = {2'b01, 4'b0001},
               DMI_ADDR_HARTINFO    = {2'b01, 4'b0010},
               DMI_ADDR_ABSTRACTS   = {2'b01, 4'b0110},
               DMI_ADDR_COMMAND     = {2'b01, 4'b0111},
               DMI_ADDR_ABSRACTAUTO = {2'b01, 4'b1000},
               DMI_ADDR_NEXTDM      = {2'b01, 4'b1101},
               DMI_ADDR_PROGBUF0    = {2'b10, 4'b0000},
               DMI_ADDR_PROGBUF1    = {2'b10, 4'b0001},
               DMI_ADDR_SBCS        = {2'b11, 4'b1000};
    
    // RISC-V Instruction           
    localparam INSTR_NOP    = 32'h00000013, // NOP
               INSTR_LW     = 32'h00002003, // lw zero, 0(zero)
               INSTR_SW     = 32'h00002023, // sw zero, 0(zero)
               INSTR_EBREAK = 32'h00100073; // ebreak
               
    // DMI access
    wire dmi_wren;
    wire dmi_rden;
    
    // Debug module DMI registers
    reg         dm_reg_dmcontrol_ndmreset;
    reg         dm_reg_dmcontrol_dmactive;
    reg         dm_reg_abstractauto_autoexecdata;
    reg [1:0]   dm_reg_abstractauto_autoexecprogbuf;
    reg [31:0]  dm_reg_progbuf0;
    reg [31:0]  dm_reg_progbuf1;    
    reg [31:0]  dm_reg_command;
    reg         dm_reg_halt_req;
    reg         dm_reg_resume_req;
    reg         dm_reg_reset_ack;
    reg         dm_reg_wr_acc_err;
    reg         dm_reg_rd_acc_err;
    reg         dm_reg_clr_acc_err;
    reg         dm_reg_autoexec_wr;
    reg         dm_reg_autoexec_rd;
    
    // CPU program buffer
    wire [31:0] cpu_progbuf0;
    wire [31:0] cpu_progbuf1;
    wire [31:0] cpu_progbuf2;
    wire [31:0] cpu_progbuf3;
    
    // DM configurations
    localparam DM_BASE = 32'hfffff800;
    localparam DM_SIZE = 32'd256; // debug ROM address space size in bytes
    localparam DM_CODE_BASE = 32'hfffff800;
    localparam DM_PBUF_BASE = 32'hfffff840;
    localparam DM_DATA_BASE = 32'hfffff880;
    localparam DM_SREG_BASE = 32'hfffff8c0;
    // park loop entry points - these need to be sync with the OCD firmware (sw/ocd-firmware/park_loop.S)
    localparam DM_EXC_ENTRY  = DM_CODE_BASE + 0;
    localparam DM_LOOP_ENTRY = DM_CODE_BASE + 8;
    localparam DM_NSCRATCH   = 4'b0001; // number of dscratch registers in CPU
    localparam DM_DATASIZE   = 4'b0001; // number of data registers in memory/CSR space
    localparam DM_DATAADDR   = DM_DATA_BASE[11:0];
    localparam DM_DATAACCESS = 1'b1;
    
    // CPU Bus Interface
    localparam HI_ABB = 31; // high address boundary bit
    localparam LO_ABB = 8;
    
    // Status and Control registers
    localparam SREG_HALT_ACK      = 0,  // CPU is halted in debug mode and waits in loop
               SREG_RESUME_REQ    = 8,  // DM request CPU to resume
               SREG_RESUME_ACK    = 8,  // CPU starts resuming
               SREG_EXECUTE_REQ   = 16, // DM requests to execute program buffer
               SREG_EXECUTE_ACK   = 16, // CPU starts to execute program buffer
               SREG_EXCEPTION_ACK = 24; // CPU has detected an exception
        
    // Debug Core Interface (DCI)
    reg         dci_halt_ack;
    wire        dci_resume_req;
    reg         dci_resume_ack;
    reg         dci_execute_req;
    reg         dci_execute_ack;
    reg         dci_exception_ack;
    reg [255:0] dci_progbuf;
    wire        dci_data_we;
    wire [31:0] dci_wdata;
    reg [31:0]  dci_rdata;
    
    // Global access control
    wire       acc_en;
    wire       rden;
    wire       wren;
    wire [1:0] maddr;
    
    // Data buffer
    reg [31:0] data_buf;
    
    // Program buffer access
    reg [31:0] prog_buf0;
    reg [31:0] prog_buf1;
    reg [31:0] prog_buf2;
    reg [31:0] prog_buf3;
    
    // Debug module control registers
    wire        dm_ctrl_busy;
    reg [31:0]  dm_ctrl_ldsw_progbuf;
    reg         dm_ctrl_pbuf_en;
    // error flag
    reg         dm_ctrl_illegal_state;
    reg         dm_ctrl_illegal_cmd;
    reg [2:0]   dm_ctrl_cmderr;
    // hart status
    reg         dm_ctrl_hart_halted;
    reg         dm_ctrl_hart_resume_req;
    reg         dm_ctrl_hart_resume_ack;
    reg         dm_ctrl_hart_reset;
        
    /*================================================================
    ============ Debug Module (DM) control FSM =======================
    ================================================================*/
    localparam CMD_IDLE         = 1,
               CMD_EXE_CHECK    = 2,
               CMD_EXE_PREAPRE  = 3,
               CMD_EXE_TRIGGER  = 4,
               CMD_EXE_BUSY     = 5,
               CMD_EXE_ERROR    = 6;
    
    reg [2:0] dm_ctrl_state;

    always @(posedge i_clk)
        if (!i_rstn) dm_ctrl_state <= CMD_IDLE;
        else
            case (dm_ctrl_state)
                CMD_IDLE        : // wait for abstract command
                    if ((dmi_wren && (dm_ctrl_cmderr == 3'b000) && (i_dmi_req_address == DMI_ADDR_COMMAND)) ||
                        (dm_reg_autoexec_rd == 1'b1) ||
                        (dm_reg_autoexec_wr == 1'b1))
                        dm_ctrl_state <= CMD_EXE_CHECK;
                CMD_EXE_CHECK   : // check if command is valid / supported
                    if ((dm_reg_command[31:24] == 8'h00)    &&
                        (dm_reg_command[23] == 1'b0)        &&
                        (dm_reg_command[22:20] == 3'b010)   &&
                        (dm_reg_command[19] == 1'b0)        &&
                        ((dm_reg_command[17] == 1'b0) || (dm_reg_command[15:5] == 11'b000_1000_0000)))
                    begin
                        if (dm_ctrl_hart_halted == 1'b1) // CPU is halted
                            dm_ctrl_state <= CMD_EXE_PREAPRE;
                        else // error CPU is still running
                            dm_ctrl_state <= CMD_EXE_ERROR;            
                    end
                    else // Invalid command
                        dm_ctrl_state <= CMD_EXE_ERROR;    
                CMD_EXE_PREAPRE : // setup program buffer
                    dm_ctrl_state <= CMD_EXE_TRIGGER;    
                CMD_EXE_TRIGGER : // request cpu to execute command
                    if (dci_execute_ack) // CPU start execution
                        dm_ctrl_state <= CMD_EXE_BUSY;      
                CMD_EXE_BUSY    : // wait for cpu to finish
                    if (dci_halt_ack) // CPU halted again
                        dm_ctrl_state <= CMD_IDLE;
                CMD_EXE_ERROR   :
                    dm_ctrl_state <= CMD_IDLE;
                default: dm_ctrl_state <= CMD_IDLE;
            endcase
    
    /*================================================================
    ============================ RTL =================================
    ================================================================*/
    // DMI access
    assign dmi_wren = i_dmi_req_valid && (i_dmi_req_op == DMI_OP_WRITE);
    assign dmi_rden = i_dmi_req_valid && (i_dmi_req_op == DMI_OP_READ);
    
    // Debug module command controller
    always @(posedge i_clk)
        if (!i_rstn) dci_execute_req <= 1'b0;
        else dci_execute_req <= dm_ctrl_state == CMD_EXE_TRIGGER;
    
    always @(posedge i_clk)
        if (!i_rstn) begin
            dm_ctrl_ldsw_progbuf  <= INSTR_SW;
            dm_ctrl_pbuf_en       <= 1'b0;
            dm_ctrl_illegal_cmd   <= 1'b0;
            dm_ctrl_illegal_state <= 1'b0;
            dm_ctrl_cmderr        <= 3'b000;
        end
        else begin
            if (dm_ctrl_state == CMD_EXE_PREAPRE)
                if (dm_reg_command[17] == 1'b1) // transfer
                    if (dm_reg_command[16] == 1'b0) // Read from GPR
                    begin
                        dm_ctrl_ldsw_progbuf[31:25] <= DM_DATAADDR[11:5]; // Destination address
                        dm_ctrl_ldsw_progbuf[24:20] <= dm_reg_command[4:0]; // source register
                        dm_ctrl_ldsw_progbuf[19:12] <= INSTR_SW[19:12];
                        dm_ctrl_ldsw_progbuf[11:7]  <= DM_DATAADDR[4:0]; // Destination address   
                        dm_ctrl_ldsw_progbuf[6:0]   <= INSTR_SW[6:0];
                    end
                    else // Write to GPR
                    begin
                        dm_ctrl_ldsw_progbuf[31:20] <= DM_DATAADDR;         // Source register
                        dm_ctrl_ldsw_progbuf[19:12] <= INSTR_LW[19:12];
                        dm_ctrl_ldsw_progbuf[11:7]  <= dm_reg_command[4:0]; // Destination register
                        dm_ctrl_ldsw_progbuf[6:0]   <= INSTR_SW[6:0];
                    end
                else dm_ctrl_ldsw_progbuf <= INSTR_NOP;
                
           dm_ctrl_pbuf_en <= dm_reg_command[18];
           
           dm_ctrl_illegal_cmd <= !((dm_reg_command[31:24] == 8'h00) &&
                                  (dm_reg_command[23] == 1'b0)      &&
                                  (dm_reg_command[22:20] == 3'b010) &&
                                  (dm_reg_command[19] == 1'b0)      &&
                                  ((dm_reg_command[17] == 1'b0) || (dm_reg_command[15:5] == 11'b000_1000_0000))) &&
                                  (dm_ctrl_state == CMD_EXE_CHECK); 
                                  
           dm_ctrl_illegal_state <= ((dm_reg_command[31:24] == 8'h00) &&
                                  (dm_reg_command[23] == 1'b0)      &&
                                  (dm_reg_command[22:20] == 3'b010) &&
                                  (dm_reg_command[19] == 1'b0)      &&
                                  ((dm_reg_command[17] == 1'b0) || (dm_reg_command[15:5] == 11'b000_1000_0000))) &&
                                  (dm_ctrl_state == CMD_EXE_CHECK) &&
                                  (dm_ctrl_hart_halted == 1'b0);
           
           if (dm_ctrl_cmderr == 3'b000) begin // ready to set new error
                if (dm_ctrl_illegal_state) // cannot execute since hart is not in expected state
                    dm_ctrl_cmderr <= 3'b100;
                else if (dci_exception_ack) // exception during execution
                    dm_ctrl_cmderr <= 3'b011;
                else if (dm_ctrl_illegal_cmd) // unsupported command
                    dm_ctrl_cmderr <= 3'b010;
                else if (dm_reg_rd_acc_err || dm_reg_wr_acc_err)
                    dm_ctrl_cmderr <= 3'b001;
           end
           else if (dm_reg_clr_acc_err == 1'b1) // acknowledge/clear error flags 
                dm_ctrl_cmderr <= 3'b000;                              
        end
    
    assign dm_ctrl_busy = !(dm_ctrl_state == CMD_IDLE);
    
    // Hart status
    always @(posedge i_clk)
        if (!i_rstn) begin
          dm_ctrl_hart_halted     <= 1'b0;
          dm_ctrl_hart_resume_req <= 1'b0;
          dm_ctrl_hart_resume_ack <= 1'b0;
          dm_ctrl_hart_reset      <= 1'b0;            
        end
        else begin
            // HALTED ACK
            if (dm_reg_dmcontrol_ndmreset == 1'b1)
                dm_ctrl_hart_halted <= 1'b0;
            else if (dci_halt_ack == 1'b1)
                dm_ctrl_hart_halted <= 1'b1;
            else if (dci_resume_ack == 1'b1)
                dm_ctrl_hart_halted <= 1'b0;  
            
          // RESUME REQ
          if (dm_reg_dmcontrol_ndmreset == 1'b1)
            dm_ctrl_hart_resume_req <= 1'b0;
          else if (dm_reg_resume_req == 1'b1)
            dm_ctrl_hart_resume_req <= 1'b1;
          else if (dci_resume_ack == 1'b1)
            dm_ctrl_hart_resume_req <= 1'b0;
          
          // RESUME ACK
          if (dm_reg_dmcontrol_ndmreset == 1'b1)
            dm_ctrl_hart_resume_ack <= 1'b0;
          else if (dci_resume_ack == 1'b1)
            dm_ctrl_hart_resume_ack <= 1'b1;
          else if (dm_reg_resume_req == 1'b1)
            dm_ctrl_hart_resume_ack <= 1'b0;
  
          // hart has been RESET
          if (dm_reg_dmcontrol_ndmreset == 1'b1) // explicit RESET triggered by DM
            dm_ctrl_hart_reset <= 1'b1;
          else if (dm_reg_reset_ack == 1'b1)
            dm_ctrl_hart_reset <= 1'b0;        
        end
   
   // Debug Module Interface - Write access
  always @(posedge i_clk)
    if (!i_rstn)
    begin
      dm_reg_dmcontrol_ndmreset <= 1'b0; // no system SoC reset
      dm_reg_dmcontrol_dmactive <= 1'b0; // DM is in reset state after hardware reset
      
      dm_reg_halt_req    <= 1'b0;
      dm_reg_resume_req  <= 1'b0;
      dm_reg_reset_ack   <= 1'b0;
      dm_reg_wr_acc_err  <= 1'b0;
      dm_reg_clr_acc_err <= 1'b0;
      dm_reg_autoexec_wr <= 1'b0;
      
      dm_reg_abstractauto_autoexecdata    <= 1'b0;
      dm_reg_abstractauto_autoexecprogbuf <= 2'b00;
      
      dm_reg_command <= 32'd0;
      dm_reg_progbuf0 <= INSTR_NOP;
      dm_reg_progbuf1 <= INSTR_NOP;
    end
    else if (dmi_wren) // valid DMI write request
    begin
      if (i_dmi_req_address == DMI_ADDR_DMCONTROL) begin
        dm_reg_dmcontrol_ndmreset <= i_dmi_req_data[1]; // ndmreset (r/w): soc reset
        dm_reg_dmcontrol_dmactive <= i_dmi_req_data[0]; // dmactive (r/w): DM reset
        dm_reg_halt_req           <= i_dmi_req_data[31];
      end
      
      dm_reg_resume_req   <= i_dmi_req_data[30] && (i_dmi_req_address == DMI_ADDR_DMCONTROL); // resumereq (-/w1): write 1 to request resume; auto-clears
      dm_reg_reset_ack    <= i_dmi_req_data[28] && (i_dmi_req_address == DMI_ADDR_DMCONTROL); // ackhavereset (-/w1): write 1 to ACK reset; auto-clears
      // Invalid access while command is executing
      dm_reg_wr_acc_err   <= dm_ctrl_busy &&      
                       ((i_dmi_req_address == DMI_ADDR_ABSTRACTS)   ||
                        (i_dmi_req_address == DMI_ADDR_COMMAND)     ||
                        (i_dmi_req_address == DMI_ADDR_ABSRACTAUTO) ||
                        (i_dmi_req_address == DMI_ADDR_DATA0)       ||
                        (i_dmi_req_address == DMI_ADDR_PROGBUF0)    ||
                        (i_dmi_req_address == DMI_ADDR_PROGBUF1));
      // ACK command error
      dm_reg_clr_acc_err  <= (i_dmi_req_address == DMI_ADDR_ABSTRACTS) &&
                             (i_dmi_req_data[10:8] == 3'b111);
      // Auto execution trigger                
      dm_reg_autoexec_wr  <= ((i_dmi_req_address == DMI_ADDR_DATA0) && dm_reg_abstractauto_autoexecdata)          ||
                             ((i_dmi_req_address == DMI_ADDR_PROGBUF0) && dm_reg_abstractauto_autoexecprogbuf[0]) ||
                             ((i_dmi_req_address == DMI_ADDR_PROGBUF1) && dm_reg_abstractauto_autoexecprogbuf[1]);
      
     
      // Write abstract command autoxec
      if (i_dmi_req_address == DMI_ADDR_ABSRACTAUTO)
        if (!dm_ctrl_busy) begin
            dm_reg_abstractauto_autoexecdata <= i_dmi_req_data[0];
            dm_reg_abstractauto_autoexecprogbuf[0] <= i_dmi_req_data[16];
            dm_reg_abstractauto_autoexecprogbuf[1] <= i_dmi_req_data[17];       
        end
        
     
     // Write abstract command
     if (i_dmi_req_address == DMI_ADDR_COMMAND)
        if (!dm_ctrl_busy && (dm_ctrl_cmderr == 3'b000))
            dm_reg_command <= i_dmi_req_data;
            
            
     // Write program bufer
     if (i_dmi_req_address[5:1] == DMI_ADDR_PROGBUF0[5:1])
        if (!dm_ctrl_busy)   
            if (~i_dmi_req_address[0])
                dm_reg_progbuf0 <= i_dmi_req_data;
            else
                dm_reg_progbuf1 <= i_dmi_req_data;                              
   end
            
   // ===== Direct control
   // Abtract data register
   assign dci_data_we = dmi_wren && (i_dmi_req_address == DMI_ADDR_DATA0) && (!dm_ctrl_busy);
   assign dci_wdata   = i_dmi_req_data;   
   
   // CPU halt/resume request
  assign o_cpu_halt_req = dm_reg_halt_req && dm_reg_dmcontrol_dmactive; // single-shot
  assign dci_resume_req = dm_ctrl_hart_resume_req; // active until explicitly cleared   
   
  // SOC reset
  assign o_cpu_ndmrstn =  ~(dm_reg_dmcontrol_ndmreset && dm_reg_dmcontrol_dmactive); // to processor's reset generator
  
  // construct program buffer array for CPU access
  assign cpu_progbuf0 = dm_ctrl_ldsw_progbuf; // pseudo program buffer for GPR access
  assign cpu_progbuf1 = !dm_ctrl_pbuf_en? INSTR_NOP : dm_reg_progbuf0;
  assign cpu_progbuf2 = !dm_ctrl_pbuf_en? INSTR_NOP : dm_reg_progbuf1;
  assign cpu_progbuf3 = INSTR_EBREAK; // implicit ebreak instruction
  
  // DMI status
  assign o_dmi_rsp_op    = 2'b00; // operation success
  assign o_dmi_req_ready = 1'b1; // always ready for new read/write
  
endmodule
