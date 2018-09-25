/////////////////////////////////////////////////////////////////
// NUDT.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: NUDT
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: pgm.v
//Version: 2.0
//Author : (Yang Xiangrui) FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)store pkt sending from UA
// 2)generating pkts
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2018/09/25
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 

module pgm_wr #(
	parameter PLATFORM = "Xilinx",
)(
	input clk,
	input rst_n,

//receive data & phv from Previous module
	
    input [1023:0] in_wr_phv,
	input in_wr_phv_wr, 
	output out_wr_phv_alf,

	input [133:0] in_wr_data,
	input in_wr_data_wr,
	input in_wr_valid_wr,
	input in_wr_valid,
	output out_wr_alf,

//transport phv and data to pgm_rd
    output reg [1023:0] out_wr_phv,
	output reg out_wr_phv_wr,
	input in_wr_phv_alf,

	output reg [133:0] out_wr_data, 
	output reg out_wr_data_wr,
	output reg out_wr_valid,
	output reg out_wr_valid_wr,
	input in_wr_alf,

//output to PGM_RAM
	output reg wr2ram_wr_en,
	output reg [143:0] wr2ram_wdata,
	output reg [6:0] wr2ram_addr


//signals to PRM_RD
	output pgm_bypass_flag,
	output pgm_sent_start_flag,
	output pgm_sent_finish_flag,

//input cfg packet from DMA
    input [133:0] cin_wr_data,
	input cin_wr_data_wr,
	output cout_wr_ready,

//output configure pkt to next module
    output [133:0] cout_wr_data,
	output cout_wr_data_wr,
	input cin_wr_ready,

);

//***************************************************
//        Intermediate variable Declaration
//****************************************************
//all wire/reg/parameter variable
//should be declare below here

//user defined counters and regs
reg [63:0] sent_time_cnt;
reg [63:0] sent_time_reg;
reg soft_rst;



assign out_wr_phv_alf = in_wr_phv_alf;
assign out_wr_alf = in_wr_alf;
assign cout_wr_ready = cin_wr_ready;
assign cout_wr_data = cin_wr_data;
assign cout_wr_data_wr = cin_wr_data_wr;

reg [4:0] pgm_wr_state;

//***************************************************
//             Pkt Store & Transmit
//***************************************************

localparam IDLE_S = 5'd0,
			WAIT_S = 5'd1,
			STORE_S = 5'd2,
			SENT_S = 5'd3,
			DISCARD_S = 5'd4;

always @(posedge clk or negedge rst_n) begin

	if(rst_n == 1'b0 || soft_rst == 1'b1) begin

		wr2ram_wr_en <= 1'b0;
		wr2ram_wdata <= 144'b0;
		wr2ram_addr <= 7'b0;

		//outputs set to 0
		out_wr_data <= 134'b0;
		out_wr_data_wr <= 1'b0;
		out_wr_valid <= 1'b0;
		out_wr_valid_wr <= 1'b0;

		out_wr_phv <= 1024'b0;
		out_wr_phv_wr <= 1'b0;

		//intermediate set to 0
		sent_time_cnt <= 64'b0;
		sent_time_reg <= 64'b0;
		soft_rst <= 1'b0;
		
	end
	else begin
		case(pgm_wr_state)
			IDLE_S: begin
				
				//start bypassing
				if(in_wr_valid == 1'b1 && in_wr_data[133:132]==2'b01 && in_wr_data[111:109]!=3'b111) begin
					out_wr_data <= in_wr_data;
					out_wr_data_wr <= 1'b1;
					out_wr_phv <= in_wr_phv;
					out_wr_phv_wr <= 1'b1;
					out_wr_valid <= 1'b1;

					pgm_bypass_flag <= 1'b1;
					pgm_wr_state <= SENT_S;
				end

				else if(in_wr_valid == 1'b1 && in_wr_data[133:132]==2'b01 && in_wr_data[111:109]==3'b111) begin
					wr2ram_wr_en <= 1'b1;
					wr2ram_addr <= 7'b0;
					wr2ram_wdata <= {10'b0,in_wr_data};

					//pgm_sent_start_flag <= 1'b1;
					pgm_wr_state <= STORE_S;
				end
				else begin
					wr2ram_wr_en <= 1'b0;
					wr2ram_wdata <= 144'b0;
					wr2ram_addr <= 7'b0;

					//outputs set to 0
					out_wr_data <= 134'b0;
					out_wr_data_wr <= 1'b0;
					out_wr_valid <= 1'b0;
					out_wr_valid_wr <= 1'b0;

					out_wr_phv <= 1024'b0;
					out_wr_phv_wr <= 1'b0;

					pgm_wr_state <= DISCARD_S;
				end
			end

			SENT_S: begin
				if(in_wr_valid == 1'b1 && in_wr_data[133:132] == 2'b11) begin
					out_wr_data <= in_wr_data;
					out_wr_data_wr <= 1'b1;
					out_wr_phv <= in_wr_phv;
					out_wr_phv_wr <= 1'b1;
					out_wr_valid <= 1'b1;
					pgm_wr_state <= SENT_S;
				end

				else if(in_wr_valid == 1'b1 && in_wr_data[133:132] == 2'b10) begin
					out_wr_data <= 134'b0;
					out_wr_data_wr <= 1'b0;
					out_wr_valid <= 1'b0;
					out_wr_valid_wr <= 1'b0;

					out_wr_phv <= 1024'b0;
					out_wr_phv_wr <= 1'b0;
					pgm_wr_state <= IDLE_S;
				end

				else begin
					out_wr_data <= 134'b0;
					out_wr_data_wr <= 1'b0;
					out_wr_valid <= 1'b0;
					out_wr_valid_wr <= 1'b0;

					out_wr_phv <= 1024'b0;
					out_wr_phv_wr <= 1'b0;
					pgm_wr_state <= DISCARD_S;
				end
			end

			STORE_S: begin
				if(in_wr_data[133:132] == 2'b11) begin
					wr2ram_wr_en <= 1'b1;
					wr2ram_wdata <= {10'b0, in_wr_data};
					wr2ram_addr <= wr2ram_addr + 1'b1;
				end
				else if(in_wr_data[133:132] == 2'b10) begin
					wr2ram_wr_en = 1'b0;

					pgm_sent_start_flag <= 1'b1;
					pgm_wr_state <= WAIT_S;
				end
				else begin
					/*TODO: clear all the values in RAM*/
					wr2ram_wr_en <= 1'b0;
					pgm_wr_state <= DISCARD_S;
				end
			end

			WAIT_S: begin
				if(sent_time_cnt != sent_time_reg) begin
					sent_time_cnt <= sent_time_cnt + 1'b1;
				end
				else begin
					pgm_sent_finish_flag <= 1'b1;
					pgm_wr_state <= IDLE_S;
				end
			end

			DISCARD_S: begin
				if(in_wr_data[133:132] != 2'b10 && in_wr_data_wr == 1'b1) begin
					wr2ram_wr_en <= 1'b0;

					//outputs set to 0
					out_wr_data <= 134'b0;
					out_wr_data_wr <= 1'b0;
					out_wr_valid <= 1'b0;
					out_wr_valid_wr <= 1'b0;

					out_wr_phv <= 1024'b0;
					out_wr_phv_wr <= 1'b0;
				end 

				else begin
					pgm_wr_state <= IDLE_S;
				end
			end
	end
end

endmodule