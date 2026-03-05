// pe.v
module PE #(
    parameter DATA_WIDTH_IN  = 8,  
    parameter DATA_WIDTH_ACC = 32, 
    parameter MATRIX_DIM = 512
) (
    input wire clk,          
    input wire reset_acc,    
    input wire enable_mac,   
    input wire [DATA_WIDTH_IN-1:0] input_a_data,
    input wire [DATA_WIDTH_IN-1:0] input_b_data,

    output reg [DATA_WIDTH_IN-1:0] output_a_data,
    output reg [DATA_WIDTH_IN-1:0] output_b_data,

    output wire [DATA_WIDTH_ACC-1:0] final_result
);

   
    reg [DATA_WIDTH_ACC-1:0] accumulator;

    
    wire signed [DATA_WIDTH_ACC-1:0] product;


    assign product = $signed(input_a_data) * $signed(input_b_data);

    
    always @(posedge clk) begin
        if (reset_acc) begin
            
            accumulator <= {DATA_WIDTH_ACC{1'b0}}; 
            output_a_data <= {DATA_WIDTH_IN{1'b0}};
            output_b_data <= {DATA_WIDTH_IN{1'b0}};
        end else if (enable_mac) begin
            
            accumulator <= accumulator + product;

            
            output_a_data <= input_a_data;
            output_b_data <= input_b_data;
        end
       
    end
    assign final_result = accumulator;

endmodule