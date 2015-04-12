// synopsys translate_off
`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_dc_sb (
		     clk, rst,
		     dc_en, dmmu_en,
		     //sb to LSU
		     sbcpu_data_i, sbcpu_sel_i, sbcpu_addr_i,
		     sbcpu_we_i, sbcpu_cycstb_i, //sbcpu_tag_i, 
		     sbcpu_ci_i,
		     sbcpu_data_o, sbcpu_ack_o,
		     sbcpu_err_o, //sbcpu_tag_o,
		     //sb to DCache
		     sbdc_data_o, sbdc_addr_o, sbdc_cycstb_o,
		     sbdc_we_o, sbdc_sel_o, 
		     //sbdc_tag_o, 
		     sbdc_ci_o,
		     sbdc_data_i, sbdc_ack_i, sbdc_err_i
		     //sbdc_tag_i
		     );


   input clk;
   input rst;
   input dc_en;
   input dmmu_en;
   //sb to LSU
   input [31:0] sbcpu_data_i;
   input [3:0] 	sbcpu_sel_i;
   input [31:0] sbcpu_addr_i;
   input 	sbcpu_we_i;
   input 	sbcpu_cycstb_i;
   //input [3:0] 	sbcpu_tag_i;
   input 	sbcpu_ci_i;
   output [31:0] sbcpu_data_o;
   output 	 sbcpu_ack_o;
   output 	 sbcpu_err_o;
   //output [3:0]  sbcpu_tag_o;
   //sb to DCache
   output [31:0] sbdc_data_o;
   output [31:0] sbdc_addr_o;
   output 	 sbdc_cycstb_o;
   output 	 sbdc_we_o;
   output [3:0]  sbdc_sel_o;
//   output [3:0]  sbdc_tag_o;
   output 	 sbdc_ci_o;
   input [31:0]  sbdc_data_i;
   input 	 sbdc_ack_i;
   input 	 sbdc_err_i;
  // input [3:0] 	 sbdc_tag_i;

   wire 	 no_sb;
`ifdef NO_DC_SB
   assign no_sb = 1;
`else
   assign no_sb = 0;
`endif
   wire 	 bypass;
   wire 	 disabled;
   assign disabled = 0;//!dc_en | !dmmu_en | no_sb;
   assign bypass = disabled | (state2 == LOADING) | (state2 == ERR_HANDLING);

//I/O, either bypass, or use value generated by FSM
   assign sbcpu_data_o = (state == LOAD_HIT_SB) ? hit_data_o : sbdc_data_i;
   assign sbcpu_ack_o =  bypass ? sbdc_ack_i : sb_ack_cpu;
   assign sbcpu_err_o =  bypass ? sbdc_err_i : sb_err_cpu;

   assign sbdc_data_o =  bypass ? sbcpu_data_i : sb_data_dc;
   assign sbdc_addr_o =  bypass ? sbcpu_addr_i : sb_addr_dc;
   assign sbdc_cycstb_o =  bypass ? sbcpu_cycstb_i : sb_cycstb_dc;
   assign sbdc_we_o =  bypass ? sbcpu_we_i : sb_we_dc;
   assign sbdc_sel_o =  bypass ? sbcpu_sel_i : sb_sel_dc;
   assign sbdc_ci_o =  bypass ? sbcpu_ci_i : sb_ci_dc;

//internal signals
   reg 		 sb_ack_cpu, sb_err_cpu;

   reg 		 sb_cycstb_dc, sb_we_dc;
   wire [31:0] 	 sb_data_dc, sb_addr_dc;
   wire 	 sb_ci_dc;
   wire [3:0] 	 sb_sel_dc;

   reg 		 load_ack;
   

   wire 	 isStore, isLoad, invalid_addr;
   assign isStore = sbcpu_cycstb_i & sbcpu_we_i;
   assign isLoad = sbcpu_cycstb_i & ~sbcpu_we_i;
   assign invalid_addr = |sbcpu_addr_i[27:23];
    //in this case, RAM is 8MB, 23 bits address
