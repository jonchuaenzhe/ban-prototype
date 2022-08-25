`timescale 1ns / 1ps

module ECG_Read(
    input clk,
    input Enable,
    input [8:0] Addr, // 512 addresses

    // ADC related
    input [1:0] xa_n,
    input [1:0] xa_p,

    // LED related
    output led0_r,
    output led0_g,
    output led0_b,

    // Data Output
    output reg [7:0] output_thousands = 0,
    output reg [7:0] output_hundreds = 0,
    output reg [7:0] output_tens = 0,
    output reg [7:0] output_ones = 0
);


    // initialise ADC module
    wire [7:0] ASCII_thousand, ASCII_hundred, ASCII_ten, ASCII_one;
    ADC_Related adc_related (.sysclk(clk),
                            .xa_p(xa_p),
                            .xa_n(xa_n),
                            .led0_r(led0_r),
                            .led0_g(led0_g),
                            .led0_b(led0_b),
//                            .enable(Enable),
                            .output_thousands(ASCII_thousand),
                            .output_hundreds(ASCII_hundred),
                            .output_tens(ASCII_ten),
                            .output_ones(ASCII_one));
    
    // Implement a buffer to store the ECG readings
    reg [7:0] buff_thousand [0:511];
    reg [7:0] buff_hundred [0:511];
    reg [7:0] buff_ten [0:511];
    reg [7:0] buff_one [0:511];
    
    // Counter declaration
    reg [8:0] buff_counter = 0;
    reg [20:0] counter_100hz = 0;

    always @ (posedge clk) begin
        if (Enable) begin
            // 100hz clock generation
            if (counter_100hz <= 120000) 
                counter_100hz <= counter_100hz + 1;
            else begin
                counter_100hz <= 0;
            end

            // Update RAM every 100hz
            if (counter_100hz == 0) begin
                buff_thousand[buff_counter] <= ASCII_thousand;
                buff_hundred[buff_counter] <= ASCII_hundred;
                buff_ten[buff_counter] <= ASCII_ten;
                buff_one[buff_counter] <= ASCII_one;
	 	buff_counter <= buff_counter + 1;
            end 

        end else begin
            buff_counter <= 0;

            // BRAM cannot read and write at the same time, thus when it is disable, we can start reading it
            output_thousands <= buff_thousand[Addr];
            output_hundreds <= buff_hundred[Addr];
            output_tens <= buff_ten[Addr];
            output_ones <= buff_one[Addr];
        end
    end
    

endmodule