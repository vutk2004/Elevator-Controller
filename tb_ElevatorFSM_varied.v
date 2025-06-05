`timescale 1ns/1ps

module tb_ElevatorFSM_varied;
  // DUT I/O
  reg         CLOCK_50;
  reg  [17:0] SW;
  reg  [3:0]  KEY;
  wire [6:0]  HEX0;
  wire [8:0]  LEDG;
  wire [3:0]  LEDR;

  // Instantiate
  ElevatorFSM uut (
    .CLOCK_50(CLOCK_50),
    .KEY      (KEY),
    .SW       (SW),
    .HEX0     (HEX0),
    .LEDG     (LEDG),
    .LEDR     (LEDR)
  );

  // --- timing params matching MOVE_LIMIT=50, DOOR_LIMIT=100 ---
  localparam integer CLK_HALF = 10;    // 50 MHz → half-period = 10 ns
  localparam integer MOVE_CY  = 50;
  localparam integer DOOR_CY  = 100;

  function integer time_to_floor;
    input integer floors;
    begin
      time_to_floor = (floors * MOVE_CY + DOOR_CY) * 2 * CLK_HALF;
    end
  endfunction

  // Clock gen
  initial CLOCK_50 = 0;
  always #CLK_HALF CLOCK_50 = ~CLOCK_50;

  initial begin
    // init
    SW  = 18'b0;
    KEY = 4'b1111;

    // --- Reset ---
    $display(">> Reset");
    SW[17] = 1; #100; SW[17] = 0; #100;

    // --- 1) Up: floor1 → floor4 ---
    $display(">> Case 1: external call to 4 (up)");
    SW[3] = 1; #20; SW[3] = 0;
    #(time_to_floor(3));  

    // --- 2) Down: floor4 → floor2 ---
    $display(">> Case 2: external call to 2 (down)");
    SW[1] = 1; #20; SW[1] = 0;
    #(time_to_floor(2));  

    // --- 3) Simultaneous calls above & below ---
    $display(">> Case 3: simultaneous calls to floor 1 and 3");
    // assume now at floor2
    SW[0] = 1;  // call floor1
    SW[2] = 1;  // call floor3
    #20;
    SW[0] = 0; SW[2] = 0;
    // Should go down→floor1 then up→floor3
    #((1*MOVE_CY + DOOR_CY)*2*CLK_HALF);  // to floor1 + door
    #((2*MOVE_CY + DOOR_CY)*2*CLK_HALF);  // to floor3 + door

    // --- 4) Cabin press at current floor ---
    $display(">> Case 4: cabin request at current floor opens door");
    // assume now at floor3
    KEY[2] = 0; #20; KEY[2] = 1;
    #(time_to_floor(0));  // floors=0, chỉ door

    $display(">> All tests done");
    $finish;
  end

  // waveform dump
  initial begin
    $dumpfile("tb_ElevatorFSM_varied.vcd");
    $dumpvars(0, tb_ElevatorFSM_varied);
  end

endmodule
