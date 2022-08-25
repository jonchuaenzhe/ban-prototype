`timescale 1ns / 1ps

module TB();
    reg clk = 0;

    always begin
        #1 clk = ~clk;
    end

    main dut(.sysclk(clk));

endmodule