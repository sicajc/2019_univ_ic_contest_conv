`include "two_num_sorter.v"
module four_num_sorter#(parameter DATA_WIDTH)
                       (a,
                        b,
                        c,
                        d,
                        max);

    input signed [DATA_WIDTH-1:0] a;
    input signed [DATA_WIDTH-1:0] b;
    input signed [DATA_WIDTH-1:0] c;
    input signed [DATA_WIDTH-1:0] d;
    output signed [DATA_WIDTH-1:0] max;

    wire signed[DATA_WIDTH-1:0] max1_1,max2_1,min1_1,min2_1;
    wire signed[DATA_WIDTH-1:0] max1_2,min1_2;
    wire signed[DATA_WIDTH-1:0] max1_3,min1_3;

    two_num_sorter #(DATA_WIDTH) (.a(a),.b(b),.min(min1_1),.max(max1_1));
    two_num_sorter #(DATA_WIDTH) (.a(c),.b(d),.min(min2_1),.max(max2_1));

    two_num_sorter #(DATA_WIDTH) (.a(max1_1),.b(min2_1),.min(min1_2),.max(max1_2));

    two_num_sorter #(DATA_WIDTH) (.a(max2_1),.b(max1_2),.min(min1_3),.max(max1_3));

    assign max = max1_3;

endmodule
