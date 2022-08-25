`timescale 1ns / 1ps

module main(
    input sysclk,
    input [1:0] btn, // state toggle
    input [1:0] xa_n,
    input [1:0] xa_p,
    input pio5, // BCP RX power good

    output reg [1:0] led,
    output led0_r,
    output led0_g,
    output led0_b,
    output uart_rxd_out, // UART
    output pio1, // BCC TX
    output pio4 // ECG power Enable
);

    // Power related
    reg ECG_PWR_Enable = 0;
    assign pio4 = ~ECG_PWR_Enable; // 1 is disable, 0 is enable

    // Initialise 1Hz clock
    wire clock_1hz;
    clk_1hz clk_1hz (sysclk, clock_1hz);

    /*
        Mode Control - one-hot encoding

        4'b0000: Start up --> No LED
        4'b0001: UART --> LED[0]
        4'b0010: Tuning ("Hello, World!") --> LED[1]
        4'b0100: BCC (only BCC) --> LED[0] & LED[1]
        4'b1000: Full Demo (BCC + BCP) --> LED Blinking (both alternate)
    */
    localparam [3:0] IDLE = 4'b0000;
    localparam [3:0] UART = 4'b0001;
    localparam [3:0] Tuning = 4'b0010;
    localparam [3:0] BCC = 4'b0100;
    localparam [3:0] Full_Demo = 4'b1000;

    reg [3:0] Mode = 0;
    
    always @ (posedge clock_1hz) begin
        if (btn[0] || btn[1]) begin // press either button will do
            case (Mode)
                IDLE: Mode <= UART;
                UART:Mode <= Tuning;
                Tuning: Mode <= BCC;
                BCC: Mode <= Full_Demo;
                default: Mode <= IDLE;
            endcase
        end
    end

    always @ (*) begin
        case (Mode)
            UART: led <= 2'b01;
            Tuning: led <= 2'b10;
            BCC: led <= 2'b11;
            Full_Demo: 
                begin
                    led[0] <= clock_1hz;
                    led[1] <= ~clock_1hz;
                end
            default: led <= 0;
        endcase
    end

    /*
        For Demo State Mode Control - one-hot encoding
        
        IDLE: 3'b000
        Delay: 3'b001
        Read_data: 3'b010
        Send_data: 3'b100
    */
    reg [2:0] Demo_Mode = 0;
    localparam [2:0] demo_IDLE = 3'b000;
    localparam [2:0] demo_Delay = 3'b001;
    localparam [2:0] demo_Read_data = 3'b010;
    localparam [2:0] demo_Send_data = 3'b100;

    reg [23:0] delay_1_seconds = 0;
    localparam [23:0] delay_1_second_total_number = 24'd12_000_000;
    
    reg [25:0] delay_3_seconds = 0;
    localparam [25:0] delay_3_second_total_number = 26'd36_000_000;
    

    reg [25:0] delay_5_seconds = 0;
    localparam [25:0] delay_5_second_total_number = 26'd60_000_000;
    
    reg [26:0] delay_10_seconds = 0;
    localparam [26:0] delay_10_second_total_number = 27'd120_000_000;

    reg [29:0] delay_1_min = 0;
    localparam [29:0] delay_1_min_total_number = 30'd720_000_000; 


    // Actual data gathering and sending
    reg Data_read_enable = 0;
    reg UART_Send_Enable = 0;
    reg BCC_Send_Enable = 0;
    reg Start_up = 0;
    wire start_up_done;
    wire UART_Send_Done;
    wire BCC_Send_Done;
    wire [8:0] Addr;
    wire [8:0] UART_Addr;
    wire [8:0] BCC_Addr;
    assign Addr = (Mode == 4'b0001) ? UART_Addr : (Mode == 4'b0100 || Mode == 4'b1000) ? BCC_Addr : 0;

    reg Tuning_Send_Enable;

    always @ (posedge sysclk) begin
        case(Mode)
            IDLE: // send start up message
                begin
                    if (~start_up_done) begin
                        UART_Send_Enable <= 1;
                        Start_up <= 1;
                    end else begin
                        UART_Send_Enable <= 0;
                        Start_up <= 0;
                    end

                    BCC_Send_Enable <= 0;
                    Data_read_enable <= 0;
                    Tuning_Send_Enable <= 0;
                    delay_5_seconds <= 0;
                    ECG_PWR_Enable <= 0;
                    Demo_Mode <= 0;
                    delay_1_seconds <= 0;
                    delay_1_min <= 0;
                end

            UART:
                begin
                    BCC_Send_Enable <= 0;
                    Tuning_Send_Enable <= 0;
                    ECG_PWR_Enable <= 0;
                    Demo_Mode <= 0;
                    delay_1_seconds <= 0;
                    delay_1_min <= 0;

                    // Data read for 5 seconds then send through UART
                    if (delay_5_seconds <= 60000000) begin
                        delay_5_seconds <= delay_5_seconds + 1;
                        Data_read_enable <= 1;
                        UART_Send_Enable <= 0;
                    end else begin
                        Data_read_enable <= 0;
                        UART_Send_Enable <= 1;

                        delay_5_seconds <= UART_Send_Done ? 0 : delay_5_seconds;
                    end
                end

            Tuning:
                begin
                    BCC_Send_Enable <= 0;
                    Data_read_enable <= 0;
                    UART_Send_Enable <= 0;
                    delay_5_seconds <= 0;
                    ECG_PWR_Enable <= 0;
                    Demo_Mode <= 0;
                    delay_1_seconds <= 0;
                    delay_1_min <= 0;

                    Tuning_Send_Enable <= 1;
                end
            BCC:
                begin
                    UART_Send_Enable <= 0;
                    Tuning_Send_Enable <= 0;
                    ECG_PWR_Enable <= 0;
                    Demo_Mode <= 0;
                    delay_1_seconds <= 0;
                    delay_1_min <= 0;

                    // Data read for 5 seconds then send through UART
                    if (delay_5_seconds <= 60000000) begin
                        delay_5_seconds <= delay_5_seconds + 1;
                        Data_read_enable <= 1;
                        BCC_Send_Enable <= 0;
                    end else begin
                        Data_read_enable <= 0;
                        BCC_Send_Enable <= 1;

                        delay_5_seconds <= BCC_Send_Done ? 0 : delay_5_seconds;
                    end
                end

            Full_Demo:
                begin

                    UART_Send_Enable <= 0;
                    Tuning_Send_Enable <= 0;

                    case (Demo_Mode)
                        demo_IDLE:
                            begin
                                delay_1_seconds <= 0;
                                BCC_Send_Enable <= 0;
                                Data_read_enable <= 0;
                                delay_5_seconds <= 0;
                                delay_1_min <= 0;
                                delay_10_seconds <= 0;
                                delay_3_seconds <= 0;

                                if (pio5) begin // if power okay
                                    Demo_Mode <= demo_Delay;
                                    ECG_PWR_Enable <= 1;
                                end else begin
                                    Demo_Mode <= demo_IDLE;
                                    ECG_PWR_Enable <= 0;
                                end
                            end
                        demo_Delay:
                            begin
//                                delay_1_seconds <= delay_1_seconds + 1;
                                ECG_PWR_Enable <= 1;
                                BCC_Send_Enable <= 0;
                                Data_read_enable <= 0;
                                delay_5_seconds <= 0;
                                delay_1_min <= 0;
                                delay_10_seconds <= 0;
                                delay_1_seconds <= 0;
//                                delay_3_seconds <= 0;
                                
                                delay_3_seconds <= delay_3_seconds + 1;

                                if (delay_3_seconds == delay_3_second_total_number) begin
                                    Demo_Mode <= demo_Read_data;
                                end else begin
                                    Demo_Mode <= demo_Delay;
                                end
                            end
                        demo_Read_data:
                            begin
                                // read data for 5 seconds
                                BCC_Send_Enable <= 0;
                                delay_1_min <= 0;

                                delay_5_seconds <= delay_5_seconds + 1;
//				delay_10_seconds <= delay_10_seconds + 1;
                                if (delay_5_seconds == delay_5_second_total_number) begin
                                    Demo_Mode <= demo_Send_data;
                                    ECG_PWR_Enable <= 0;
                                    Data_read_enable <= 0;
                                end else begin
                                    ECG_PWR_Enable <= 1;
                                    Data_read_enable <= 1;
                                end
                            end
                        demo_Send_data:
                            begin
                                // switch off ECG sensor power & stop read ECG value
                                ECG_PWR_Enable <= 0;
                                Data_read_enable <= 0;
                                BCC_Send_Enable <= 1;

                                delay_1_min <= delay_1_min + 1;

                                // continuously send data for 1 minute then switch off
                                if (delay_1_min == delay_1_min_total_number) begin
                                    Demo_Mode <= demo_IDLE;
                                end
                            end
                        default:
                            begin
                                delay_1_seconds <= 0;
                                ECG_PWR_Enable <= 0;
                                BCC_Send_Enable <= 0;
                                Data_read_enable <= 0;
                                delay_1_seconds <= 0;
                                delay_5_seconds <= 0;
                                delay_1_min <= 0;
                                
                                Demo_Mode <= demo_IDLE;
                            end
                    endcase
                end
            
            default:
                begin
                    BCC_Send_Enable <= 0;
                    Data_read_enable <= 0;
                    UART_Send_Enable <= 0;
                    delay_5_seconds <= 0;
                    Tuning_Send_Enable <= 0;
                    ECG_PWR_Enable <= 0;
                    delay_1_seconds <= 0;
                    delay_5_seconds <= 0;
                    delay_1_min <= 0;

                end

        endcase
    end

    // wires for BCD output
    wire [7:0] output_thousands;
    wire [7:0] output_hundreds;
    wire [7:0] output_tens;
    wire [7:0] output_ones;


    // UART Mode
    UART_Controller UART_Ctrl (
        .clk(sysclk),
        .Start_up(Start_up),
        .Enable(UART_Send_Enable),
        .output_thousands(output_thousands),
        .output_hundreds(output_hundreds),
        .output_tens(output_tens),
        .output_ones(output_ones),
        
        .Addr(UART_Addr),
        .start_up_done(start_up_done),
        .TX_Done(UART_Send_Done),
        .uart_rxd_out(uart_rxd_out)
    );

    // BCC Mode
    BCC_Controller BCC_Ctrl (
        .clk(sysclk),
        .ECG_Send_Enable(BCC_Send_Enable),
        .Tuning_Send_Enable(Tuning_Send_Enable),
        .output_thousands(output_thousands),
        .output_hundreds(output_hundreds),
        .output_tens(output_tens),
        .output_ones(output_ones),
        
        .Addr(BCC_Addr),
        .TX_Done(BCC_Send_Done),
        .bcc_out(pio1)
    );

    // ECG Read
    ECG_Read ECG_Read(
        .clk(sysclk),
        .Enable(Data_read_enable),
        .Addr(Addr),
        
        .xa_n(xa_n),
        .xa_p(xa_p),
        
        .led0_r(led0_r),
        .led0_g(led0_g),
        .led0_b(led0_b),

        .output_thousands(output_thousands),
        .output_hundreds(output_hundreds),
        .output_tens(output_tens),
        .output_ones(output_ones)
    );

endmodule