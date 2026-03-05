// central_control.v

module central_control #(
    parameter P = 4,
    parameter MATRIX_DIM = 16
)(
    input wire clk,
    input wire reset,
    input wire start_global_computation,

    // Control for Skew Logic A (Matrix X)
    output reg start_load_A,
    output reg [$clog2(MATRIX_DIM/P)-1:0] tile_row_A,
    output reg [$clog2(MATRIX_DIM/P)-1:0] tile_col_A,
    input wire load_finished_A,

    // Control for Skew Logic B (Matrix W)
    output reg start_load_B,
    output reg [$clog2(MATRIX_DIM/P)-1:0] tile_row_B,
    output reg [$clog2(MATRIX_DIM/P)-1:0] tile_col_B,
    input wire load_finished_B,

    output wire skew,

    // Control for Basic Logic (Computation)
    output reg start_computation,
    input wire computation_finished,

    output reg clear_c_buf, 
    output reg we_c_buf,      

    input wire write_back_finished_C,

    output wire global_computation_done
);


    localparam NUM_TILES = MATRIX_DIM / P;

    localparam S_IDLE              = 4'b0000;
    localparam S_INIT_K_LOOP       = 4'b0001; 
    localparam S_LOAD_A_B          = 4'b0010;
    localparam S_WAIT_LOAD         = 4'b0011;
    localparam S_COMPUTE           = 4'b0100;
    localparam S_WAIT_COMPUTE      = 4'b0101;
    localparam S_ACCUMULATE_RESULT = 4'b0110; 
    localparam S_UPDATE_K          = 4'b0111;
    localparam S_WRITE_BACK_C      = 4'b1000; 
    localparam S_WAIT_WRITE_BACK   = 4'b1001;
    localparam S_DONE              = 4'b1010;

    reg [3:0] state, next_state;


    reg [$clog2(NUM_TILES)-1:0] tile_i_cnt, tile_j_cnt, tile_k_cnt;


    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else       state <= next_state;
    end

    assign skew = (state == S_LOAD_A_B||state == S_WAIT_LOAD);


    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:              if (start_global_computation) next_state = S_INIT_K_LOOP;
            S_INIT_K_LOOP:       next_state = S_LOAD_A_B;
            S_LOAD_A_B:          next_state = S_WAIT_LOAD;
            S_WAIT_LOAD:         if (load_finished_A && load_finished_B) next_state = S_COMPUTE;
            S_COMPUTE:           next_state = S_WAIT_COMPUTE;
            S_WAIT_COMPUTE:      if (computation_finished) next_state = S_ACCUMULATE_RESULT;
            S_ACCUMULATE_RESULT: next_state = S_UPDATE_K;
            S_UPDATE_K:          if (tile_k_cnt == NUM_TILES - 1) next_state = S_WAIT_WRITE_BACK;
                                 else next_state = S_LOAD_A_B;
            S_WAIT_WRITE_BACK:   if (write_back_finished_C) begin
                                     if (tile_i_cnt == NUM_TILES-1 && tile_j_cnt == NUM_TILES-1)
                                         next_state = S_DONE;
                                     else
                                         next_state = S_INIT_K_LOOP;
                                 end
            S_DONE:              next_state = S_IDLE;
        endcase
    end


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tile_i_cnt <= 0;
            tile_j_cnt <= 0;
            tile_k_cnt <= 0;
            start_load_A <= 0;
            start_load_B <= 0;
            start_computation <= 0;
            clear_c_buf <= 0;
            we_c_buf <= 0;
        end else begin

            start_load_A <= 0;
            start_load_B <= 0;
            start_computation <= 0;
            clear_c_buf <= 0;
            we_c_buf <= 0;

            case (state) 
                S_IDLE: begin
                    if (start_global_computation) begin

                        tile_i_cnt <= 0;
                        tile_j_cnt <= 0;
                        tile_k_cnt <= 0;
                    end
                end

                S_INIT_K_LOOP: begin

                    clear_c_buf <= 1'b1;
                    we_c_buf <= 1'b1; 
                end

                S_LOAD_A_B: begin
                    
                    start_load_A <= 1'b1;
                    start_load_B <= 1'b1;
                end
                
                S_WAIT_LOAD: begin
                    if (load_finished_A && load_finished_B) begin
                        
                        start_computation <= 1'b1;
                    end
                end

                S_WAIT_COMPUTE: begin
                    if(next_state == S_ACCUMULATE_RESULT) begin 
                        we_c_buf <= 1'b1; 
                    end
                end

                S_ACCUMULATE_RESULT: begin
                    
                end

                S_UPDATE_K: begin
                    
                    tile_k_cnt <= tile_k_cnt + 1;
                end
                
                S_WRITE_BACK_C: begin
                   
                end
                
                S_WAIT_WRITE_BACK: begin
                    if (write_back_finished_C) begin
                        if (tile_i_cnt == NUM_TILES - 1 && tile_j_cnt == NUM_TILES - 1) begin
                            
                        end else if (tile_i_cnt == NUM_TILES - 1) begin
                            
                            tile_i_cnt <= 0;
                            tile_j_cnt <= tile_j_cnt + 1;
                        end else begin
                            
                            tile_i_cnt <= tile_i_cnt + 1;
                        end
                        tile_k_cnt <= 0; 
                    end
                end
            endcase
        end
    end

    
    always @(posedge clk) begin
        
        tile_row_A <= tile_i_cnt;
        tile_col_A <= tile_k_cnt;
        
        tile_row_B <= tile_k_cnt;
        tile_col_B <= tile_j_cnt;
    end

    assign global_computation_done = (state == S_DONE);

endmodule