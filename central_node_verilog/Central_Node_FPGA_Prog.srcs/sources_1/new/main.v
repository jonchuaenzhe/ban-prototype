`timescale 1ns / 1ps

module main(
    input sysclk, 
    input [1:0] btn,
    input pio1, // BCC RX Data Read pin

    output uart_rxd_out,
    output [1:0] led,
    output pio2 // BCP TX Enable
);
    /*
        Mode Control:
            1'b0: Receiving Mode --> Transmit whatever BCC RX receives to UART
            1'b1: Demo Mode --> 2 minutes BCP transmission, 2 minutes receiving 

            TBH, it is always receiving, the AFE will always try to demodulate the data, 
            but we can choose to send the data or not.
            
            Thus, by "receiving", I mean sending the received data through UART to PC
    */
    reg Mode = 0; 

    // Get a 1hz clock
    wire clock_1hz;
    clk_1hz clk_1hz (sysclk, clock_1hz);

    // Single LED means in receiving mode, else double LED to show it is in Demo Mode
    assign led = (Mode == 0) ? 2'b01 : 2'b11;

    // UART
    wire TX_Active, TX_Done;
    reg TX_Start = 0;
    reg [7:0] o_Byte = 0;
    UART_TX tx_out (.sysclk(sysclk), .i_Tx_Byte(o_Byte), 
                    .o_Tx_Serial(uart_rxd_out), .o_Tx_Active(TX_Active), 
                    .o_Tx_Done(TX_Done), .i_Tx_start(TX_Start));

    // BCC RX related
    wire rx_ready;
    wire [7:0] received_byte;
    RX_Demodulator RX (.i_Clock(sysclk), .i_Rx_Serial(pio1), .o_Rx_DV(rx_ready), .o_Rx_Byte(received_byte));

    // BCP TX Related
    reg BCP_TX_Enable = 0;
    assign pio2 = BCP_TX_Enable;

    // X minutes timer;
    wire X_timer_out;
    reg reset = 0;
    timer_x timer_2_min (clock_1hz, reset, X_timer_out);

    // Start up message
    reg [7:0] start_up_message [0:11]; // RX Started!
    initial begin
        start_up_message[0] = 82; // R
        start_up_message[1] = 88; // X
        start_up_message[2] = 32; // Space
        start_up_message[3] = 83; // S
        start_up_message[4] = 116; // t
        start_up_message[5] = 97; // a
        start_up_message[6] = 114; // r
        start_up_message[7] = 116; // t
        start_up_message[8] = 101; // e
        start_up_message[9] = 100; // d
        start_up_message[10] = 33; // !
        start_up_message[11] = 13; // /r
    end

    reg [3:0] start_up_index = 0;
    reg start_msg_send = 0;


    // State toggle
    always @ (posedge clock_1hz) begin
        if (btn[0]) begin
            Mode <= 1;
            // Enable the reset for X_Timer for one cycle
            reset <= 1;
        end else if (btn[1]) begin
            Mode <= 0;
            reset <= 0;
        end else begin
            reset <= 0;
        end
    end

    // FSM state stuff
    always @ (posedge sysclk) begin
        case (Mode)
            1'b0: // pure receiving mode
                begin
                    // Disable BCP TX
                    BCP_TX_Enable <= 0;

                    // Send BCC RX data to UART
                    if (TX_Active == 0 && TX_Start == 0) begin
                        // Send start_up message first
                        if (!start_msg_send) begin
                            o_Byte <= start_up_message[start_up_index];
                            TX_Start <= 1;

                            start_up_index <= (start_up_index < 11) ? start_up_index + 1 : start_up_index;
                            start_msg_send <= (start_up_index == 11) ? 1 : 0; // move the start_msg_send to 1 after we sent --> Infer latch for this
                        end else if (rx_ready) begin
                            o_Byte <= received_byte;
                            TX_Start <= 1;
                        end
                    end else begin
                        TX_Start <= 0;
                    end
                end 
            1'b1: // Demo Mode
                begin
                    if (X_timer_out) begin
                        // Enable BCP TX
                        BCP_TX_Enable <= 1;

                        // Reset BCC UART output
                        TX_Start <= 0;
                        o_Byte <= 0;
                    end else begin
                        // Disable BCP TX
                        BCP_TX_Enable <= 0;

                        // Enable Data reading and sending to UART from BCC RX
                        if (TX_Active == 0 && TX_Start == 0) begin
                            if (rx_ready) begin
                                o_Byte <= received_byte;
                                TX_Start <= 1;
                            end
                        end else begin
                            TX_Start <= 0;
                        end
                    end
                end
            default: // shouldn't even have this state but just in case
                begin
                    o_Byte <= 0;
                    TX_Start <= 0;
                end
        endcase
    end

endmodule