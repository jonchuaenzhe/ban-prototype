`timescale 1ns / 1ps

module UART_Controller(
    input clk,
    input Start_up,
    input Enable,
    input [7:0] output_thousands,
    input [7:0] output_hundreds,
    input [7:0] output_tens,
    input [7:0] output_ones,

    output reg [8:0] Addr,
    output reg start_up_done,
    output reg TX_Done,

    // UART Output
    output uart_rxd_out
);

    // Start_up message
    (* ROM_STYLE="BLOCK"*) reg [7:0] start_up_message [0:19]; // ECG Sensor Started!
    initial begin
        start_up_message[0]  = 69; // E
        start_up_message[1]  = 67; // C
        start_up_message[2]  = 71; // G
        start_up_message[3]  = 32; // Space
        start_up_message[4]  = 83; // S
        start_up_message[5]  = 101; // e
        start_up_message[6]  = 110; // n
        start_up_message[7]  = 115; // s
        start_up_message[8]  = 111; // o
        start_up_message[9]  = 114; // r
        start_up_message[10] = 32; // Space
        start_up_message[11] = 83; // S
        start_up_message[12] = 116; // t
        start_up_message[13] = 97; // a
        start_up_message[14] = 114; // r
        start_up_message[15] = 116; // t
        start_up_message[16] = 101; // e
        start_up_message[17] = 100; // d
        start_up_message[18] = 33; // !
        start_up_message[19] = 13; // /r
    end
    reg [5:0] start_up_index;
    reg [2:0] Decimal_index;
    reg [7:0] o_Byte;
    wire TX_Active;
    reg TX_Start;

	initial begin 
		start_up_done =0; 
		start_up_index = 0;
		Decimal_index = 0;
		TX_Start = 0;
	end

    always @ (posedge clk) begin
        if (Start_up) begin
            if (TX_Active == 0 & TX_Start == 0) begin
                o_Byte <= start_up_message[start_up_index];

                if (start_up_index < 20) begin
                    start_up_index <= start_up_index + 1;
                    TX_Start <= 1;
                end else
                    start_up_done <= 1;
            end else begin
            	TX_Start <= 0;	
            end
            TX_Done <= 0;
        end else if (Enable) begin
            if (TX_Active == 0 && TX_Start == 0) begin
                TX_Start <= 1;

                case (Decimal_index)
                    3'd0: o_Byte <= output_thousands;
                    3'd1: o_Byte <= output_hundreds;
                    3'd2: o_Byte <= output_tens;
                    3'd3: o_Byte <= output_ones;
                    3'd4: o_Byte <= start_up_message[19];

                    default: o_Byte <= 0;
                endcase

                if (Decimal_index <= 3)
                    Decimal_index <= Decimal_index + 1;
                else begin
                    Decimal_index <= 0;

                    // Address increment
                    Addr <= Addr + 1;
                end

                TX_Done <= 0;
            end else begin
                TX_Start <= 0;

                TX_Done <= (Addr == 511) ? 1 : 0;
            end
        end else begin
            TX_Start <= 0;
            TX_Done <= 0;
        end
    end

    // Initialise UART
    UART_TX tx_out (.sysclk(clk), 
                   .i_Tx_Byte(o_Byte), 
                   .o_Tx_Serial(uart_rxd_out), 
                   .o_Tx_Active(TX_Active), 
                   .o_Tx_Done(), 
                   .i_Tx_start(TX_Start));
endmodule