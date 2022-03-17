`timescale 1ns/10ps

module CONV(input		clk,
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
            output	 	csel);
    reg [3:0] conv_current_state,conv_next_state;
    parameter IDLE       = 0;
    parameter CAL        = 1;
    parameter DONE       = 2;
    parameter DATA_WIDTH = 20;

    wire [DATA_WIDTH-1:0] kernal_input;
    wire [DATA_WIDTH-1:0] grey_pixel;
    reg [2:0] counter_reg;

    always @(posedge clk)
    begin
        counter_reg <= reset ? 0 : counter_reg+3;
    end

    always @(posedge clk)
    begin
        conv_current_state <= reset ? IDLE : conv_next_state;
    end

    always @(*)
    begin
        case(conv_current_state)
            IDLE:
            begin

            end

            CAL:
            begin

            end

            DONE:
            begin

            end

            default:
            begin

            end
        endcase
    end


endmodule
