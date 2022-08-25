`timescale 1ns / 1ps

module ADC_Related(
//    input enable,
    input sysclk, 
    input [1:0] xa_p,
    input [1:0] xa_n,
    output led0_r,
    output led0_g,
    output led0_b,
    output reg [7:0] output_thousands = 0,
    output reg [7:0] output_hundreds = 0,
    output reg [7:0] output_tens = 0,
    output reg [7:0] output_ones = 0
    );
    
    // registers and wires
    wire ADC_enable;
    wire ready;
    reg [6:0] Address_in = 7'h1c; // the other pin is 7'h14
    wire [15:0] data;
    
    // XADC instantiation
    xadc_wiz_0 ADC (.daddr_in(Address_in),
                    .dclk_in(sysclk),
                    .den_in(ADC_enable),
                    .di_in(0),
                    .dwe_in(0),
                    .vauxp12(xa_p[1]),
                    .vauxn12(xa_n[1]),
                    .vauxp4(xa_p[0]),
                    .vauxn4(xa_n[0]),
                    .do_out(data),
                    .eoc_out(ADC_enable),
                    .drdy_out(ready));
    
    // filter out tiny noise part of the signal to achieve zero at ground
    wire [11:0] shifted_data;
    assign shifted_data = (data >> 4);
    
    // LED Indicator
    integer pwm_end = 4070;
    reg [11:0] pwm_count = 0;
    reg pwm_out = 0;

    // PWM the data to show the voltage level
    always @ (posedge sysclk) begin
        if (pwm_count < pwm_end) 
            pwm_count <= pwm_count + 1;
        else
            pwm_count = 0;
    end
    assign led0_r = ! (pwm_count < shifted_data ? 1'b1 : 1'b0);
    assign led0_g = 1; assign led0_b = 1;
    
    // Binary to Decimal conversion for Data output
    wire [3:0] Thousands, Hundreds, Tens, Ones;
    wire [14:0] bout;
    bin2bcd #(.W(12)) BCD (
        .bin(shifted_data),
        .bcd(bout)
    );

    assign Ones = bout[3:0];
    assign Tens = bout[7:4];
    assign Hundreds = bout[11:8];
    assign Thousands = bout[14:12];

    // BCD binary_to_decimal (.clk(sysclk),
    //                     .binary(shifted_data),
    //                     .Thousands(Thousands),
    //                     .Hundreds(Hundreds),
    //                     .Tens(Tens),
    //                     .Ones(Ones));
    
    // ASCII encode the BDC output
    always @ (posedge sysclk) begin
        output_thousands <= Thousands + 48;
        output_hundreds <= Hundreds + 48;
        output_tens <= Tens + 48;
        output_ones <= Ones + 48;
    end
endmodule
