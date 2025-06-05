`timescale 1ns/1ps

module tb_ElevatorFSM_concurrent;
  // DUT I/O
  reg         CLOCK_50;
  reg  [17:0] SW;
  reg  [3:0]  KEY;
  wire [6:0]  HEX0;
  wire [8:0]  LEDG;
  wire [3:0]  LEDR;

  // Instantiate DUT
  ElevatorFSM uut (
    .CLOCK_50(CLOCK_50),
    .KEY      (KEY),
    .SW       (SW),
    .HEX0     (HEX0),
    .LEDG     (LEDG),
    .LEDR     (LEDR)
  );

  // timing params matching MOVE_LIMIT=50, DOOR_LIMIT=100
  localparam integer CLK_HALF = 10;  
  localparam integer MOVE_CY  = 50;  
  localparam integer DOOR_CY  = 100; 

  function integer time_to_floor;
    input integer floors;
    begin
      time_to_floor = (floors * MOVE_CY + DOOR_CY) * 2 * CLK_HALF;
    end
  endfunction

  // clock gen
  initial CLOCK_50 = 0;
  always #CLK_HALF CLOCK_50 = ~CLOCK_50;

  initial begin
    // init
    SW  = 18'b0;
    KEY = 4'b1111;

    // reset
    SW[17] = 1; #100; SW[17] = 0; #100;

    // ==== CASE A: simultaneous cabin(3) & external(2) at floor1 ====
    // ở floor1, vừa nhấn KEY[2] (cabin go to 3) vừa gạt SW[1] (external go to 2)
    $display("CASE A: simultaneous cabin(3) & external(2) from floor1");
    KEY[2] = 0;
    SW[1]  = 1;
    #20;
    KEY[2] = 1;
    SW[1]  = 0;
    // chờ đủ: sẽ đi 1→2 rồi 2→3 (tuỳ dir_up code), 
    // tuỳ logic của bạn, chờ 2 * MOVE_LIMIT + DOOR_LIMIT
    #(time_to_floor(2));

    // ==== CASE B: simultaneous external calls to both ends ====
    // ở floor C (tầng hiện tại), gọi cả floor1 và floor4 cùng lúc
    // giả sử bây giờ đã ở floor3 (HEX0 = “4”), ta gọi SW[0] & SW[3]
    $display("CASE B: simultaneous external calls to floor1 & floor4");
    // giả sử DUT đã ở floor 4, xóa requests cũ
    #10;
    SW[0] = 1; 
    SW[3] = 1;
    #20;
    SW[0] = 0;
    SW[3] = 0;
    // chờ 3 floors chuyển động + door + 3 floors trở lại + door
    // worst-case 3+3 floors:
    #(time_to_floor(3) + time_to_floor(3));

    // ==== CASE C: simultaneous cabin & external same floor ====
    // Ở floor2, vừa nhấn KEY[1] vừa gạt SW[1]
    // nên chỉ mở cửa (0 floors)
    $display("CASE C: simultaneous cabin&external at same floor (floor2)");
    // giả sử DUT đã ở floor 2
    #10;
    KEY[1] = 0;
    SW[1]  = 1;
    #20;
    KEY[1] = 1;
    SW[1]  = 0;
    // chỉ mở cửa
    #(time_to_floor(0));

    $display(">>> Concurrent tests done");
    $finish;
  end

  // dump waves
  initial begin
    $dumpfile("tb_ElevatorFSM_concurrent.vcd");
    $dumpvars(0, tb_ElevatorFSM_concurrent);
  end

endmodule
