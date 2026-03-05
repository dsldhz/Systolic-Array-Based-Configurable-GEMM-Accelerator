module skew_logic#(
    parameter P = 64,
    parameter DATA_WIDTH = 8,
    parameter MATRIX_DIM = 512,
    parameter ADDR_WIDTH = $clog2(MATRIX_DIM * MATRIX_DIM / P)
)(
    input wire clk,
    input wire reset,
    input wire start_load, 

    input wire [$clog2(MATRIX_DIM/P)-1:0] row,
    input wire [$clog2(MATRIX_DIM/P)-1:0] column, 

    input wire [P * DATA_WIDTH-1 : 0] in_ram_q,
    output reg [ADDR_WIDTH - 1 : 0] in_ram_addr,
    
    input wire [P * DATA_WIDTH-1 : 0] in_buf_q,
    output reg [P * DATA_WIDTH-1:0] out_buf_d,       
    output reg [$clog2(2*P-1)-1:0]  out_buf_row_addr, 
    output reg [$clog2(2*P-1)-1:0]  out_buf_col_addr, 
    output reg                      out_buf_we,      


    output reg load_finished 

);
    localparam S_IDLE          = 3'b001;
    localparam S_ZERO_BUFFER   = 3'b010; 
    localparam S_LOAD_SET_ADDR = 3'b011; 
    localparam S_LOAD_WRITE_BUF= 3'b100; 
    localparam S_DONE          = 3'b101;


    reg [2:0] state, next_state;
    reg [$clog2(2*P-2):0] zero_cnt;
    reg [$clog2(P):0] r_cnt, c_cnt; 
    reg [1:0] load_cnt;
    reg [P * DATA_WIDTH-1:0] in_buff;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            S_IDLE: begin
                if (start_load) begin
                    next_state = S_ZERO_BUFFER;
                end
            end
            S_ZERO_BUFFER: begin
                if (zero_cnt == (2*P-1)) begin  //0,1,...2P-2
                    next_state = S_LOAD_SET_ADDR;
                end
            end
            S_LOAD_SET_ADDR: begin
                next_state = S_LOAD_WRITE_BUF;
            end
            S_LOAD_WRITE_BUF: begin
                if (r_cnt == P-1 && c_cnt == P-1 && load_cnt == 2) begin
                    next_state = S_DONE;
                end else if(load_cnt == 3 )begin
                    next_state = S_LOAD_SET_ADDR;
                end
                else begin
                    next_state = S_LOAD_WRITE_BUF;
                end
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            
            r_cnt <= 0;
            c_cnt <= 0;
            zero_cnt <= 0;
            
            in_ram_addr <= 0;
            out_buf_d <= 0;
            out_buf_row_addr <= 0;
            out_buf_col_addr <= 0;
            out_buf_we <= 1'b0;
            load_finished <= 1'b0;
            load_cnt <= 0;
        end else begin
            
            out_buf_we <= 0;
            load_finished <= 1'b0;
            load_cnt <= 0;
            
            case(state)
                S_IDLE: begin
                    r_cnt <= 0;
                    c_cnt <= 0;
                    zero_cnt <= 0;
                end
                
                S_ZERO_BUFFER: begin
                    
                    out_buf_we <= 1'b1;
                    out_buf_d <= 0;
                    out_buf_row_addr <= zero_cnt;
                    zero_cnt <= zero_cnt + 1;
                end

                S_LOAD_SET_ADDR: begin
                    
                    in_ram_addr <= row*(MATRIX_DIM)+column*P+r_cnt;
                    out_buf_we <= 1'b0;
                    out_buf_row_addr <= r_cnt + c_cnt;
                    out_buf_col_addr <= c_cnt;
                end

                S_LOAD_WRITE_BUF: begin
                
                    if(load_cnt == 0)begin
                        in_buff <= in_buf_q;
                        load_cnt <= load_cnt + 1;
                    end
                    else if(load_cnt == 1)begin
                        in_buff[DATA_WIDTH*c_cnt] <= in_ram_q[DATA_WIDTH*c_cnt];
                        in_buff[DATA_WIDTH*c_cnt+1] <= in_ram_q[DATA_WIDTH*c_cnt+1];
                        in_buff[DATA_WIDTH*c_cnt+2] <= in_ram_q[DATA_WIDTH*c_cnt+2];
                        in_buff[DATA_WIDTH*c_cnt+3] <= in_ram_q[DATA_WIDTH*c_cnt+3];
                        in_buff[DATA_WIDTH*c_cnt+4] <= in_ram_q[DATA_WIDTH*c_cnt+4];
                        in_buff[DATA_WIDTH*c_cnt+5] <= in_ram_q[DATA_WIDTH*c_cnt+5];
                        in_buff[DATA_WIDTH*c_cnt+6] <= in_ram_q[DATA_WIDTH*c_cnt+6];
                        in_buff[DATA_WIDTH*c_cnt+7] <= in_ram_q[DATA_WIDTH*c_cnt+7];
    
                        load_cnt <= load_cnt + 1;
                        
                    end
                    else if(load_cnt == 2)begin
                        out_buf_d <= in_buff;
                        load_cnt <= load_cnt + 1;
                        out_buf_we <= 1'b1;
                    end
                    else if(load_cnt == 3)begin
                        load_cnt <= 0;
                   
                        if (c_cnt == P-1) begin
                            c_cnt <= 0;
                            r_cnt <= r_cnt + 1;
                        end else begin
                            c_cnt <= c_cnt + 1;
                        end
                    end
                    
                end
                
                S_DONE: begin
                    load_finished <= 1'b1;
                end
            endcase
        end
    end



endmodule