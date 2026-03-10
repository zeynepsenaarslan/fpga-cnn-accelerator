`timescale 1ns / 1ps

module dense_unit #(
    parameter SHIFT_AMOUNT = 8 // Python çıktısından gelen değer buraya girilecek
)(
    input wire clk,
    input wire rst_n,
    
    // Kontrol Sinyalleri
    input wire start,       // Hesaplamayı başlat (Akümülatörü sıfırla)
    input wire mac_en,      // Çarp-Topla yap (Her clock vuruşunda)
    input wire bias_en,     // Bias ekle ve sonucu bitir
    
    // Veri Girişleri
    input wire signed [7:0] pixel_in,   // Önceki katmandan gelen veri
    input wire signed [7:0] weight_in,  // Ağırlık
    input wire signed [31:0] bias_in,   // O nöronun Bias değeri
    
    // Sonuç
    output reg [7:0] data_out, // 8-bit Kuantize edilmiş sonuç
    output reg done            // İşlem tamamlandı
);

    reg signed [31:0] accumulator;
    reg signed [31:0] temp_sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 0;
            data_out <= 0;
            done <= 0;
        end else begin
            // 1. Akümülatörü Başlatma
            if (start) begin
                accumulator <= 0;
                done <= 0;
            end
            
            // 2. MAC İşlemi (Multiply - Accumulate)
            // Python'daki np.dot() işleminin donanım karşılığı
            else if (mac_en) begin
                accumulator <= accumulator + ($signed(pixel_in) * $signed(weight_in));
            end
            
            // 3. Bias Ekleme + ReLU + Quantization + Clamping
            else if (bias_en) begin
                // A) Bias Ekle
                temp_sum = accumulator + bias_in;
                
                // B) ReLU (Negatifse Sıfırla)
                if (temp_sum < 0) 
                    temp_sum = 0;
                
                // C) Quantization (Bit Shifting - Sağa Kaydırma)
                // Proje föyünde belirtilen >>> işlemi
                temp_sum = temp_sum >>> SHIFT_AMOUNT;
                
                // D) Clamping (Doyuma Ulaştırma)
                // Sonuç 127'den büyükse 127'ye sabitle (8-bit signed sınırı)
                if (temp_sum > 127)
                    data_out <= 8'd127;
                else
                    data_out <= temp_sum[7:0]; // Alt 8 biti al
                    
                done <= 1;
            end
        end
    end

endmodule