`timescale 1ns/1ps

module tb_ElevatorFSM;
  // ===== DUT I/O =====
  reg         CLOCK_50;
  reg  [17:0] SW;
  reg  [3:0]  KEY;
  wire [6:0]  HEX0;
  wire [8:0]  LEDG;
  wire [3:0]  LEDR;

  // instantiate Device Under Test
  ElevatorFSM uut (
    .CLOCK_50(CLOCK_50),
    .KEY      (KEY),
    .SW       (SW),
    .HEX0     (HEX0),
    .LEDG     (LEDG),
    .LEDR     (LEDR)
  );

  // ===== timing parameters =====
  localparam integer CLK_HALF = 10;    // ns
  localparam integer MOVE_CY  = 50;    // chu kỳ để move 1 floor
  localparam integer DOOR_CY  = 100;   // chu kỳ để open/close door

  // helper function: tính ns để move N floors rồi open door
  function integer time_to_floor;
    input integer floors;
    begin
      time_to_floor = (floors * MOVE_CY + DOOR_CY) * 2 * CLK_HALF;
    end
  endfunction

  // ===== clock generator =====
  initial CLOCK_50 = 0;
  always #CLK_HALF CLOCK_50 = ~CLOCK_50;

  initial begin
    // --- init ---
    SW  = 18'b0;
    KEY = 4'b1111;  // active-low: 1 = not pressed

    // --- 1) reset FSM via SW[17] ---
    $display(">>> Applying reset");
    SW[17] = 1;
    #100;
    SW[17] = 0;
    #100;

    // --- 2) external call: from floor1 → floor3 ---
    $display(">>> Testing external call to floor 3");
    SW[2] = 1;         // SW[2] = call floor 3
    #20;
    SW[2] = 0;
    #(time_to_floor(2));  // di chuyển 2 tầng + mở cửa

    // --- 3) internal call: from floor3 → floor4 ---
    $display(">>> Testing internal (cabin) call to floor 4");
    KEY[3] = 0;
    #20;
    KEY[3] = 1;
    #(time_to_floor(1));  // di chuyển 1 tầng + mở cửa

    // --- 4) multi-request: cabin→4 rồi external→2 ---
    $display(">>> Testing multi-request: cabin 4 then external 2");
    // assume now at floor4
    // 4.1 mở cửa lại tại floor4
    KEY[3] = 0; #20; KEY[3] = 1;
    #(time_to_floor(0));  // floors=0 → chỉ open door
    // 4.2 external call floor2
    SW[1] = 1; #20; SW[1] = 0;
    #(time_to_floor(2));  // move 2 tầng + open door

    $display(">>> Simulation complete");
    $finish;
  end

  // dump waveforms
  initial begin
    $dumpfile("tb_ElevatorFSM.vcd");
    $dumpvars(0, tb_ElevatorFSM);
  end

endmodule
