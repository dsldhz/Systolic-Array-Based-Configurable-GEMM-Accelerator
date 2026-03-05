
`timescale 1ns / 1ns

`include "ram.v"
`include "accelerator.v"

module tb_accelerator;

    
    parameter P = 4;
    parameter MATRIX_DIM = 512;
    parameter DATA_WIDTH_IN = 8;
    parameter DATA_WIDTH_ACC = 32;
    localparam MAIN_RAM_A_B_ADDR_WIDTH = $clog2(MATRIX_DIM * MATRIX_DIM / P);
    localparam MAIN_RAM_A_B_DATA_WIDTH = P * DATA_WIDTH_IN;
    localparam MAIN_RAM_C_ADDR_WIDTH = $clog2(MATRIX_DIM * MATRIX_DIM / (P*P));
    localparam MAIN_RAM_C_DATA_WIDTH = P * P * DATA_WIDTH_ACC;
    localparam NUM_C_TILES = (MATRIX_DIM/P)*(MATRIX_DIM/P);

    localparam BUF_ROW_WIDTH = P * DATA_WIDTH_IN;
    localparam BUF_DEPTH = 2 * P - 1;
    localparam BUF_ADDR_WIDTH = $clog2(BUF_DEPTH);
    localparam C_BUF_DATA_WIDTH = P*P*DATA_WIDTH_ACC;


    reg clk;
    reg reset;
    reg start_global_computation;

    wire [MAIN_RAM_A_B_DATA_WIDTH-1:0] main_ram_a_q;
    wire [MAIN_RAM_A_B_ADDR_WIDTH-1:0] main_ram_a_addr;

    wire [MAIN_RAM_A_B_DATA_WIDTH-1:0] main_ram_b_q;
    wire [MAIN_RAM_A_B_ADDR_WIDTH-1:0] main_ram_b_addr;

    wire [MAIN_RAM_C_DATA_WIDTH-1:0] main_ram_c_d;
    wire [MAIN_RAM_C_ADDR_WIDTH-1:0] main_ram_c_addr;
    wire main_ram_c_we;

    wire we_to_buffer_a;
    wire we_to_buffer_b;
    wire we_to_buffer_c;

    wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_a_write;
    wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_a_read;
    wire [BUF_ROW_WIDTH-1:0] q_from_buffer_a;
    wire [BUF_ROW_WIDTH-1:0] d_to_buffer_a;

    wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_b_write;
    wire [BUF_ADDR_WIDTH-1:0] addr_to_buffer_b_read;
    wire [BUF_ROW_WIDTH-1:0] q_from_buffer_b;
    wire [BUF_ROW_WIDTH-1:0] d_to_buffer_b;

    wire skew;

    wire [C_BUF_DATA_WIDTH-1:0] q_from_buffer_c;
    wire [C_BUF_DATA_WIDTH-1:0] d_to_buffer_c;

    wire global_computation_done;

    integer file_a_b , file_c;
    integer r, c; 
    integer scan_code; 
    integer ram_addr;
    integer word_offset;

    integer tile_row;
    integer tile_col;
    integer inner_row;
    integer inner_col;

    integer tile_addr;


    integer i, j;

    
    accelerator #(
        .P(P), .MATRIX_DIM(MATRIX_DIM)
    ) uut (
        .clk(clk), .reset(reset), .start_global_computation(start_global_computation),
        .main_ram_a_q(main_ram_a_q), .main_ram_a_addr(main_ram_a_addr),
        .main_ram_b_q(main_ram_b_q), .main_ram_b_addr(main_ram_b_addr),
        .main_ram_c_d(main_ram_c_d), .main_ram_c_addr(main_ram_c_addr),
        .we_to_buffer_a(we_to_buffer_a), .we_to_buffer_b(we_to_buffer_b), .we_to_buffer_c(we_to_buffer_c),
        .addr_to_buffer_a_write(addr_to_buffer_a_write), .addr_to_buffer_a_read(addr_to_buffer_a_read),
        .d_to_buffer_a(d_to_buffer_a), .q_from_buffer_a(q_from_buffer_a),
        .addr_to_buffer_b_write(addr_to_buffer_b_write), .addr_to_buffer_b_read(addr_to_buffer_b_read),
        .d_to_buffer_b(d_to_buffer_b), .q_from_buffer_b(q_from_buffer_b),
        .skew(skew),
        .q_from_buffer_c(q_from_buffer_c), .d_to_buffer_c(d_to_buffer_c),
        .global_computation_done(global_computation_done)
    );

    ram #(
        .DATA_WIDTH(MAIN_RAM_A_B_DATA_WIDTH),
        .ADDR_WIDTH(MAIN_RAM_A_B_ADDR_WIDTH)
    ) u_ram_a (
        .clk(clk),
        .address(main_ram_a_addr), 
        .d(), 
        .q(main_ram_a_q),
        .cs(1'b1), 
        .web(1'b1) 
    );

    ram #(
        .DATA_WIDTH(MAIN_RAM_A_B_DATA_WIDTH),
        .ADDR_WIDTH(MAIN_RAM_A_B_ADDR_WIDTH)
    ) u_ram_b (
        .clk(clk),
        .address(main_ram_b_addr), 
        .d(), 
        .q(main_ram_b_q),
        .cs(1'b1), 
        .web(1'b1) 
    );

    ram #(
        .DATA_WIDTH(MAIN_RAM_C_DATA_WIDTH),
        .ADDR_WIDTH(MAIN_RAM_C_ADDR_WIDTH)
    ) u_ram_c (
        .clk(clk),
        .address(main_ram_c_addr),
        .d(d_to_buffer_c), 
        .q(q_from_buffer_c), 
        .cs(1'b1), 
        .web(~we_to_buffer_c) 
    );

    ram #(
        .DATA_WIDTH(BUF_ROW_WIDTH), .ADDR_WIDTH(BUF_ADDR_WIDTH)
    ) u_buffer_a (
        .clk(clk), .cs(1'b1), 
        .web(~we_to_buffer_a), 
        .address(skew ? addr_to_buffer_a_write : addr_to_buffer_a_read),
        .d(d_to_buffer_a),
        .q(q_from_buffer_a)
    );
    ram #(
        .DATA_WIDTH(BUF_ROW_WIDTH), .ADDR_WIDTH(BUF_ADDR_WIDTH)
    ) u_buffer_b (
        .clk(clk), .cs(1'b1), 
        .web(~we_to_buffer_b),
        .address(skew ? addr_to_buffer_b_write : addr_to_buffer_b_read),
        .d(d_to_buffer_b),
        .q(q_from_buffer_b)
    );



    reg signed [DATA_WIDTH_IN-1:0] val;
    reg dummy_char;
    reg signed [DATA_WIDTH_ACC-1:0] result_val;

    reg signed [P*DATA_WIDTH_IN-1:0] csv_line_data;

    initial begin
        clk = 0;
        forever #1 clk = ~clk; 
    end

    localparam BYTES_PER_LINE = 8;
    reg [63:0] line_buffer; 
    integer byte_count_in_line = 0;
    
    initial begin
        $dumpfile("acc.vcd");
        $dumpvars(0, tb_accelerator);

        
        $display("--- Test Start: Reading from unified input_mem.csv ---");

        
        file_a_b = $fopen("input_mem.csv", "r"); 
        if (file_a_b == 0) begin
            $display("ERROR: Could not open input_mem.csv. Please create it first.");
            $finish;
        end
        
        file_c = $fopen("result_mem.csv", "w");
        if (file_c == 0) begin
            $display("ERROR: Could not open output_c.csv for writing.");
            $finish;
        end

        $display("Loading data from input_mem.csv into RAM A and RAM B...");
        for (r = 0; r < MATRIX_DIM * MATRIX_DIM / P; r = r + 1) begin
            scan_code = $fscanf(file_a_b, "%h\n", csv_line_data); 
            for (c = 0; c < P; c = c + 1) begin
                tile_row = r / P;
                tile_col = c / P;
                inner_row = r % P;
                inner_col = c % P;

                ram_addr = tile_row * P + inner_col;
                word_offset = inner_row;

                u_ram_a.mem[ram_addr][(word_offset*DATA_WIDTH_IN) +: DATA_WIDTH_IN] = csv_line_data[((P-1-inner_col)*DATA_WIDTH_IN) +: DATA_WIDTH_IN];
            end
        end
        for (r =0; r < MATRIX_DIM * MATRIX_DIM / P; r = r + 1) begin
            scan_code = $fscanf(file_a_b, "%h\n", csv_line_data);
            for (c = 0; c < P; c = c + 1) begin
                tile_row = r / P;
                tile_col = c / P;
                inner_row = r % P;
                inner_col = c % P;

                ram_addr = tile_row * P + inner_row;
                word_offset = inner_col;

                u_ram_b.mem[ram_addr][(word_offset*DATA_WIDTH_IN) +: DATA_WIDTH_IN] = csv_line_data[((P-1-word_offset)*DATA_WIDTH_IN) +: DATA_WIDTH_IN];
            end
        end

        reset = 1;
        start_global_computation = 0;
        #22;
        reset = 0;
        #4;
        $display("T=%0t: Reset released.", $time);


        start_global_computation = 1;
        #2;
        start_global_computation = 0;
        $display("T=%0t: Start pulse issued.", $time);


        wait (global_computation_done == 1);
        $display("T=%0t: Global computation done signal received.", $time);
        

        $display("Writing result from RAM C to output_c.csv in HEX format...");
        for (r = 0; r < MATRIX_DIM; r = r + 1) begin
            for (c = 0; c < MATRIX_DIM; c = c + 1) begin

                tile_row = r / P;
                tile_col = c / P;
                inner_row = r % P;
                inner_col = c % P;

                tile_addr = tile_row * (MATRIX_DIM/P) + tile_col;
                word_offset = inner_row * P + inner_col;

                
                result_val = u_ram_c.mem[tile_addr][(word_offset*DATA_WIDTH_ACC) +: DATA_WIDTH_ACC];


                if (c < MATRIX_DIM - 1) begin
                    $fwrite(file_c, "%h,", result_val);
                end else begin
                    $fwrite(file_c, "%h\n", result_val);
                end
            end
        end
        $fclose(file_c);
        $display("Result successfully written to output_c.csv.");

        #6;
        $display("--- Test Finished ---");
        $finish;
    end
endmodule