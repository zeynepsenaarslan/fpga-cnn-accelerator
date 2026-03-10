module seven_segment(
    input [3:0] digit,  // Gösterilecek sayı (0-9)
    output reg [6:0] seg // a,b,c,d,e,f,g segmentleri
);
    // Active Low (0 olduğunda yanar) mantığına göre:
    always @(*) begin
        case(digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // Hepsini kapat
        endcase
    end
endmodule