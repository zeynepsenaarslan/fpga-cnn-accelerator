`timescale 1ns / 1ps

module conv_unit (
    input wire clk,
    input wire rst_n,             // Active low reset
    input wire start,             // İşlemi başlat sinyali
    
    // İşlenecek 9 piksel (3x3 pencere) - İşaretsiz 8-bit
    input wire [7:0] p0, p1, p2,
    input wire [7:0] p3, p4, p5,
    input wire [7:0] p6, p7, p8,
    
    // Filtre ağırlıkları (3x3 kernel) - İşaretli 8-bit!
    input wire signed [7:0] w0, w1, w2,
    input wire signed [7:0] w3, w4, w5,
    input wire signed [7:0] w6, w7, w8,
    
    input wire signed [15:0] bias, // Bias değeri
    
    output reg signed [31:0] result, // Sonuç (32-bit, Shift yapılmamış)
    output reg done                  // İşlem bitti sinyali
);

    // Ara çarpım sonuçları (16-bit işaretli) [cite: 242]
    reg signed [15:0] mult0, mult1, mult2;
    reg signed [15:0] mult3, mult4, mult5;
    reg signed [15:0] mult6, mult7, mult8;
    
    // Akümülatör (Toplayıcı) [cite: 243]
    reg signed [31:0] sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            sum <= 0;
        end else begin
            if (start) begin
                // 1. Aşama: Çarpma (Multiply)
                // Pikselleri $signed() ile işaretliye çevirmek zorundayız [cite: 240]
                // Yoksa negatif ağırlıklarla çarpım yanlış olur.
                mult0 <= $signed({1'b0, p0}) * w0;
                mult1 <= $signed({1'b0, p1}) * w1;
                mult2 <= $signed({1'b0, p2}) * w2;
                mult3 <= $signed({1'b0, p3}) * w3;
                mult4 <= $signed({1'b0, p4}) * w4;
                mult5 <= $signed({1'b0, p5}) * w5;
                mult6 <= $signed({1'b0, p6}) * w6;
                mult7 <= $signed({1'b0, p7}) * w7;
                mult8 <= $signed({1'b0, p8}) * w8;
                
                // 2. Aşama: Toplama (Accumulate) + Bias
                sum <= mult0 + mult1 + mult2 + 
                       mult3 + mult4 + mult5 + 
                       mult6 + mult7 + mult8 + bias;
                       
                // 3. Aşama: ReLU (Aktivasyon) [cite: 165]
                // Eğer toplam 0'dan küçükse 0 yap, değilse aynen aktar.
                if (sum < 0) 
                    result <= 0;
                else 
                    result <= sum;
                    
                done <= 1; // İşlem tamam
            end else begin
                done <= 0;
            end
        end
    end

endmodule