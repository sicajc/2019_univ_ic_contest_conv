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
    output [ADDR_WIDTH-1:0] iaddr;
    output reg[ADDR_WIDTH-1:0] caddr_rd;
    output [DATA_WIDTH-1:0] cdata_wr;
    output [ADDR_WIDTH-1:0] caddr_wr;

    //CONV MAIN CTR
    parameter IDLE            = 'd0 ;
    parameter RD_DATA         = 'd1 ;
    parameter ZERO_PAD_CONV   = 'd2 ;
    parameter RE_LU           = 'd3 ;
    parameter WB              = 'd4 ;
    parameter INCR_POINTER    = 'd5 ;
    parameter L0_DONE         = 'd6 ;
    parameter MP_RD_DATA      = 'd7;
    parameter MP_CAL          = 'd8;
    parameter MP_WB           = 'd9;
    parameter L1_DONE         = 'd10;
    parameter MP_INCR_POINTER = 'd11;

    //State register
    reg[4:0] conv_current_state,conv_next_state;

    //State indicators
    //L0
    wire conv_state_IDLE          = conv_current_state == IDLE ;
    wire conv_state_RD_DATA       = conv_current_state == RD_DATA;
    wire conv_state_ZERO_PAD_CONV = conv_current_state == ZERO_PAD_CONV;
    wire conv_state_RELU          = conv_current_state == RE_LU ;
    wire conv_state_WB            = conv_current_state == WB ;
    wire conv_state_INCR_POINTER  = conv_current_state == INCR_POINTER;
    wire conv_state_L0_DONE       = conv_current_state == L0_DONE ;

    //L1
    wire max_pooling_state_MP_RD_DATA   = conv_current_state == MP_RD_DATA;
    wire max_pooling_state_MP_CAL       = conv_current_state == MP_CAL;
    wire max_pooling_state_MP_WB        = conv_current_state == MP_WB;
    wire max_pooling_state_INCR_POINTER = conv_current_state == MP_INCR_POINTER;
    wire max_pooling_state_L1_DONE      = conv_current_state == L1_DONE;

    //Flags
    //L0
    wire rd_done_flag;
    wire zero_pad_done_flag;
    wire conv_done_flag;
    wire rd_data_right_end_reach_flag;
    wire rd_data_bottom_end_reach_flag;
    wire process_image_right_end_reach_flag;
    wire process_image_bottom_end_reach_flag;
    wire whole_image_bottom_end_reach_flag;
    wire whole_image_right_end_reach_flag;

    //L1
    wire mp_rd_data_done_flag;
    wire max_pooling_done_flag;

    /*--------------MEMORY---------------*/
    reg[DATA_WIDTH-1:0] zero_padded_grey_image_mem[0:IMAGE_WIDTH-1][0:IMAGE_WIDTH-1];

    /*------IMAGE_ACCESS_POINTERS--------*/
    //Main frame pointers
    reg[POINTER_WIDTH-1:0] row_pointer_reg;
    reg[POINTER_WIDTH-1:0] col_pointer_reg;

    //SMA offset pointers
    reg[POINTER_WIDTH-1:0] offset_row_pointer_reg;
    reg[POINTER_WIDTH-1:0] offset_col_pointer_reg;

    /*----------------SMA-------------------*/
    reg signed[DATA_WIDTH-1:0] sma_input_1;
    wire signed[DATA_WIDTH-1:0] sma_input_2;
    reg signed[2*DATA_WIDTH-1:0] sma_output_reg; //Need extra bit to prevent overflow after calculating due to multiplication

    wire[3:0] kernal_addr;
    wire[POINTER_WIDTH-1:0] process_row_pointer;
    wire[POINTER_WIDTH-1:0] process_col_pointer;

    wire[DATA_WIDTH-1:0] biased_result;
    /*----------------RELU------------------*/
    reg[DATA_WIDTH-1:0] relu_result_reg;

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
                conv_next_state = conv_done_flag ? L0_DONE : ZERO_PAD_CONV;
                busy            = 1;
                csel            = 3'b000 ;
            end
            L0_DONE:
            begin
                conv_next_state = MP_RD_DATA;
                busy            = 1;
                csel            = 3'b000 ;
            end
            MP_RD_DATA:
            begin
                conv_next_state = mp_rd_data_done_flag ? MP_CAL : MP_RD_DATA;
                busy            = 1;
                csel            = 3'b001 ;
            end
            MP_CAL:
            begin
                conv_next_state = MP_WB;
                busy            = 1;
                csel            = 3'b000 ;
            end
            MP_WB:
            begin
                conv_next_state = MP_INCR_POINTER;
                busy            = 1;
                csel            = 3'b011 ;
            end
            MP_INCR_POINTER:
            begin
                conv_next_state = max_pooling_done_flag ? L1_DONE : MP_CAL;
                busy            = 1;
                csel            = 3'b000 ;
            end
            L1_DONE:
            begin
                conv_next_state = L1_DONE;
                busy            = 0;
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
                    row_pointer_reg <= rd_data_right_end_reach_flag ? 'd0 : row_pointer_reg + 'd1;
                end
                INCR_POINTER:
                begin
                    row_pointer_reg <= whole_image_bottom_end_reach_flag ? 'd0 : row_pointer_reg + 'd1;
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
                    col_pointer_reg <= rd_data_bottom_end_reach_flag ? 'd0 : col_pointer_reg + 'd1;
                end
                INCR_POINTER:
                begin
                    col_pointer_reg <= whole_image_right_end_reach_flag ? 'd0 : col_pointer_reg + 'd1;
                end
                default:
                begin
                    col_pointer_reg <= col_pointer_reg;
                end
            endcase
        end
    end

    assign rd_data_right_end_reach_flag  = (col_pointer_reg == IMAGE_WIDTH);
    assign rd_data_bottom_end_reach_flag = (row_pointer_reg == IMAGE_WIDTH);
    assign rd_data_done_flag             = rd_data_bottom_end_reach_flag;
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

    //Addr converter
    assign addr  = row_pointer_reg * IMAGE_WIDTH + col_pointer_reg;
    assign iaddr = conv_state_RD_DATA ? addr : 'z;

    /*--------------------------CONV_ZER0_PAD---------------------------*/

    //offset_row_pointer_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            offset_row_pointer_reg <= 'd0;
        end
        else if (conv_state_ZERO_PAD_CONV)
        begin
            offset_row_pointer_reg <= process_image_right_end_reach_flag ? 'd0 : offset_row_pointer_reg + 'd1;
        end
        else
        begin
            offset_row_pointer_reg <= offset_row_pointer_reg;
        end
    end
    //offset_col_pointer_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            offset_col_pointer_reg <= 'd0;
        end
        else if (conv_state_ZERO_PAD_CONV)
        begin
            offset_col_pointer_reg <= process_image_bottom_end_reach_flag ? 'd0 : offset_col_pointer_reg + 'd1;
        end
        else
        begin
            offset_col_pointer_reg <= offset_col_pointer_reg;
        end
    end

    assign process_image_bottom_end_reach_flag = (offset_row_pointer_reg == 'd3);
    assign process_image_right_end_reach_flag  = (offset_col_pointer_reg == 'd3);
    assign conv_done_flag                      = process_image_bottom_end_reach_flag;

    /*-----------------Serial_Multiplier----------------*/
    //sma_kernal_input_1
    assign kernal_addr = offset_row_pointer_reg * 3 + offset_col_pointer_reg;

    always @(*)
    begin
        case(kernal_addr)
            'd0:
            begin
                sma_input_1 = 20'h0ab9e;
            end
            'd1:
            begin
                sma_input_1 = 20'h092d5;
            end
            'd2:
            begin
                sma_input_1 = 20'h06d43;
            end
            'd3:
            begin
                sma_input_1 = 20'h01004;
            end
            'd4:
            begin
                sma_input_1 = 20'hf8f71;
            end
            'd5:
            begin
                sma_input_1 = 20'hf6e54;
            end
            'd6:
            begin
                sma_input_1 = 20'hfa6d7;
            end
            'd7:
            begin
                sma_input_1 = 20'hfc834;
            end
            'd8:
            begin
                sma_input_1 = 20'hfac19;
            end
            default:
            begin
                sma_input_1 = 20'h11111;
            end
        endcase
    end

    assign process_row_pointer = offset_row_pointer_reg + row_pointer_reg;
    assign process_col_pointer = offset_col_pointer_reg + col_pointer_reg;

    //sma input2 grey image
    assign zero_pad    = (process_row_pointer == 'd0) || (process_col_pointer == 'd0) || (process_row_pointer == 'd65) || (process_col_pointer == 'd65);
    assign sma_input_2 = zero_pad ? 'd0 : zero_padded_grey_image_mem[process_row_pointer-'d1][process_col_pointer-'d1];

    //Serial_multiplier
    always @(posedge clk)
    begin
        if (reset)
        begin
            sma_output_reg <= 'd0;
        end
        else if (conv_state_ZERO_PAD_CONV)
        begin
            sma_output_reg <= sma_input_1 * sma_input_2 + sma_output_reg ;
        end
        else
        begin
            sma_output_reg <= conv_state_INCR_POINTER ? 'd0 : sma_output_reg;
        end
    end

    assign biased_result = sma_output_reg[36:17]; //Truncated result


    /*------------------RELU----------------------*/
    always @(posedge clk or posedge clk)
    begin
        if (reset)
        begin
            relu_result_reg <= 'd0;
        end
        else if (conv_state_RELU)
        begin
            relu_result_reg <= (biased_result >= 0) ? biased_result : 'd0;
        end
        else
        begin
            relu_result_reg <= relu_result_reg;
        end
    end

    /*-------------------WB-------------------*/
    assign cdata_wr = conv_state_WB ?  relu_result_reg : 'z;
    assign caddr_wr = conv_state_WB ?  addr : 'z;

    /*---------------INCR_POINTER-------------*/
    assign whole_image_right_end_reach_flag  = (col_pointer_reg == IMAGE_WIDTH);
    assign whole_image_bottom_end_reach_flag = (row_pointer_reg == IMAGE_WIDTH);



endmodule
