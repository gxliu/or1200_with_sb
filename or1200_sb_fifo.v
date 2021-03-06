//////////////////////////////////////////////////////////////////////
////                                                              ////
////  OR1200's Store Buffer FIFO                                  ////
////                                                              ////
////  This file is part of the OpenRISC 1200 project              ////
////  http://www.opencores.org/cores/or1k/                        ////
////                                                              ////
////  Description                                                 ////
////  Implementation of store buffer FIFO.                        ////
////                                                              ////
////  To Do:                                                      ////
////   - N/A                                                      ////
////                                                              ////
////  Author(s):                                                  ////
////      - Damjan Lampret, lampret@opencores.org                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2002 Authors and OPENCORES.ORG                 ////
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
// $Log: or1200_sb_fifo.v,v $
// Revision 2.0  2010/06/30 11:00:00  ORSoC
// No update 
//
// Revision 1.3  2002/11/06 13:53:41  simons
// SB mem width fixed.
//
// Revision 1.2  2002/08/22 02:18:55  lampret
// Store buffer has been tested and it works. BY default it is still disabled until uClinux confirms correct operation on FPGA board.
//
// Revision 1.1  2002/08/18 19:53:08  lampret
// Added store buffer.
//
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_sb_fifo(
	clk_i, rst_i, dat_i, wr_i, rd_i, dat_o, full_o, empty_o,
	sb_hit, hit_data_o
);

   parameter dw = 32+4+32+1; //addr, sel, data, ci (no tag) //68;
   parameter fw = 4;//`OR1200_SB_LOG;
   parameter fl = 1<<fw;//`OR1200_SB_ENTRIES;

//
// FIFO signals
//
input			clk_i;	// Clock
input			rst_i;	// Reset
input	[dw-1:0]	dat_i;	// Input data bus
input			wr_i;	// Write request
input			rd_i;	// Read request
output [dw-1:0]	dat_o;	// Output data bus
output			full_o;	// FIFO full
output			empty_o;// FIFO empty

//
// Internal regs
//
reg	[dw-1:0]	mem [fl-1:0];
reg	[dw-1:0]	dat_o;
reg	[fw+1:0]	cntr;
reg	[fw-1:0]	wr_pntr;
reg	[fw-1:0]	rd_pntr;
reg			empty_o;
reg			full_o;


//this part is for compare ld_addr and stores in the sb
//
//
//
   output  reg 		sb_hit;
   output reg [31:0] 	hit_data_o;
   reg [fl-1:0] 	addr_hit, sel_hit;
   reg [fl-1:0] 	shift_addr_hit, shift_sel_hit, addrhit_selmiss, addrhit_selhit; 
   reg [fw-1:0] 	hit_pntr;
   reg [fl-1:0] 	mask;
   integer 		i, addrhit_selmiss_h, addrhit_selhit_h; 
   always @ (*) begin
   //each bit means that entry's addr matches ld_addr      
      for (i=0; i<fl; i=i+1) begin
	 if (mem[i][63:32] == dat_i[63:32]) addr_hit[i] = 1;
	 else addr_hit[i] = 0;
	 if (mem[i][67:64] & dat_i[67:64] == dat_i[67:64]) sel_hit[i] = 1;
	 else sel_hit[i] = 0;
      end
