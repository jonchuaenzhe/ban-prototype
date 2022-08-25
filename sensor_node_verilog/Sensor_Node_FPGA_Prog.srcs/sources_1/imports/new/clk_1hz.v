`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.07.2021 16:01:04
// Design Name: 
// Module Name: clk_1hz
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clk_1hz(
    input sysclk,
    output reg clk_1hz = 0
    );
    
    reg [22:0] counter = 0;
    
    always @ (posedge sysclk) begin
        if (counter < 5999999) begin
            counter <= counter + 1;
        end else begin
            counter <= 0;
            clk_1hz <= ~clk_1hz;
        end
    end
endmodule
