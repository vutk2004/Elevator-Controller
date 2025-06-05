`timescale 1ns/1ps

// ------------------------------------------------------------------
// Testbench: ElevatorFSM_allcases_tb.v
// Mục đích: Kết hợp tất cả các kịch bản test (A–I) vào một file duy nhất
// ------------------------------------------------------------------
module ElevatorFSM_allcases_tb;
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
  localparam integer CLK_HALF = 10;       // ns (half period of 50MHz)
  localparam integer MOVE_CY  = 50;       // cycles to move 1 floor
  localparam integer DOOR_CY  = 100;      // cycles to open/close door

  // Helper function: total ns to move N floors + door
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
    // Initialize inputs
    SW  = 18'b0;
    KEY = 4'b1111;  // active-low (1 = not pressed)

    // ------------------------------
    // Reset FSM
    // ------------------------------
    $display("=== Reset FSM ===");
    SW[17] = 1; #100;
    SW[17] = 0; #100;

    // ------------------------------
    // Case A: Simultaneous cabin(3) & external(2)
    // ------------------------------
    $display("=== CASE A: cabin(3) & external(2) from floor1 ===");
    KEY[2] = 0; SW[1] = 1; #20;
    KEY[2] = 1; SW[1] = 0;
    # (time_to_floor(2));

    // ------------------------------
    // Case B: Simultaneous external calls to 1 & 4
    // ------------------------------
    $display("=== CASE B: external calls to floor1 & floor4 ===");
    SW[0] = 1; SW[3] = 1; #20;
    SW[0] = 0; SW[3] = 0;
    // Serve floor4 then floor1
    # (time_to_floor(3) + time_to_floor(3));

    // ------------------------------
    // Case C: Cabin & external at same floor (floor2)
    // ------------------------------
    $display("=== CASE C: cabin & external at floor2 ===");
    // Move to floor2 first
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[1] = 1; #20; SW[1] = 0; # (time_to_floor(1));
    KEY[1] = 0; SW[1] = 1; #20;
    KEY[1] = 1; SW[1] = 0;
    # (time_to_floor(0));

    // ------------------------------
    // Case D: Request during MOVE (1->2 then 4)
    // ------------------------------
    $display("=== CASE D: request during MOVE to floor4 ===");
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[1] = 1; #20; SW[1] = 0;
    # (MOVE_CY*2*CLK_HALF/2);  // mid-MOVE
    SW[3] = 1; #20; SW[3] = 0;
    // complete to floor2 + door, then floor4 + door
    # (time_to_floor(1));
    # (time_to_floor(2));

    // ------------------------------
    // Case E: Request during DOOR at floor3
    // ------------------------------
    $display("=== CASE E: request during DOOR at floor3 ===");
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[2] = 1; #20; SW[2] = 0;
    # (time_to_floor(2) - DOOR_CY*2*CLK_HALF/2);
    SW[0] = 1; #20; SW[0] = 0;
    # (DOOR_CY*2*CLK_HALF/2);
    # (time_to_floor(2));

    // ------------------------------
    // Case F: Simultaneous cabin presses floors2 & 4
    // ------------------------------
    $display("=== CASE F: cabin presses 2 & 4 ===");
    SW[17] = 1; #100; SW[17] = 0; #100;
    KEY[1] = 0; KEY[3] = 0; #20;
    KEY[1] = 1; KEY[3] = 1;
    # (time_to_floor(1));
    # (time_to_floor(2));

    // ------------------------------
    // Case G: External call all floors
    // ------------------------------
    $display("=== CASE G: external call all floors ===");
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[0] = 1; SW[1] = 1; SW[2] = 1; SW[3] = 1; #20;
    SW[0] = 0; SW[1] = 0; SW[2] = 0; SW[3] = 0;
    # (time_to_floor(3));
    # (time_to_floor(3));

    // ------------------------------
    // Case H: Idle state (no requests)
    // ------------------------------
    $display("=== CASE H: idle state ===");
    #1000;

    // ------------------------------
    // Case I: Call at limits (floor1 & floor4)
    // ------------------------------
    $display("=== CASE I: calls at floor limits ===");
    // At floor1
    SW[17] = 1; #100; SW[17] = 0; #100;
    SW[0] = 1; #20; SW[0] = 0;
    # (time_to_floor(0));
    // At floor4
    SW[3] = 1; #20; SW[3] = 0;
    # (time_to_floor(3));

    $display("=== All extended tests complete ===");
    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("ElevatorFSM_allcases_tb.vcd");
    $dumpvars(0, ElevatorFSM_allcases_tb);
  end
endmodule
