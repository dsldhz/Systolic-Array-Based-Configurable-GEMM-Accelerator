// top_level.v

`include "control_unit.v"
`include "PE_array.v"
module basic_logic #(
    parameter P = 8,
    parameter MATRIX_DIM = 512,
    parameter DATA_WIDTH_IN = 8,
    parameter DATA_WIDTH_ACC = 32
)(
    input wire clk,
    input wire reset,
    input wire start_computation, 

    input wire [P*DATA_WIDTH_IN-1:0] q_from_buffer_a,
    input wire [P*DATA_WIDTH_IN-1:0] q_from_buffer_b,

    output wire [$clog2(2*P-1)-1:0] addr_a_read,
    output wire [$clog2(2*P-1)-1:0] addr_b_read,
    output wire cs_a_read,
    output wire cs_b_read,
    output wire web_a_read,
    output wire web_b_read,
    
    output wire [P*P*DATA_WIDTH_ACC-1:0] result_c_block,
    output wire                          computation_finished
);

    wire reset_acc;
    wire [P*P-1:0] enable_mac_stream;
    wire [P*DATA_WIDTH_IN-1:0] input_a_stream;
    wire [P*DATA_WIDTH_IN-1:0] input_b_stream;
    

    control_unit #(
        .P(P),
        .MATRIX_DIM(MATRIX_DIM),
        .DATA_WIDTH_IN(DATA_WIDTH_IN),
        .ADDR_WIDTH($clog2(2 * P - 1))
    ) u_control_unit (
        .clk(clk),
        .reset(reset),
        .start_computation(start_computation),
        .q_from_buffer_a(q_from_buffer_a),
        .q_from_buffer_b(q_from_buffer_b),
        .reset_acc(reset_acc),
        .enable_mac_stream(enable_mac_stream),
        .input_a_stream(input_a_stream),
        .input_b_stream(input_b_stream),
        .addr_a(addr_a_read),
        .addr_b(addr_b_read),
        .cs_a(cs_a_read),
        .cs_b(cs_b_read),
        .web_a(web_a_read),
        .web_b(web_b_read),
        .computation_done(computation_finished)
    );

    pe_array #(
        .PE_ARRAY_DIM(P),
        .DATA_WIDTH_IN(DATA_WIDTH_IN),
        .DATA_WIDTH_ACC(DATA_WIDTH_ACC),
        .MATRIX_DIM(MATRIX_DIM)
    ) u_pe_array (
        .clk(clk),
        .reset_acc(reset_acc),
        .enable_mac_stream(enable_mac_stream),
        .input_a_stream(input_a_stream),
        .input_b_stream(input_b_stream),
        .output_c_results(result_c_block)
    );

endmodule