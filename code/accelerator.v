// accelerator.v
// Top-level module connecting all components
`include "skew_logic.v"
`include "basic_logic.v"
`include "central_control.v"
`include "tile_adder.v"

module accelerator #(
    parameter P = 16,
    parameter MATRIX_DIM = 512,
    parameter DATA_WIDTH_IN = 8,
    parameter DATA_WIDTH_ACC = 32
)(
    input wire clk,
    input wire reset,
    input wire start_global_computation,

    input wire [P*DATA_WIDTH_IN-1:0] main_ram_a_q,
    output wire [$clog2(MATRIX_DIM*MATRIX_DIM/P)-1:0] main_ram_a_addr,


    input wire [P*DATA_WIDTH_IN-1:0] main_ram_b_q,
    output wire [$clog2(MATRIX_DIM*MATRIX_DIM/P)-1:0] main_ram_b_addr,

    output wire [P*P*DATA_WIDTH_ACC-1:0] main_ram_c_d,
    output wire [$clog2(MATRIX_DIM*MATRIX_DIM/(P*P))-1:0] main_ram_c_addr,

    output wire we_to_buffer_a,
    output wire we_to_buffer_b,
    output wire we_to_buffer_c,

    output wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_a_write, 
    output wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_a_read,
    output wire [BUF_ROW_WIDTH-1:0] d_to_buffer_a,
    output wire [BUF_ROW_WIDTH-1:0] q_from_buffer_a,

    
    output wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_b_write,
    output wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_b_read,
    output wire [BUF_ROW_WIDTH-1:0] q_from_buffer_b,
    output wire [BUF_ROW_WIDTH-1:0] d_to_buffer_b,

    output wire skew,

    input wire [C_BUF_DATA_WIDTH-1:0] q_from_buffer_c,
    output wire [C_BUF_DATA_WIDTH-1:0] d_to_buffer_c,


    output wire global_computation_done
);


    wire start_load_A, load_finished_A;
    wire [$clog2(MATRIX_DIM/P)-1:0] tile_row_A, tile_col_A;
    wire start_load_B, load_finished_B;
    wire [$clog2(MATRIX_DIM/P)-1:0] tile_row_B, tile_col_B;
    wire start_computation, computation_finished;
    wire start_write_back_C, write_back_finished_C; 
    wire [$clog2(2*P-1) - 1 : 0]  out_buf_col_addr;
    
    localparam BUF_ROW_WIDTH = P * DATA_WIDTH_IN;
    localparam BUF_DEPTH = 2 * P - 1;
    localparam BUF_ADDR_WIDTH = $clog2(2 * P - 1);
    localparam C_BUF_DATA_WIDTH = P*P*DATA_WIDTH_ACC;
    
    wire clear_c_buf; 

    wire [C_BUF_DATA_WIDTH-1:0] partial_product_c; 
    wire [C_BUF_DATA_WIDTH-1:0] accumulated_sum;   

    assign d_to_buffer_c = clear_c_buf ? 0 : accumulated_sum;

    tile_adder #(
        .P(P), .DATA_WIDTH_ACC(DATA_WIDTH_ACC)
    ) u_tile_adder (
        .tile_a(partial_product_c), 
        .tile_b(q_from_buffer_c),   
        .sum_tile(accumulated_sum)
    );

    // --- Instantiate Central Control ---
    central_control #(
        .P(P), .MATRIX_DIM(MATRIX_DIM)
    ) u_central_control (
        .clk(clk), .reset(reset), .start_global_computation(start_global_computation),
        .start_load_A(start_load_A), .tile_row_A(tile_row_A), .tile_col_A(tile_col_A), .load_finished_A(load_finished_A),
        .start_load_B(start_load_B), .tile_row_B(tile_row_B), .tile_col_B(tile_col_B), .load_finished_B(load_finished_B),
        .skew(skew),
        .start_computation(start_computation), 
        .computation_finished(computation_finished),
        .clear_c_buf(clear_c_buf), 
        .we_c_buf(we_to_buffer_c),   
        .write_back_finished_C(1'b1), 

        .global_computation_done(global_computation_done)
    );

    skew_logic #(
        .P(P), .DATA_WIDTH(DATA_WIDTH_IN), .MATRIX_DIM(MATRIX_DIM)
    ) u_skew_a (
        .clk(clk), .reset(reset), .start_load(start_load_A),

        .row(tile_row_A), .column(tile_col_A),

        .in_ram_q(main_ram_a_q), .in_ram_addr(main_ram_a_addr),

        .in_buf_q(q_from_buffer_a),
        .out_buf_d(d_to_buffer_a),
        .out_buf_row_addr(addr_to_buffer_a_write),
        .out_buf_col_addr(out_buf_col_addr),
        .out_buf_we(we_to_buffer_a),

        .load_finished(load_finished_A)
    );
    skew_logic #(
        .P(P), .DATA_WIDTH(DATA_WIDTH_IN), .MATRIX_DIM(MATRIX_DIM)
    ) u_skew_b (
        .clk(clk), .reset(reset), .start_load(start_load_B),

        .row(tile_row_B), .column(tile_col_B),

        .in_ram_q(main_ram_b_q), .in_ram_addr(main_ram_b_addr),

        .in_buf_q(q_from_buffer_b),
        .out_buf_d(d_to_buffer_b),
        .out_buf_row_addr(addr_to_buffer_b_write),
        .out_buf_col_addr(out_buf_col_addr),
        .out_buf_we(we_to_buffer_b),

        .load_finished(load_finished_B)
    );

    basic_logic #(
        .P(P), .MATRIX_DIM(MATRIX_DIM), .DATA_WIDTH_IN(DATA_WIDTH_IN), .DATA_WIDTH_ACC(DATA_WIDTH_ACC)
    ) u_basic_logic (
        .clk(clk), .reset(reset), .start_computation(start_computation),
        .q_from_buffer_a(q_from_buffer_a), .q_from_buffer_b(q_from_buffer_b),
        .addr_a_read(addr_to_buffer_a_read), .addr_b_read(addr_to_buffer_b_read),
        .cs_a_read(), .cs_b_read(), .web_a_read(), .web_b_read(), 
        .result_c_block(partial_product_c), 
        .computation_finished(computation_finished)
    );
    assign main_ram_c_addr = tile_row_A * (MATRIX_DIM/P) + tile_col_B;
    assign main_ram_c_d = q_from_buffer_c;
    
endmodule