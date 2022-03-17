`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output		busy,
	input		ready,

	output		iaddr,
	input		idata,

	output	 	cwr,
	output	 	caddr_wr,
	output	 	cdata_wr,

	output	 	crd,
	output	 	caddr_rd,
	input	 	cdata_rd,

	output	 	csel
	);
	reg [3:0] conv_current_state,conv_next_state;
	parameter IDLE = 0;
	parameter DATA_WIDTH = 20;

	wire [DATA_WIDTH-1:0] kernal_input;
	wire [DATA_WIDTH-1:0] grey_pixel;
	reg [2:0] counter_reg;

	always @(posedge clk)
	begin
		counter_reg <= reset ? 0 : counter_reg+1;
<<<<<<< HEAD
	end

	always @(posedge clk )
	begin
		conv_current_state <= reset ? IDLE : conv_next_state;
=======
>>>>>>> 95e4a9641de472ea98b92faf8d90a9b62e94f71c
	end


endmodule
