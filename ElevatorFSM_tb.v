// File: ElevatorFSM_tb.v
`timescale 1ns/1ps

module ElevatorFSM_tb;
    reg         clk = 0;
    reg  [3:0]  KEY = 4'b1111;
    reg  [3:0]  SW  = 4'b0000;
    wire [6:0]  HEX0;
    wire [8:0]  LEDG;
    wire [3:0]  LEDR;

    // clock: 20ns period
    always #10 clk = ~clk;

    // instantiate DUT
    ElevatorFSM uut (
        .CLOCK_50(clk),
        .KEY    (KEY),
        .SW     (SW),
        .HEX0   (HEX0),
        .LEDG   (LEDG),
        .LEDR   (LEDR)
    );

    // print header once
    initial begin
        $display(" Time | State | Floor | Pend | Door Up Dn | HEX LEDR");
        $display("-----+-------+-------+------+------+----+-------");
    end

    // monitor all changes on DUT
    always @(posedge clk) begin
        $display("%4d  |   %b   |   %0d   |  %b  |   %b   %b   %b | %b  %b",
            $time/1,               // in ns
            uut.state,             // FSM state
            uut.floor,             // current floor
            uut.pending,           // pending requests
            uut.led_door,          // door open
            uut.led_up,            // moving up
            uut.led_dn,            // moving down
            HEX0,                  // 7-seg
            LEDR                   // LEDR
        );
    end

    // stimulus
    initial begin
        #100;
        $display("\n>> CALL ext floor 3");
        SW[2] = 1; #20; SW[2] = 0;
        // wait enough cycles: (2 floors × 50 + door 100)
        repeat(200) @(posedge clk);

        $display("\n>> CABIN select floor 1");
        KEY[0] = 0; @(posedge clk); KEY[0] = 1;
        repeat(200) @(posedge clk);

        $display("\n>> CALL ext floors 4 & 2");
        SW[3] = 1; SW[1] = 1; @(posedge clk);
        SW[3] = 0; SW[1] = 0;
        // wait (3×50 +100 +2×50 +100)
        repeat(400) @(posedge clk);

        $display("\n>> SIMULATION COMPLETE @%0t\n", $time);
        $finish;
    end
endmodule
