`timescale 1ns/1ps

module tb_ElevatorFSM_extended;
  // DUT I/O
  reg         CLOCK_50;
  reg  [17:0] SW;
  reg  [3:0]  KEY;
  wire [6:0]  HEX0;
  wire [8:0]  LEDG;
  wire [3:0]  LEDR;

  // Instantiate Elevator FSM
  ElevatorFSM uut (
    .CLOCK_50(CLOCK_50),
    .KEY      (KEY),
    .SW       (SW),
    .HEX0     (HEX0),
    .LEDG     (LEDG),
    .LEDR     (LEDR)
  );

  // Timing parameters (MOVE_LIMIT=50, DOOR_LIMIT=100)
  localparam integer CLK_HALF = 10;       // ns for half period (50MHz)
  localparam integer MOVE_CY  = 50;       // cycles to move 1 floor
  localparam integer DOOR_CY  = 100;      // cycles to open/close door
  localparam integer MOVE_NS  = MOVE_CY*2*CLK_HALF;
  localparam integer DOOR_NS  = DOOR_CY*2*CLK_HALF;

  // helper: total ns to move N floors and open door
  function integer time_to_floor;
    input integer floors;
    begin
      time_to_floor = (floors * MOVE_CY + DOOR_CY) * 2 * CLK_HALF;
    end
  endfunction

  // Clock generation: 50 MHz
  initial CLOCK_50 = 0;
  always #CLK_HALF CLOCK_50 = ~CLOCK_50;

  initial begin
    // Initialize
    SW  = 18'b0;
    KEY = 4'b1111;  // active-low

    // Reset FSM
    $display(">>> Reset FSM");
    SW[17] = 1; #100; SW[17] = 0; #100;

    // Case A: simultaneous cabin(3) & external(2) from floor 1
    $display(">>> CASE A: simultaneous cabin(3) & external(2)");
    KEY[2] = 0; SW[1] = 1; #20;
    KEY[2] = 1; SW[1] = 0;
    # (time_to_floor(2));

    // Case B: simultaneous external calls to floor1 & floor4
    $display(">>> CASE B: simultaneous external calls 1 & 4");
    SW[0] = 1; SW[3] = 1; #20;
    SW[0] = 0; SW[3] = 0;
    # (MOVE_NS + DOOR_NS + 3*MOVE_NS + DOOR_NS);

    // Case C: cabin & external same floor (floor2)
    $display(">>> CASE C: cabin & external at same floor2");
    // move to floor2 first
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[1] = 1; #20; SW[1] = 0; # (time_to_floor(1));
    KEY[1] = 0; SW[1] = 1; #20;
    KEY[1] = 1; SW[1] = 0;
    # (time_to_floor(0));

    // Case D: request to floor4 during move from 1->2
    $display(">>> CASE D: request during MOVE (floor2 then 4)");
    // reset to floor1
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[1] = 1; #20; SW[1] = 0;
    # (MOVE_NS/2);
    SW[3] = 1; #20; SW[3] = 0;
    # (time_to_floor(1));
    # (time_to_floor(2));

    // Case E: request to floor1 during DOOR at floor3
    $display(">>> CASE E: request during DOOR at floor3");
    // reset and go to floor3
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[2] = 1; #20; SW[2] = 0;
    # (time_to_floor(2) - DOOR_NS);
    # (DOOR_NS/2);
    SW[0] = 1; #20; SW[0] = 0;
    # (DOOR_NS/2);
    # (time_to_floor(2));

    // Case F: simultaneous cabin presses floors2 &4 from floor1
    $display(">>> CASE F: cabin press floors2 &4 simultaneously");
    SW[17] = 1; #100; SW[17] = 0; #100;
    KEY[1] = 0; KEY[3] = 0; #20;
    KEY[1] = 1; KEY[3] = 1;
    # (time_to_floor(1));
    # (time_to_floor(2));

    // Case G: external call all floors from floor1
    $display(">>> CASE G: external call all floors");
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[0] = 1; SW[1] = 1; SW[2] = 1; SW[3] = 1; #20;
    SW[0] = 0; SW[1] = 0; SW[2] = 0; SW[3] = 0;
    # (time_to_floor(3));
    # (time_to_floor(3));

    // Case H: idle state
    $display(">>> CASE H: idle state");
    #1000;

    // Case I: call at limits
    $display(">>> CASE I: call at limits");
    // floor1 limit
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[0] = 1; #20; SW[0] = 0;
    # (time_to_floor(0));
    // floor4 limit
    SW[3] = 1; #20; SW[3] = 0;
    # (time_to_floor(3));

    $display(">>> Extended tests complete");
    $finish;
  end

  // dump waveforms
  initial begin
    $dumpfile("tb_ElevatorFSM_extended.vcd");
    $dumpvars(0, tb_ElevatorFSM_extended);
  end
endmodule
