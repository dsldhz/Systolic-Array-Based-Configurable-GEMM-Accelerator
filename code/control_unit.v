// control_unit.v
// Control unit for feeding a PxP systolic array from pre-loaded RAM buffers.

module control_unit #(
    parameter P = 8,                     
    parameter DATA_WIDTH_IN = 8,          
    parameter ADDR_WIDTH = $clog2(2 * P - 1),
    parameter MATRIX_DIM = 512
) (
    // --- System Signals ---
    input wire clk,
    input wire reset,                    
    input wire start_computation,        

    input wire [P*DATA_WIDTH_IN-1:0] q_from_buffer_a,
    input wire [P*DATA_WIDTH_IN-1:0] q_from_buffer_b,

    // --- Control Signals to PE Array ---
    output reg reset_acc,                 
    output wire [P*P-1:0] enable_mac_stream, 

    // --- Data Streams to PE Array ---
    output reg [P*DATA_WIDTH_IN-1:0] input_a_stream,
    output reg [P*DATA_WIDTH_IN-1:0] input_b_stream,

    // --- Control Signals to RAMs/Buffers ---
    output reg [ADDR_WIDTH-1:0] addr_a,  
    output reg [ADDR_WIDTH-1:0] addr_b,   
    output reg cs_a,                      
    output reg cs_b,                      
    
    output wire web_a,
    output wire web_b,

    // --- Status Signal ---
    output reg computation_done          
);

    // --- FSM State Definition ---
    localparam S_IDLE   = 2'b00;
    localparam S_STREAM = 2'b01;
    localparam S_DRAIN  = 2'b10;
    

    reg [1:0] state, next_state;

    // --- Timing Parameters ---
   
    localparam STREAM_CYCLES = 2 * P - 1;
   
    localparam DRAIN_CYCLES = P;


    reg [$clog2(STREAM_CYCLES)-1:0] stream_counter;

    reg [$clog2(DRAIN_CYCLES):0] drain_counter;


    assign web_a = 1'b1; 
    assign web_b = 1'b1; 
    
    
    assign enable_mac_stream = (state == S_STREAM || state == S_DRAIN) ? {P*P{1'b1}} : {P*P{1'b0}};


    // --- FSM State Register ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // --- FSM Next State Logic ---
    always @(*) begin
        next_state = state; 
        case (state)
            S_IDLE: begin
                if (start_computation) begin
                    next_state = S_STREAM;
                end
            end
            S_STREAM: begin
                
                if (stream_counter == STREAM_CYCLES - 1) begin
                    next_state = S_DRAIN;
                end
            end
            S_DRAIN: begin
                
                if (drain_counter == DRAIN_CYCLES - 1) begin
                    next_state = S_IDLE;
                end
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // --- Counters and Output Logic ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            
            reset_acc <= 1'b1;
            cs_a <= 1'b0;
            cs_b <= 1'b0;
            addr_a <= 0;
            addr_b <= 0;
            stream_counter <= 0;
            drain_counter <= 0;
            input_a_stream <= 0;
            input_b_stream <= 0;
            computation_done <= 1'b0;
        end else begin
            
            computation_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    reset_acc <= 1'b1; 
                    cs_a <= 1'b0;
                    cs_b <= 1'b0;
                    stream_counter <= 0; 
                    drain_counter <= 0;
                    
                    if (start_computation) begin
                        reset_acc <= 0; 
                        cs_a <= 1'b1;
                        cs_b <= 1'b1;
                        addr_a <= 0;
                        addr_b <= 0;
                    end
                end

                S_STREAM: begin
                    input_a_stream <= q_from_buffer_a;
                    input_b_stream <= q_from_buffer_b;

                    addr_a <= addr_a + 1;
                    addr_b <= addr_b + 1;
                    stream_counter <= stream_counter + 1;

                    if (stream_counter == STREAM_CYCLES - 1) begin
                        cs_a <= 1'b0;
                        cs_b <= 1'b0;
                    end
                end

                S_DRAIN: begin
                    
                    input_a_stream <= 0;
                    input_b_stream <= 0;
                    
                    
                    drain_counter <= drain_counter + 1;

                    
                    if (drain_counter == DRAIN_CYCLES - 1) begin
                        computation_done <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule