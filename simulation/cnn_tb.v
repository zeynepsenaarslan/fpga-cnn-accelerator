`timescale 1ns / 1ps

module cnn_tb;
    reg clk;
    reg rst_n;
    reg start_btn;
    wire [6:0] hex_out;

    // Modül Ba?lant?s?
    cnn_top uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_btn(start_btn), 
        .hex_out(hex_out)
    );

    // Saat Sinyali
    always #10 clk = ~clk;

    initial begin
        clk = 0; rst_n = 1; start_btn = 1; 
        
        $display("---------------------------------------");
        $display("--- FPGA MNIST SINIFLANDIRICI TESTI ---");
        $display("---------------------------------------");
        
        #100; rst_n = 0; 
        #100; rst_n = 1; 
        
        #100; start_btn = 0; 
        #100; start_btn = 1; 
        
        $display("Islem baslatildi. Lutfen bekleyin...");
        
        // --- DÜZELTME BURADA ---
        // S_DONE art?k 38. durumda. (Eskiden 22 idi)
        wait(uut.state == 47);
        // -----------------------
        
        #100;
        
        $display("\n");
        $display("=======================================");
        $display("          ISLEM TAMAMLANDI!            ");
        $display("=======================================");
        $display(" Giris Resmi       : test_image_0_label_7 ");
        $display(" Beklenen Sonuc    : 7                    ");
        $display("---------------------------------------");
        $display(" FPGA TAHMINI      : %d                   ", uut.prediction);
        $display("=======================================");
        $display("\n");
        
        // Detayl? Skor Tablosu
        $display("--- DETAYLI SKORLAR ---");
        // RAM'den son skorlar? okuyup yazabiliriz ama ?u an prediction yeterli.
        
        $stop;
    end
endmodule
