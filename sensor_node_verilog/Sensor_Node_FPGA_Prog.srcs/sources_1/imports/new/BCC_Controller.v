`timescale 1ns / 1ps

module BCC_Controller(
    input clk,
    input ECG_Send_Enable,
    input Tuning_Send_Enable,
    input [7:0] output_thousands,
    input [7:0] output_hundreds,
    input [7:0] output_tens,
    input [7:0] output_ones,

    output reg [8:0] Addr,
    output reg TX_Done,

    // BCC Output
    output bcc_out
);

    // declaring out message
    reg [7:0] message [0:14];
    reg [7:0] numerals [0:9];
    initial begin
        message[0] = 32; // Space
        message[1] = 72; // H
        message[2] = 101; // e
        message[3] = 108; // l
        message[4] = 108; // l
        message[5] = 111; // o
        message[6] = 44; // ,
        message[7] = 32; // space
        message[8] = 119; // w
        message[9] = 111; // o
        message[10] = 114; // r
        message[11] = 108; // l
        message[12] = 100; // d
        message[13] = 33; // !
        message[14] = 13; // /r
        
        numerals[0] = 48;
        numerals[1] = 49;
        numerals[2] = 50;
        numerals[3] = 51;
        numerals[4] = 52;
        numerals[5] = 53;
        numerals[6] = 54;
        numerals[7] = 55;
        numerals[8] = 56;
        numerals[9] = 57;
        
    end
    // Take a pause after sending it 10 times
    reg [3:0] total_num_counter = 0;
    reg number_send = 0;
    reg [26:0] delay_counter = 0;
    reg [3:0] index = 0;

    // For ECG BCC
    reg [2:0] Decimal_index;
    reg [7:0] o_Byte;
    wire TX_Active;
    reg TX_Start;
    
    initial begin
    	Decimal_index = 0;
    	TX_Start = 0;
    end

    always @ (posedge clk) begin
        if (ECG_Send_Enable) begin
            if (TX_Active == 0 && TX_Start == 0) begin
                TX_Start <= 1;

                case (Decimal_index)
                    3'd0: o_Byte <= output_thousands;
                    3'd1: o_Byte <= output_hundreds;
                    3'd2: o_Byte <= output_tens;
                    3'd3: o_Byte <= output_ones;
                    3'd4: o_Byte <= 8'd13;

                    default: o_Byte <= 0;
                endcase

                if (Decimal_index <= 3)
                    Decimal_index <= Decimal_index + 1;
                else begin
                    Decimal_index <= 0;

                    // Address increment
                    Addr <= Addr + 1;
                end
            end else begin
                TX_Start <= 0;

                TX_Done <= (Addr == 511) ? 1 : 0;
            end
        
        end else if (Tuning_Send_Enable) begin
            if (TX_Active == 0 && TX_Start == 0 && total_num_counter < 10) begin
                if (number_send == 0) begin
                    o_Byte <= numerals[total_num_counter];
                    number_send <= 1;
                end else begin
                    o_Byte <= message[index];
                    if (index < 14) begin
                        index <= index + 1;
                    end else begin
                        index <= 0;
                        total_num_counter <= total_num_counter + 1;
                        number_send <= 0;
                    end
                end
                TX_Start <= 1;
            end else begin
                TX_Start <= 0;
                if (total_num_counter > 9)
                    if (delay_counter < 120000) // 10 Second delay
                        delay_counter <= delay_counter + 1;
                    else begin
                        total_num_counter <= 0;
                        delay_counter <= 0;
                    end
            end
            TX_Done <= 0;
        end else begin
            TX_Start <= 0;
            TX_Done <= 0;
        end
    end

    // Initialise UART
    BCC_TX BCC_out (.sysclk(clk), 
                    .i_Tx_Byte(o_Byte), 
                    .o_Tx_Serial(bcc_out), 
                    .o_Tx_Active(TX_Active), 
                    .o_Tx_Done(), 
                    .i_Tx_start(TX_Start));
endmodule