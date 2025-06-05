module ElevatorFSM(
    input  wire        CLOCK_50,      // 50 MHz clock
    input  wire [3:0]  KEY,           // cabin buttons (active-low)
    input  wire [17:0] SW,            // SW[0..3]=ext up calls, SW[8..11]=ext down calls
                                      // SW[17]=reset, SW[4]=emergency, SW[5]=overload, SW[6]=door hold
    output wire [6:0]  HEX0,          // 7-seg floor display
    output wire [8:0]  LEDG,          // [0]=door, [1]=up, [2]=down, [3]=overload
    output wire [3:0]  LEDR           // pending indicators
);

    // Controls
    wire reset_n    = ~SW[17];
    wire emergency  = SW[4];
    wire overload   = SW[5];
    wire door_hold  = SW[6];

    // Floor range
    localparam [1:0] FLOOR_MIN = 2'd0, FLOOR_MAX = 2'd3;

    // FSM states
    localparam [1:0] S_IDLE = 2'd0, S_MOVE = 2'd1, S_DOOR = 2'd2;

    // Timing
    localparam [26:0] MOVE_LIMIT = 27'd50000000,
                      DOOR_LIMIT = 27'd100000000;

    // ===== registers & wires =====
    reg  [1:0]  state, floor;
    reg         dir_up, dir_locked;
    reg  [26:0] timer;

    // LEDs indicators
    reg         led_door;
    reg         led_up;
    reg         led_dn;

    // Request queues & next-state copies
    reg  [3:0]  cabin_req,    next_cabin_req;
    reg  [3:0]  ext_up_req,   next_ext_up_req;
    reg  [3:0]  ext_dn_req,   next_ext_dn_req;
    wire [3:0]  ext_any  = ext_up_req | ext_dn_req;
    wire [3:0]  pending  = cabin_req | ext_any;

    // Helpers for above/below
    wire cabin_above = (floor < FLOOR_MAX) && |(cabin_req >> (floor+1));
    wire cabin_below = (floor > FLOOR_MIN) && |(cabin_req & ((1<<floor)-1));
    wire ext_above   = (floor < FLOOR_MAX) && |(ext_any   >> (floor+1));
    wire ext_below   = (floor > FLOOR_MIN) && |(ext_any   & ((1<<floor)-1));

    // ===== Main FSM with Emergency & Overload Override =====
    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            // Reset tất cả
            state        <= S_IDLE;
            floor        <= FLOOR_MIN;
            dir_up       <= 1'b0;
            dir_locked   <= 1'b0;
            timer        <= 27'd0;
            cabin_req    <= 4'd0;
            ext_up_req   <= 4'd0;
            ext_dn_req   <= 4'd0;
            led_door     <= 1'b0;
            led_up       <= 1'b0;
            led_dn       <= 1'b0;
        end
        else if (emergency) begin
            // Emergency: dừng ngay tại tầng hiện tại
            state      <= S_IDLE;
            timer      <= 27'd0;
            led_up     <= 1'b0;
            led_dn     <= 1'b0;
            led_door   <= 1'b0;
        end
        else if (overload && (state == S_IDLE || state == S_DOOR)) begin
            // Overload trong trạng thái chờ hoặc mở cửa
            state      <= S_DOOR;
            timer      <= 27'd0;
            led_door   <= 1'b1;
            led_up     <= 1'b0;
            led_dn     <= 1'b0;
        end
        else begin
            // --- Latch new requests ---
            next_cabin_req  = cabin_req   | ~KEY;
            next_ext_up_req = ext_up_req  | SW[3:0];
            next_ext_dn_req = ext_dn_req  | SW[11:8];

            // --- FSM ---
            case (state)
                S_IDLE: begin
                    // Unlock direction nếu hết request theo hướng hiện tại
                    if (dir_locked) begin
                        if (dir_up && !(cabin_above || ext_above))
                            dir_locked <= 1'b0;
                        else if (!dir_up && !(cabin_below || ext_below))
                            dir_locked <= 1'b0;
                    end else begin
                        dir_locked <= 1'b0;
                    end

                    // Reset đèn và timer
                    led_door <= 1'b0;
                    led_up   <= 1'b0;
                    led_dn   <= 1'b0;
                    timer    <= 27'd0;

                    // 1) Cabin call tại tầng hiện tại?
                    if (cabin_req[floor]) begin
                        next_cabin_req[floor] = 1'b0;
                        state <= S_DOOR;

                    // 2) External call tại tầng hiện tại?
                    end else if ((|cabin_req)
                            ? ((ext_up_req[floor] && dir_up) || (ext_dn_req[floor] && !dir_up))
                            : (ext_up_req[floor] || ext_dn_req[floor])) begin
                        next_ext_up_req[floor] = 1'b0;
                        next_ext_dn_req[floor] = 1'b0;
                        state <= S_DOOR;

                    // 3) Di chuyển phục vụ cabin requests
                    end else if (|cabin_req) begin
                        if (!dir_locked) begin
                            if (cabin_above && !cabin_below)
                                dir_up <= 1'b1;
                            else if (!cabin_above && cabin_below)
                                dir_up <= 1'b0;
                            else
                                dir_up <= (floor >= (FLOOR_MAX - floor));
                        end
                        dir_locked <= 1'b1;
                        state      <= S_MOVE;

                    // 4) Di chuyển phục vụ external requests
                    end else if (|ext_any) begin
                        if (!dir_locked) begin
                            if (ext_above && !ext_below)
                                dir_up <= 1'b1;
                            else if (!ext_above && ext_below)
                                dir_up <= 1'b0;
                            else
                                dir_up <= (floor >= (FLOOR_MAX - floor));
                        end
                        dir_locked <= 1'b1;
                        state      <= S_MOVE;
                    end
                end

                S_MOVE: begin
                    // Luôn di chuyển bất kể overload
                    led_up <= dir_up;
                    led_dn <= ~dir_up;
                    timer  <= timer + 1;
                    if (timer == MOVE_LIMIT) begin
                        timer <= 27'd0;
                        if (dir_up && floor < FLOOR_MAX)
                            floor <= floor + 2'd1;
                        if (!dir_up && floor > FLOOR_MIN)
                            floor <= floor - 2'd1;
                        state <= S_IDLE;
                    end
                end

                S_DOOR: begin
                    // Mở cửa
                    led_door <= 1'b1;
                    if (!door_hold) begin
                        timer <= timer + 1;
                        if (timer == DOOR_LIMIT) begin
                            timer               <= 27'd0;
                            next_cabin_req[floor]  = 1'b0;
                            next_ext_up_req[floor] = 1'b0;
                            next_ext_dn_req[floor] = 1'b0;
                            state               <= S_IDLE;
                        end
                    end else begin
                        timer <= timer;  
                    end
                end
            endcase

            // --- Commit requests ---
            cabin_req  <= next_cabin_req;
            ext_up_req <= next_ext_up_req;
            ext_dn_req <= next_ext_dn_req;
        end
    end

    // 7-seg decoder
    reg [6:0] hex_reg;
    always @(*) begin
        case (floor)
            2'd0: hex_reg = 7'b1111001; // "1"
            2'd1: hex_reg = 7'b0100100; // "2"
            2'd2: hex_reg = 7'b0110000; // "3"
            2'd3: hex_reg = 7'b0011001; // "4"
            default: hex_reg = 7'b1111111;
        endcase
    end

    // Outputs
    assign HEX0      = hex_reg;
    assign LEDG[0]   = led_door;
    assign LEDG[1]   = led_up;
    assign LEDG[2]   = led_dn;
    assign LEDG[3]   = overload;
    assign LEDG[8:4] = 5'b0;
    assign LEDR      = pending;

endmodule