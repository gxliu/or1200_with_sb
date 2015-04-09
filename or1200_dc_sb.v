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
   
//bypass sb
   assign sbcpu_data_o = sbdc_data_i;
   assign sbcpu_ack_o = sbdc_ack_i;
   assign sbcpu_err_o = sbdc_err_i;

   assign sbdc_data_o = sbcpu_data_i;
   assign sbdc_addr_o = sbcpu_addr_i;
   assign sbdc_cycstb_o = sbcpu_cycstb_i;
   assign sbdc_we_o = sbcpu_we_i;
   assign sbdc_sel_o = sbcpu_sel_i;
   assign sbdc_ci_o = sbcpu_ci_i;

endmodule
   
