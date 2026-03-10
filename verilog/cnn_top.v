`timescale 1ns / 1ps

module cnn_top(
    input wire clk,       // PIN_P11 (50 MHz Clock)
    input wire rst_n,     // PIN_B8  (KEY0 - Reset)
    input wire start_btn, // PIN_A7  (KEY1 - Start)
    output wire [6:0] hex_out // PIN_C14... (HEX0 Display)
);

    // --- PARAMETRELER ---
    localparam SHIFT_CONV   = 8;
    localparam SHIFT_DENSE1 = 9;
    localparam SHIFT_DENSE2 = 8;

    // --- FSM DURUMLARI ---
    localparam S_IDLE=0, S_CONV_INIT=1, S_LOAD_ADDR=2, S_LOAD_WAIT=3, S_LOAD_READ=4;
    localparam S_CALC=5, S_WRITE_RAM=6, S_NEXT_POS=7, S_MP_INIT=8;
    localparam S_MP_READ0_A=9, S_MP_READ0_W=10, S_MP_READ0_R=11;
    localparam S_MP_READ1_A=12, S_MP_READ1_W=13, S_MP_READ1_R=14;
    localparam S_MP_READ2_A=15, S_MP_READ2_W=16, S_MP_READ2_R=17;
    localparam S_MP_READ3_A=18, S_MP_READ3_W=19, S_MP_READ3_R=20;
    localparam S_MP_WRITE=21, S_FILTER_INC=22;
    localparam S_D1_INIT=23, S_D1_BIAS_A=24, S_D1_BIAS_W=25, S_D1_BIAS_R=26;
    localparam S_D1_DATA_A=27, S_D1_DATA_W=28, S_D1_ACC=29, S_D1_WRITE=30;
    localparam S_D2_INIT=31, S_D2_BIAS_A=32, S_D2_BIAS_W=33, S_D2_BIAS_R=34;
    localparam S_D2_DATA_A=35, S_D2_DATA_W=36, S_D2_ACC=37, S_D2_WRITE=38;
    localparam S_OUT_INIT=39, S_OUT_BIAS_A=40, S_OUT_BIAS_W=41, S_OUT_BIAS_R=42;
    localparam S_OUT_DATA_A=43, S_OUT_DATA_W=44, S_OUT_ACC=45, S_OUT_CHECK=46, S_DONE=47;

    reg [5:0] state;
    reg [3:0] load_counter;
    reg [4:0] row, col;          
    reg [3:0] mp_row, mp_col;    
    reg [2:0] filter_idx;        
    reg [9:0] d_in_cnt;  
    reg [5:0] d_out_cnt; 
    reg [3:0] prediction;
    reg signed [31:0] max_score;

    wire [7:0] img_data, weight_data;
    wire [15:0] bias_data; 
    reg [7:0] window_buffer [0:8];
    reg signed [7:0] weights_buffer [0:8];
    reg signed [15:0] bias_reg;
    reg conv_start;
    wire conv_done;
    wire signed [31:0] conv_result;
    reg [9:0] rom_addr, weight_addr;
    reg [3:0] bias_addr;
    reg signed [31:0] temp_shifted;
    reg [7:0] mp_val0, mp_val1, mp_val2;
    reg [7:0] m0, m1, max_final;
    reg signed [31:0] dense_acc;
    
    // --- RAM MODULLERI (Dosya yolları sadece isim olarak ayarlandı) ---
    bram_module #(.INIT_FILE("test_image_8_label_5_hex.txt"), .DEPTH(784)) img_rom (.clk(clk), .addr(rom_addr), .we(1'b0), .din(8'b0), .dout(img_data));
    bram_module #(.INIT_FILE("conv1_weights_hex.txt"), .DEPTH(36)) weight_rom (.clk(clk), .addr(weight_addr), .we(1'b0), .din(8'b0), .dout(weight_data));
    bram_module #(.INIT_FILE("conv1_bias_hex.txt"), .DATA_WIDTH(16), .ADDR_WIDTH(4), .DEPTH(4)) bias_rom (.clk(clk), .addr(bias_addr), .we(1'b0), .din(16'b0), .dout(bias_data));

    reg [11:0] conv_ram_addr; reg conv_ram_we; reg [7:0] conv_ram_din; wire [7:0] conv_ram_dout;
    bram_module #(.DATA_WIDTH(8), .ADDR_WIDTH(12), .DEPTH(2704)) conv_mem (.clk(clk), .addr(conv_ram_addr), .we(conv_ram_we), .din(conv_ram_din), .dout(conv_ram_dout));

    reg [9:0] pool_ram_addr; reg pool_ram_we; reg [7:0] pool_ram_din; wire [7:0] pool_ram_dout;
    bram_module #(.DATA_WIDTH(8), .ADDR_WIDTH(10), .DEPTH(676)) pool_mem (.clk(clk), .addr(pool_ram_addr), .we(pool_ram_we), .din(pool_ram_din), .dout(pool_ram_dout));

    reg [5:0] d1_ram_addr; reg d1_ram_we; reg [7:0] d1_ram_din; wire [7:0] d1_ram_dout;
    bram_module #(.DATA_WIDTH(8), .ADDR_WIDTH(6), .DEPTH(32)) d1_mem (.clk(clk), .addr(d1_ram_addr), .we(d1_ram_we), .din(d1_ram_din), .dout(d1_ram_dout));

    reg [5:0] d2_ram_addr; reg d2_ram_we; reg [7:0] d2_ram_din; wire [7:0] d2_ram_dout;
    bram_module #(.DATA_WIDTH(8), .ADDR_WIDTH(6), .DEPTH(32)) d2_mem (.clk(clk), .addr(d2_ram_addr), .we(d2_ram_we), .din(d2_ram_din), .dout(d2_ram_dout));

    wire [7:0] w_d1_data; reg [14:0] w_d1_addr;
    bram_module #(.INIT_FILE("dense1_weights_hex.txt"), .DATA_WIDTH(8), .ADDR_WIDTH(15), .DEPTH(21632)) wd1_rom (.clk(clk), .addr(w_d1_addr), .we(1'b0), .din(8'b0), .dout(w_d1_data));
    wire [15:0] b_d1_data; reg [4:0] b_d1_addr;
    bram_module #(.INIT_FILE("dense1_bias_hex.txt"), .DATA_WIDTH(16), .ADDR_WIDTH(5), .DEPTH(32)) bd1_rom (.clk(clk), .addr(b_d1_addr), .we(1'b0), .din(16'b0), .dout(b_d1_data));

    wire [7:0] w_d2_data; reg [9:0] w_d2_addr;
    bram_module #(.INIT_FILE("dense2_weights_hex.txt"), .DATA_WIDTH(8), .ADDR_WIDTH(10), .DEPTH(1024)) wd2_rom (.clk(clk), .addr(w_d2_addr), .we(1'b0), .din(8'b0), .dout(w_d2_data));
    wire [15:0] b_d2_data; reg [4:0] b_d2_addr;
    bram_module #(.INIT_FILE("dense2_bias_hex.txt"), .DATA_WIDTH(16), .ADDR_WIDTH(5), .DEPTH(32)) bd2_rom (.clk(clk), .addr(b_d2_addr), .we(1'b0), .din(16'b0), .dout(b_d2_data));

    wire [7:0] w_out_data; reg [8:0] w_out_addr;
    bram_module #(.INIT_FILE("output_weights_hex.txt"), .DATA_WIDTH(8), .ADDR_WIDTH(9), .DEPTH(320)) wout_rom (.clk(clk), .addr(w_out_addr), .we(1'b0), .din(8'b0), .dout(w_out_data));
    wire [15:0] b_out_data; reg [3:0] b_out_addr;
    bram_module #(.INIT_FILE("output_bias_hex.txt"), .DATA_WIDTH(16), .ADDR_WIDTH(4), .DEPTH(10)) bout_rom (.clk(clk), .addr(b_out_addr), .we(1'b0), .din(16'b0), .dout(b_out_data));

    conv_unit processor (.clk(clk), .rst_n(rst_n), .start(conv_start),
        .p0(window_buffer[0]), .p1(window_buffer[1]), .p2(window_buffer[2]), .p3(window_buffer[3]), .p4(window_buffer[4]), .p5(window_buffer[5]),
        .p6(window_buffer[6]), .p7(window_buffer[7]), .p8(window_buffer[8]),
        .w0(weights_buffer[0]), .w1(weights_buffer[1]), .w2(weights_buffer[2]), .w3(weights_buffer[3]), .w4(weights_buffer[4]), .w5(weights_buffer[5]),
        .w6(weights_buffer[6]), .w7(weights_buffer[7]), .w8(weights_buffer[8]),
        .bias(bias_reg), .result(conv_result), .done(conv_done));

    // --- 7-SEGMENT AYARLARI (Active Low Düzeltmesi) ---
    wire [6:0] seg_active_high;
    seven_segment display(.digit(prediction), .seg(seg_active_high));
    assign hex_out = seg_active_high; // DE10-Lite için tersle (0=Yanar)

    // --- FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            row <= 0; col <= 0; mp_row <= 0; mp_col <= 0; filter_idx <= 0;
            load_counter <= 0; conv_start <= 0; conv_ram_we <= 0; pool_ram_we <= 0;
            d1_ram_we <= 0; d2_ram_we <= 0; prediction <= 10;
            dense_acc <= 0; d_in_cnt <= 0; d_out_cnt <= 0;
            b_d1_addr <= 0; b_d2_addr <= 0; b_out_addr <= 0;
        end else begin
            conv_ram_we <= 0; pool_ram_we <= 0; d1_ram_we <= 0; d2_ram_we <= 0; conv_start <= 0;
            bias_addr <= filter_idx; bias_reg <= $signed(bias_data);

            case(state)
                S_IDLE: if (!start_btn) begin state <= S_CONV_INIT; filter_idx <= 0; prediction <= 10; end
                S_CONV_INIT: begin row <= 0; col <= 0; state <= S_LOAD_ADDR; load_counter <= 0; end
                S_LOAD_ADDR: begin rom_addr <= (row + (load_counter/3))*28 + (col + (load_counter%3)); weight_addr <= (filter_idx * 9) + load_counter; state <= S_LOAD_WAIT; end
                S_LOAD_WAIT: state <= S_LOAD_READ; 
                S_LOAD_READ: begin
                    window_buffer[load_counter] <= img_data; weights_buffer[load_counter] <= $signed(weight_data);
                    if (load_counter < 8) begin load_counter <= load_counter + 1; state <= S_LOAD_ADDR; end else begin state <= S_CALC; conv_start <= 1; end
                end
                S_CALC: if (conv_done) state <= S_WRITE_RAM;
                S_WRITE_RAM: begin
                    if (conv_result[31]) temp_shifted = 0; else temp_shifted = conv_result >>> SHIFT_CONV;
                    if (temp_shifted > 127) conv_ram_din <= 127; else conv_ram_din <= temp_shifted[7:0];
                    conv_ram_addr <= (filter_idx * 676) + (row * 26) + col; conv_ram_we <= 1;
                    state <= S_NEXT_POS;
                end
                S_NEXT_POS: begin
                    if (col < 25) begin col <= col + 1; state <= S_LOAD_ADDR; load_counter <= 0; end
                    else begin col <= 0; if (row < 25) begin row <= row + 1; state <= S_LOAD_ADDR; load_counter <= 0; end else begin state <= S_MP_INIT; mp_row <= 0; mp_col <= 0; end end
                end
                S_MP_INIT: state <= S_MP_READ0_A;
                S_MP_READ0_A: begin conv_ram_addr <= (filter_idx * 676) + (2*mp_row)*26 + (2*mp_col); state <= S_MP_READ0_W; end
                S_MP_READ0_W: state <= S_MP_READ0_R; S_MP_READ0_R: begin mp_val0 <= conv_ram_dout; state <= S_MP_READ1_A; end
                S_MP_READ1_A: begin conv_ram_addr <= (filter_idx * 676) + (2*mp_row)*26 + (2*mp_col) + 1; state <= S_MP_READ1_W; end
                S_MP_READ1_W: state <= S_MP_READ1_R; S_MP_READ1_R: begin mp_val1 <= conv_ram_dout; state <= S_MP_READ2_A; end
                S_MP_READ2_A: begin conv_ram_addr <= (filter_idx * 676) + (2*mp_row + 1)*26 + (2*mp_col); state <= S_MP_READ2_W; end
                S_MP_READ2_W: state <= S_MP_READ2_R; S_MP_READ2_R: begin mp_val2 <= conv_ram_dout; state <= S_MP_READ3_A; end
                S_MP_READ3_A: begin conv_ram_addr <= (filter_idx * 676) + (2*mp_row + 1)*26 + (2*mp_col) + 1; state <= S_MP_READ3_W; end
                S_MP_READ3_W: state <= S_MP_READ3_R; S_MP_READ3_R: begin 
                    m0 = (mp_val0 > mp_val1) ? mp_val0 : mp_val1; m1 = (mp_val2 > conv_ram_dout) ? mp_val2 : conv_ram_dout;
                    max_final = (m0 > m1) ? m0 : m1; state <= S_MP_WRITE; 
                end
                S_MP_WRITE: begin
                    pool_ram_addr <= (filter_idx * 169) + (mp_row * 13) + mp_col; pool_ram_din <= max_final; pool_ram_we <= 1;
                    if (mp_col < 12) begin mp_col <= mp_col + 1; state <= S_MP_READ0_A; end else begin mp_col <= 0; if (mp_row < 12) begin mp_row <= mp_row + 1; state <= S_MP_READ0_A; end else state <= S_FILTER_INC; end
                end
                S_FILTER_INC: if (filter_idx < 3) begin filter_idx <= filter_idx + 1; state <= S_CONV_INIT; end else state <= S_D1_INIT;

                S_D1_INIT: begin d_in_cnt <= 0; d_out_cnt <= 0; b_d1_addr <= 0; state <= S_D1_BIAS_A; end
                S_D1_BIAS_A: begin b_d1_addr <= d_out_cnt; state <= S_D1_BIAS_W; end
                S_D1_BIAS_W: state <= S_D1_BIAS_R; S_D1_BIAS_R: begin dense_acc <= {{16{b_d1_data[15]}}, b_d1_data}; state <= S_D1_DATA_A; end
                S_D1_DATA_A: begin pool_ram_addr <= d_in_cnt; w_d1_addr <= (d_out_cnt * 676) + d_in_cnt; state <= S_D1_DATA_W; end
                S_D1_DATA_W: state <= S_D1_ACC;
                S_D1_ACC: begin
                    dense_acc <= dense_acc + ($signed(pool_ram_dout) * $signed(w_d1_data));
                    if (d_in_cnt < 675) begin d_in_cnt <= d_in_cnt + 1; state <= S_D1_DATA_A; end else state <= S_D1_WRITE;
                end
                S_D1_WRITE: begin
                    if (dense_acc[31]) temp_shifted = 0; else temp_shifted = dense_acc >>> SHIFT_DENSE1;
                    if (temp_shifted > 127) d1_ram_din <= 127; else d1_ram_din <= temp_shifted[7:0];
                    d1_ram_addr <= d_out_cnt; d1_ram_we <= 1;
                    if (d_out_cnt < 31) begin d_out_cnt <= d_out_cnt + 1; d_in_cnt <= 0; state <= S_D1_BIAS_A; end else state <= S_D2_INIT;
                end

                S_D2_INIT: begin d_in_cnt <= 0; d_out_cnt <= 0; b_d2_addr <= 0; state <= S_D2_BIAS_A; end
                S_D2_BIAS_A: begin b_d2_addr <= d_out_cnt; state <= S_D2_BIAS_W; end
                S_D2_BIAS_W: state <= S_D2_BIAS_R; S_D2_BIAS_R: begin dense_acc <= {{16{b_d2_data[15]}}, b_d2_data}; state <= S_D2_DATA_A; end
                S_D2_DATA_A: begin d1_ram_addr <= d_in_cnt; w_d2_addr <= (d_out_cnt * 32) + d_in_cnt; state <= S_D2_DATA_W; end
                S_D2_DATA_W: state <= S_D2_ACC;
                S_D2_ACC: begin
                    dense_acc <= dense_acc + ($signed(d1_ram_dout) * $signed(w_d2_data));
                    if (d_in_cnt < 31) begin d_in_cnt <= d_in_cnt + 1; state <= S_D2_DATA_A; end else state <= S_D2_WRITE;
                end
                S_D2_WRITE: begin
                    if (dense_acc[31]) temp_shifted = 0; else temp_shifted = dense_acc >>> SHIFT_DENSE2;
                    if (temp_shifted > 127) d2_ram_din <= 127; else d2_ram_din <= temp_shifted[7:0];
                    d2_ram_addr <= d_out_cnt; d2_ram_we <= 1;
                    if (d_out_cnt < 31) begin d_out_cnt <= d_out_cnt + 1; d_in_cnt <= 0; state <= S_D2_BIAS_A; end else state <= S_OUT_INIT;
                end

                S_OUT_INIT: begin d_in_cnt <= 0; d_out_cnt <= 0; b_out_addr <= 0; max_score <= -32'd2000000000; state <= S_OUT_BIAS_A; end
                S_OUT_BIAS_A: begin b_out_addr <= d_out_cnt; state <= S_OUT_BIAS_W; end
                S_OUT_BIAS_W: state <= S_OUT_BIAS_R; S_OUT_BIAS_R: begin dense_acc <= {{16{b_out_data[15]}}, b_out_data}; state <= S_OUT_DATA_A; end
                S_OUT_DATA_A: begin d2_ram_addr <= d_in_cnt; w_out_addr <= (d_out_cnt * 32) + d_in_cnt; state <= S_OUT_DATA_W; end
                S_OUT_DATA_W: state <= S_OUT_ACC;
                S_OUT_ACC: begin
                    dense_acc <= dense_acc + ($signed(d2_ram_dout) * $signed(w_out_data));
                    if (d_in_cnt < 31) begin d_in_cnt <= d_in_cnt + 1; state <= S_OUT_DATA_A; end else state <= S_OUT_CHECK;
                end
                S_OUT_CHECK: begin
                    if (dense_acc > max_score) begin max_score <= dense_acc; prediction <= d_out_cnt[3:0]; end
                    if (d_out_cnt < 9) begin d_out_cnt <= d_out_cnt + 1; d_in_cnt <= 0; state <= S_OUT_BIAS_A; end else state <= S_DONE;
                end
                S_DONE: ;
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule