`timescale 1ns/10ps
module CONV(clk,
            reset,
            busy,
            ready,
            iaddr,
            idata,
            cwr,
            caddr_wr,
            cdata_wr,
            crd,
            caddr_rd,
            cdata_rd,
            csel);
    /*---------------------PARAMETERS--------------------------*/
    parameter DATA_WIDTH    = 20 ;
    parameter ADDR_WIDTH    = 12 ;
    parameter COUNTER_WIDTH = 8 ;
    parameter IMAGE_WIDTH   = 64;
    parameter KERNAL_WIDTH  = 3;
    parameter POINTER_WIDTH = 7;
    /*-----------------Varaible Declaration---------------------*/
    //INPUTS
    input clk;
    input reset;
    input ready;
    input[DATA_WIDTH-1:0] idata;
    input[DATA_WIDTH-1:0] cdata_rd;

    //OUTPUTS
    output reg busy;
    output reg crd;
    output reg cwr;
    output reg[2:0] csel;
    output reg[ADDR_WIDTH-1:0] iaddr;
    output reg[ADDR_WIDTH-1:0] caddr_rd;
    output reg[DATA_WIDTH-1:0] cdata_wr;
    output reg[ADDR_WIDTH-1:0] caddr_wr;

    //CONV MAIN CTR
    parameter IDLE          = 'd0 ;
    parameter RD_DATA       = 'd1 ;
    parameter ZERO_PAD_CONV = 'd2 ;
    parameter RE_LU         = 'd3 ;
    parameter WB            = 'd4 ;
    parameter INCR_POINTER  = 'd5 ;
    parameter DONE          = 'd6 ;

    //State register
    reg[3:0] conv_current_state,conv_next_state;

    //State indicators
    wire conv_state_IDLE          = conv_current_state == IDLE ;
    wire conv_state_RD_DATA       = conv_current_state == RD_DATA;
    wire conv_state_ZERO_PAD_CONV = conv_current_state == ZERO_PAD_CONV;
    wire conv_state_RELU          = conv_current_state == RE_LU ;
    wire conv_state_WB            = conv_current_state == WB ;
    wire conv_state_INCR_POINTER  = conv_current_state == INCR_POINTER;
    wire conv_state_DONE          = conv_current_state == DONE ;

    //Flags
    wire rd_done_flag;
    wire zero_pad_done_flag;
    wire conv_done_flag;
    wire right_end_reach_flag;
    wire bottom_end_reach_flag;

    /*--------------MEMORY---------------*/
    reg[DATA_WIDTH-1:0] zero_padded_grey_image_mem[0:IMAGE_WIDTH-1][0:IMAGE_WIDTH-1];

    /*------IMAGE_ACCESS_POINTERS--------*/
    //Main frame pointers
    reg[POINTER_WIDTH-1:0] row_pointer_reg;
    reg[POINTER_WIDTH-1:0] col_pointer_reg;

    //SMA offset pointers
    reg[POINTER_WIDTH-1:0] offset_row_pointer_reg;
    reg[POINTER_WIDTH-1:0] offset_col_pointer_reg;

    /*------------------CONV_MAIN_CTR-----------------*/
    always @(posedge clk or posedge reset)
    begin
        conv_current_state <= reset ? IDLE : conv_next_state;
    end

    always @(*)
    begin
        case(conv_current_state)
            IDLE:
            begin
                conv_next_state = ready ? RD_DATA : IDLE;
                busy            = 0;
                csel            = 3'b000 ;
            end
            RD_DATA:
            begin
                conv_next_state = rd_done_flag ? ZERO_PAD_CONV : RD_DATA;
                busy            = 1;
                csel            = 3'b000 ;
            end
            ZERO_PAD_CONV:
            begin
                conv_next_state = zero_pad_done_flag ? RE_LU : ZERO_PAD_CONV;
                busy            = 1;
                csel            = 3'b000 ;
            end
            RE_LU:
            begin
                conv_next_state = WB;
                busy            = 1;
                csel            = 3'b000 ;
            end
            WB:
            begin
                conv_next_state = INCR_POINTER;
                busy            = 1;
                csel            = 3'b001 ;
            end
            INCR_POINTER:
            begin
                conv_next_state = conv_done_flag ? DONE : ZERO_PAD_CONV;
                busy            = 1;
                csel            = 3'b000 ;
            end
            DONE:
            begin
                conv_next_state = DONE;
                busy            = 1;
                csel            = 3'b000 ;
            end
            default:
            begin
                conv_next_state = IDLE;
                busy            = 1;
                csel            = 3'b000 ;
            end
        endcase
    end

    /*-----------------------RD_DATA-----------------------*/
    //Include the zero_pad 64x64 IMAGE becomes 66 x 66 IMAGE
    integer i;
    integer j;
    //Row_pointer_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            row_pointer_reg <= 'd0;
        end
        else
        begin
            case(conv_current_state)
                RD_DATA:
                begin
                    row_pointer_reg <= right_end_reach_flag ? 'd0 : row_pointer_reg + 'd1;
                end
                INCR_POINTER:
                begin
                    row_pointer_reg <= right_end_reach_flag ? 'd0 : row_pointer_reg + 'd1;
                end
                default:
                begin
                    row_pointer_reg <= row_pointer_reg;
                end
            endcase
        end
    end
    //Col_pointer_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            col_pointer_reg <= 'd0;
        end
        else
        begin
            case(conv_current_state)
                RD_DATA:
                begin
                    col_pointer_reg <= bottom_end_reach_flag ? 'd0 : col_pointer_reg + 'd1;
                end
                INCR_POINTER:
                begin
                    col_pointer_reg <= bottom_end_reach_flag ? 'd0 : col_pointer_reg + 'd1;
                end
                default:
                begin
                    col_pointer_reg <= col_pointer_reg;
                end
            endcase
        end
    end

    assign right_end_reach_flag  = (col_pointer_reg == IMAGE_WIDTH);
    assign bottom_end_reach_flag = (row_pointer_reg == IMAGE_WIDTH);

    //Zero_padded_image_mem
    always @(posedge clk or posedge reset)
    begin
        for(i = 0 ; i<IMAGE_WIDTH ; i = i+1)
            for(j = 0; j<IMAGE_WIDTH; j = j+1)
            begin
                if (reset)
                begin
                    zero_padded_grey_image_mem[i][j] <= 'd0;
                end
                else if (conv_state_RD_DATA)
                begin
                    zero_padded_grey_image_mem[row_pointer_reg][col_pointer_reg] <= idata;
                end
                else
                begin
                    zero_padded_grey_image_mem[i][j] <= zero_padded_grey_image_mem[i][j];
                end
            end
    end








endmodule
