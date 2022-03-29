module two_num_sorter#(parameter DATA_WIDTH)
                      (a,
                       b,
                       min,
                       max);

    input signed[DATA_WIDTH-1:0] a;
    input signed[DATA_WIDTH-1:0]b;
    output signed[DATA_WIDTH-1:0] min;
    output signed[DATA_WIDTH-1:0] max;

    assign max = a > b ? a : b;
    assign min = a < b ? a : b;

endmodule
