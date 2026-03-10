`timescale 1ns / 1ps

module bram_module #(
    parameter INIT_FILE = "", 
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire we,
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);

    // Quartus'un RAM'i doğru tanıması için bu stili kullanması daha iyidir
    (* ramstyle = "M9K" *) reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    
    integer i;

    initial begin
        dout = 0;

        // --- DEĞİŞİKLİK BURADA ---
        // Sentez (Quartus) sırasında 21.000 döngü hataya sebep olur.
        // Gerçek donanımda BRAM zaten başlatılır ve readmemh üzerine yazar.
        // Bu yüzden bu döngüyü kapatıyoruz:
        
        /* for (i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = 0;
        end
        */

        // Dosya varsa yükle (Bu kısım donanım sentezinde .mif dosyasına dönüşür)
        if (INIT_FILE != "") begin
            // Quartus synthesis ekranında bu mesaj görünmeyebilir ama işlem yapılır
            $readmemh(INIT_FILE, ram);
        end
    end

    always @(posedge clk) begin
        if (we) begin
            ram[addr] <= din;
            dout <= din; 
        end else begin
            dout <= ram[addr];
        end
    end

endmodule