//-------------FSM1--------------------------
   parameter IDLE  = 3'b000,
     STORE = 3'b001,
     BUSERR = 3'b010,
     LOAD_HIT_SB = 3'b011,
     LOAD_MISS_SB = 3'b100;
   
   reg [2:0] 	 state;
   reg [2:0] 	 next_state  ;
   
   always @ (*)
     begin : FSM1_COMBO
	if (rst == 1'b1 | disabled) begin
	   next_state = IDLE;
	   sb_ack_cpu = 0;
	   sb_err_cpu = 0;
	   fifo_wr = 0;
	end
	else begin
	   case(state)
	     IDLE : begin
		sb_ack_cpu = 0;
		sb_err_cpu = 0;
		if ((isStore | isLoad) & invalid_addr) begin
		   fifo_wr = 0;
		   if (fifo_empty) begin
		      next_state = BUSERR;
		   end
		   else begin
		      next_state = IDLE; //wait until fifo is empty to maintain precise state
		   end
		end
		else if (isStore & ~fifo_full) begin
		   fifo_wr = 1;
		   next_state = STORE;
		end
		else if (isLoad & load_hit_sb) begin
		   fifo_wr = 0;
		   next_state = LOAD_HIT_SB;
		end
		else if (isLoad & load_miss_sb) begin
		   fifo_wr = 0;
		   next_state = LOAD_MISS_SB;
		end
		else begin
		   next_state = IDLE;
		   fifo_wr = 0;
		 end
	     end
	     STORE : begin
		next_state = IDLE;
		fifo_wr = 0;
		sb_ack_cpu = 1;
		sb_err_cpu = 0;
	     end
	     BUSERR : begin
		if (sbdc_err_i) begin
		   next_state = IDLE;
//		   sb_err_cpu = 1;
//		   sb_ack_cpu = 0;
		   fifo_wr = 0;
		end
		else begin
		   next_state = BUSERR;
//		   sb_err_cpu = 0;
//		   sb_ack_cpu = 0;
		   fifo_wr = 0;
		end
	     end
	    
	     LOAD_HIT_SB : begin
		next_state = IDLE;
		fifo_wr = 0;
		sb_ack_cpu = 1;
		sb_err_cpu = 0;
	     end
	     LOAD_MISS_SB : begin
		if (load_ack) begin
		   next_state = IDLE;
		   fifo_wr = 0;
		end
		else begin
		   next_state = LOAD_MISS_SB;
		   fifo_wr = 0;
		end
	     end
	     default : begin
		next_state = IDLE;
		sb_err_cpu = 0;
		sb_ack_cpu = 0;
		fifo_wr = 0;
	     end
	   endcase // case (state)
	end // else: !if(rst == 1'b1)
     end // block: FSM1_COMBO
   always @ (posedge clk)
     begin : FSM1_SEQ
	if (rst == 1'b1) begin
	   state <= IDLE;
	end 
	else begin
	   state <= next_state;
	end
     end
   
//fifo I/O
   wire  fifo_full, fifo_empty;
   reg 	 fifo_rd,  fifo_wr;
   wire [32+4+32+1-1:0] fifo_dat_o, fifo_dat_i;
   wire 		load_hit_sb, load_miss_sb;
   wire [31:0] 		hit_data_o;
   assign load_miss_sb = ~load_hit_sb;
   
//   wire [31:0] 		  fifo_addr, fifo_data;
  // wire [3:0] 		  fifo_sel, fifo_tag;
  // wire 		  fifo_ci;
   assign fifo_dat_i = {sbcpu_ci_i, sbcpu_sel_i, sbcpu_addr_i,sbcpu_data_i};
   assign {sb_ci_dc, sb_sel_dc, sb_addr_dc, sb_data_dc} = fifo_dat_o;
   
   or1200_sb_fifo or1200_dcsb_fifo (
    .clk_i(clk),
    .rst_i(rst),
    .dat_i(fifo_dat_i),
    .wr_i(fifo_wr),
    .rd_i(fifo_rd),
    .dat_o(fifo_dat_o),
    .full_o(fifo_full),
    .empty_o(fifo_empty),
    .sb_hit(load_hit_sb),
    .hit_data_o(hit_data_o)
    );
   
//-------------FSM2--------------------------
   parameter START  = 3'b000,
     STORING = 3'b001, 
     LOADING = 3'b010,
     ERR_HANDLING = 3'b011;
   
   reg [2:0] 		  state2;
   reg [2:0] 		  next_state2;
   always @ (*)
      begin : FSM2_COMBO
	 if (rst == 1'b1 | disabled) begin
	    next_state2 = START;
	    fifo_rd = 0;
	    sb_cycstb_dc = 0;
	    sb_we_dc = 0;
	    load_ack = 0;
	 end
	 else begin
	    case(state2)
	      START : begin
		 sb_cycstb_dc = 0;
		 sb_we_dc = 0;
		 fifo_rd = 0;
		 load_ack = 0;
		 if (state == BUSERR) begin
		    if (fifo_empty) begin
		       next_state2 = ERR_HANDLING;
		    end
		    else begin
		       next_state2 = STORING;
		    end
		 end
		 else if (state == LOAD_MISS_SB) begin
		    next_state2 = LOADING;
		 end
	         else if (~fifo_empty) begin
		    next_state2 = STORING;
		 end
		 else begin
		    next_state2 = START;
		 end
	      end
	      STORING : begin
		 sb_we_dc = 1;
		 if(sbdc_ack_i) begin
		    next_state2 = START;
		    sb_cycstb_dc = 0;
		    fifo_rd = 1;
		 end
		 else begin
		    next_state2 = STORING;
		    sb_cycstb_dc = 1;
		    fifo_rd = 0;
		 end
	      end
	      LOADING : begin 
		 fifo_rd = 0;
		 if(sbdc_ack_i) begin
		    load_ack = 1;
		    next_state2 = START;
		 end
		 else begin
		    load_ack = 0;
		    next_state2 = LOADING;
		 end
	      end
	      ERR_HANDLING : begin
		 if(sbdc_err_i) begin
		    next_state2 = START;
		 end
		 else begin
		    next_state2 = ERR_HANDLING;
		 end
	      end
	      default : begin
		 next_state2 = START;
		 fifo_rd = 0;
		 sb_cycstb_dc = 0;
		 sb_we_dc = 0;
	      end
	    endcase // case (state2)
	 end // else: !if(rst == 1'b1)
      end // block: FSM2_COMBO
   always @ (posedge clk)
     begin : FSM2_SEQ
	if (rst == 1'b1) begin
	   state2 <= START;
	end 
	else begin
	   state2 <= next_state2;
	end
     end
endmodule
   
