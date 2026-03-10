`timescale 1ns / 1ps

module maxpool_unit (
    // Conv2D çıkışından gelen 4 piksel (2x2 blok)
    input wire signed [31:0] in0,
    input wire signed [31:0] in1,
    input wire signed [31:0] in2,
    input wire signed [31:0] in3,
    
    output reg signed [31:0] val_out // En büyük değer
);

    reg signed [31:0] max0, max1;

    always @* begin
        // 1. Karşılaştırma: Üst satırdaki ikili
        if (in0 > in1) 
            max0 = in0;
        else 
            max0 = in1;
            
        // 2. Karşılaştırma: Alt satırdaki ikili
        if (in2 > in3) 
            max1 = in2;
        else 
            max1 = in3;
            
        // 3. Karşılaştırma: Final
        if (max0 > max1) 
            val_out = max0;
        else 
            val_out = max1;
    end

endmodule