// pe_array.v

`include "PE.v"
module pe_array #(
    parameter PE_ARRAY_DIM = 8, 
    parameter MATRIX_DIM = 512,
    parameter DATA_WIDTH_IN  = 8,  
    parameter DATA_WIDTH_ACC = 32  
) (
    
    input wire clk,          
    input wire reset_acc,    
    
    
    input wire [PE_ARRAY_DIM*PE_ARRAY_DIM-1:0] enable_mac_stream,

    
    input wire [PE_ARRAY_DIM*DATA_WIDTH_IN-1:0] input_a_stream,
    
    input wire [PE_ARRAY_DIM*DATA_WIDTH_IN-1:0] input_b_stream,

    
    output wire [PE_ARRAY_DIM*PE_ARRAY_DIM*DATA_WIDTH_ACC-1:0] output_c_results
);

    
    localparam NUM_PES = PE_ARRAY_DIM * PE_ARRAY_DIM;

    
    wire [DATA_WIDTH_IN-1:0] a_internal [NUM_PES-1:0];
    wire [DATA_WIDTH_IN-1:0] b_internal [NUM_PES-1:0];

    
    wire [DATA_WIDTH_IN-1:0] a_out_interm [NUM_PES-1:0];
    wire [DATA_WIDTH_IN-1:0] b_out_interm [NUM_PES-1:0];

    
    wire [DATA_WIDTH_ACC-1:0] c_results_internal [NUM_PES-1:0];

    

    generate 
        genvar r, c;
        for (r = 0; r < PE_ARRAY_DIM; r = r + 1) begin : row_gen
            for (c = 0; c < PE_ARRAY_DIM; c = c + 1) begin : col_gen

                
                localparam pe_idx_1d = r * PE_ARRAY_DIM + c;

                
                if (c == 0) begin 
                    
                    assign a_internal[pe_idx_1d] = input_a_stream[(r+1)*DATA_WIDTH_IN - 1 : r*DATA_WIDTH_IN];
                end else begin 
                   
                    assign a_internal[pe_idx_1d] = a_out_interm[r * PE_ARRAY_DIM + (c-1)];
                end

                
                if (r == 0) begin 
                   
                    assign b_internal[pe_idx_1d] = input_b_stream[(c+1)*DATA_WIDTH_IN - 1 : c*DATA_WIDTH_IN];
                end else begin 
                   
                     assign b_internal[pe_idx_1d] = b_out_interm[(r-1) * PE_ARRAY_DIM + c];
                end

                
                PE #( 
                    .DATA_WIDTH_IN(DATA_WIDTH_IN),
                    .DATA_WIDTH_ACC(DATA_WIDTH_ACC),
                    .MATRIX_DIM(MATRIX_DIM)
                ) u_pe (
                    .clk(clk),
                    .reset_acc(reset_acc),     
                    
                    .enable_mac(enable_mac_stream[pe_idx_1d]),
                    
                    .input_a_data(a_internal[pe_idx_1d]), 
                    .input_b_data(b_internal[pe_idx_1d]), 
                    .output_a_data(a_out_interm[pe_idx_1d]), 
                    .output_b_data(b_out_interm[pe_idx_1d]),
                    .final_result(c_results_internal[pe_idx_1d]) 
                );

            end 
        end 
    endgenerate 

    generate
        genvar i;
        for (i = 0; i < NUM_PES; i = i + 1) begin : collect_results
            assign output_c_results[i * DATA_WIDTH_ACC + DATA_WIDTH_ACC - 1 : i * DATA_WIDTH_ACC] = c_results_internal[i];
        end
    endgenerate

endmodule