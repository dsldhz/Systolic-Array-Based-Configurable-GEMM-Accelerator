// tile_adder.v

module tile_adder #(
    parameter P = 4,
    parameter DATA_WIDTH_ACC = 32
)(
    input wire [P*P*DATA_WIDTH_ACC-1:0] tile_a,
    input wire [P*P*DATA_WIDTH_ACC-1:0] tile_b,
    output wire [P*P*DATA_WIDTH_ACC-1:0] sum_tile
);


    generate
        genvar i;
        for (i = 0; i < P*P; i = i + 1) begin : adder_loop
            localparam start_bit = i * DATA_WIDTH_ACC;
            localparam end_bit = start_bit + DATA_WIDTH_ACC - 1;
            
            assign sum_tile[end_bit:start_bit] = tile_a[end_bit:start_bit] + tile_b[end_bit:start_bit];
        end
    endgenerate

endmodule