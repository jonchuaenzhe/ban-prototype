`timescale 1ns / 1ps

module timer_x #(
    parameter Bit_width = 9 // default is 128, if input 1hz clock, this will roughly output around 2 minutes
)(
    input clk,
    input reset,
    
    output reg clk_out
);

    reg [Bit_width - 1 : 0] counter;
    
    initial begin
        clk_out = 0;
        counter = 0;
    end

    always @ (posedge clk) begin
        // Synchrounous reset
        if (reset) begin
            counter <= 0;
            clk_out <= 1;
        end else begin
            counter <= counter + 1;

            if (counter == 2 ** Bit_width - 1) begin
                clk_out <= ~clk_out; 
            end else begin
                clk_out <= clk_out;
            end
        end
    end

endmodule