/*      if ((mem[0][63:32] == dat_i[63:32]) 
	  && (mem[0][67:64] & dat_i[67:64] == dat_i[67:64])) addr_hit[0] = 1;
      else addr_hit[0] = 0;
      if ((mem[1][63:32] == dat_i[63:32])
	  && (mem[1][67:64] & dat_i[67:64] == dat_i[67:64])) addr_hit[1] = 1;
      else addr_hit[1] = 0;
      if ((mem[2][63:32] == dat_i[63:32]) 
	  && (mem[2][67:64] & dat_i[67:64] == dat_i[67:64])) addr_hit[2] = 1;
      else addr_hit[2] = 0;
      if ((mem[3][63:32] == dat_i[63:32])
	  && (mem[3][67:64] & dat_i[67:64] == dat_i[67:64])) addr_hit[3] = 1;
      else addr_hit[3] = 0;
  */    
      //generate mask according to cntr
      for (i=0; i<fl; i=i+1) begin
	 if (i<cntr) mask[i] = 1;
	 else mask[i] = 0;
      end
      /*
      case (cntr)
	4: mask = 4'b1111;
	3: mask = 4'b0111;
	2: mask = 4'b0011;
	1: mask = 4'b0001;
	default : mask = 4'b0000;
      endcase // case (cntr)*/
      //shift to make rd_pntr at lowest bit, and larger than wr_pntr bits mask to 0
      shift_addr_hit = ((addr_hit>>rd_pntr) + (addr_hit<<(fl-rd_pntr))) & mask;
      shift_sel_hit = ((sel_hit>>rd_pntr) + (sel_hit<<(fl-rd_pntr))) & mask; 
      addrhit_selhit = shift_addr_hit & shift_sel_hit;
      addrhit_selmiss = shift_addr_hit & (~shift_sel_hit);
      //decide the highest bit that is 1, 
      addrhit_selhit_h = -1;
      addrhit_selmiss_h = -1;
      for (i=0; i<fl; i=i+1) begin
	 if (addrhit_selhit[i] == 1) begin
	    addrhit_selhit_h = i;//(i+rd_pntr)%fl;
	 end
	 if (addrhit_selmiss[i] == 1) begin
	    addrhit_selmiss_h = i;//(i+rd_pntr)%fl;
	 end
      end
      /*
      else if (rotated_addr_hit[2] == 1) begin
	 hit_pntr = (2+rd_pntr)%fl;
      end
      else if (rotated_addr_hit[1] == 1) begin
	 hit_pntr = (1+rd_pntr)%fl;
      end
      else if (rotated_addr_hit[0] == 1) begin
	 hit_pntr = (0+rd_pntr)%fl;
      end
      else begin
	 hit_pntr = 0;
      end
      */
      hit_pntr = (addrhit_selhit_h+rd_pntr)%fl;
      sb_hit = ((addrhit_selhit_h >= 0) && (addrhit_selhit_h > addrhit_selmiss_h));
      hit_data_o = mem[hit_pntr][31:0];
   end
   
   
   

always @ (*) begin //always output the head of fifo
   if (rst_i == `OR1200_RST_VALUE) begin
      dat_o = {dw{1'b0}};
   end
   else begin 
      dat_o = mem[rd_pntr];
   end
end
   
always @(posedge clk_i or `OR1200_RST_EVENT rst_i)
	if (rst_i == `OR1200_RST_VALUE) begin
		full_o <=  1'b0;
		empty_o <=  1'b1;
		wr_pntr <=  {fw{1'b0}};
		rd_pntr <=  {fw{1'b0}};
		cntr <=  {fw+2{1'b0}};
		//dat_o <=  {dw{1'b0}};
	end
	else if (wr_i && rd_i) begin		// FIFO Read and Write
		mem[wr_pntr] <=  dat_i;
		if (wr_pntr >= fl-1)
			wr_pntr <=  {fw{1'b0}};
		else
			wr_pntr <=  wr_pntr + 1'b1;
		/*if (empty_o) begin
			dat_o <=  dat_i;
		end
		else begin
			dat_o <=  mem[rd_pntr];
		end*/
		if (rd_pntr >= fl-1)
			rd_pntr <=  {fw{1'b0}};
		else
			rd_pntr <=  rd_pntr + 1'b1;
	end
	else if (wr_i && !full_o) begin		// FIFO Write
		mem[wr_pntr] <=  dat_i;
		cntr <=  cntr + 1'b1;
		empty_o <=  1'b0;
		if (cntr >= (fl-1)) begin
			full_o <=  1'b1;
			cntr <=  fl;
		end
		if (wr_pntr >= fl-1)
			wr_pntr <=  {fw{1'b0}};
		else
			wr_pntr <=  wr_pntr + 1'b1;
	end
	else if (rd_i && !empty_o) begin	// FIFO Read
		//dat_o <=  mem[rd_pntr];
		cntr <=  cntr - 1'b1;
		full_o <=  1'b0;
		if (cntr <= 1) begin
			empty_o <=  1'b1;
			cntr <=  {fw+2{1'b0}};
		end
		if (rd_pntr >= fl-1)
			rd_pntr <=  {fw{1'b0}};
		else
			rd_pntr <=  rd_pntr + 1'b1;
	end

endmodule
