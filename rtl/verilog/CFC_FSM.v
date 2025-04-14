module CFC_FSM (
    input wire clk,
    input wire reset,
    input wire flag,
    input wire [31:0] input_sig,
    output reg error,
    output reg watchdog_timeout
);

    parameter ERROR = 32'hFFFFFFFF;
    parameter START = 32'h0;
    parameter WATCHDOG_TIMEOUT_CYCLES = 500;

    reg [31:0] current_state, next_state;
    reg [31:0] watchdog_counter;
    reg flag_prev;

    always @(*) begin
        next_state = current_state;
        if (flag) begin
            case (current_state)
                START: next_state = (input_sig = 32'h10964);
                32'h10964: next_state = (input_sig == 32'h10965) ? 32'h10965 : ERROR;
                32'h10965: begin
                    if (input_sig == 32'h32617)
                        next_state = 32'h32617;
                    else if (input_sig == 32'h32622)
                        next_state = 32'h32622;
                    else
                        next_state = ERROR;
                end
                32'h25120: next_state = (input_sig == 32'h25126) ? 32'h25126 : ERROR;
                32'h25121: next_state = (input_sig == 32'h25126) ? 32'h25126 : ERROR;
                32'h25124: begin
                    if (input_sig == 32'h32620)
                        next_state = 32'h32620;
                    else if (input_sig == 32'h32621)
                        next_state = 32'h32621;
                    else
                        next_state = ERROR;
                end
                32'h25126: begin
                    if (input_sig == 32'h25121)
                        next_state = 32'h25121;
                    else if (input_sig == 32'h25127)
                        next_state = 32'h25127;
                    else
                        next_state = ERROR;
                end
                32'h25127: next_state = (input_sig == 32'h25124) ? 32'h25124 : ERROR;
                32'h29104: next_state = (input_sig == 32'h29107) ? 32'h29107 : ERROR;
                32'h29105: begin
                    if (input_sig == 32'h29110)
                        next_state = 32'h29110;
                    else if (input_sig == 32'h29104)
                        next_state = 32'h29104;
                    else
                        next_state = ERROR;
                end
                32'h29107: next_state = (input_sig == 32'h32621) ? 32'h32621 : ERROR;
                32'h29110: next_state = (input_sig == 32'h29105) ? 32'h29105 : ERROR;
                32'h29111: next_state = (input_sig == 32'h29105) ? 32'h29105 : ERROR;
                32'h32610: next_state = ERROR;
                32'h32616: next_state = (input_sig == 32'h10964) ? 32'h10964 : ERROR;
                32'h32617: next_state = (input_sig == 32'h32623) ? 32'h32623 : ERROR;
                32'h32620: next_state = (input_sig == 32'h29111) ? 32'h29111 : ERROR;
                32'h32621: next_state = (input_sig == 32'h46485) ? 32'h46485 : ERROR;
                32'h32622: next_state = (input_sig == 32'h32623) ? 32'h32623 : ERROR;
                32'h32623: next_state = (input_sig == 32'h25120) ? 32'h25120 : ERROR;
                32'h46481: next_state = (input_sig == 32'h32610) ? 32'h32610 : ERROR;
                32'h46482: next_state = (input_sig == 32'h46481) ? 32'h46481 : ERROR;
                32'h46483: begin
                    if (input_sig == 32'h46484)
                        next_state = 32'h46484;
                    else if (input_sig == 32'h46482)
                        next_state = 32'h46482;
                    else
                        next_state = ERROR;
                end
                32'h46484: next_state = (input_sig == 32'h46483) ? 32'h46483 : ERROR;
                32'h46485: next_state = (input_sig == 32'h46483) ? 32'h46483 : ERROR;
                default: next_state = ERROR;
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            current_state <= START;
            watchdog_counter <= 0;
            watchdog_timeout <= 0;
            flag_prev <= 0;
        end else begin
            current_state <= next_state;
            flag_prev <= flag;
            if (current_state != ERROR) begin
                if (flag && !flag_prev) begin
                    watchdog_counter <= 0;
                    watchdog_timeout <= 0;
                end else if (watchdog_counter >= WATCHDOG_TIMEOUT_CYCLES) begin
                    watchdog_timeout <= 1;
                end else begin
                    watchdog_counter <= watchdog_counter + 1;
                end
            end else begin
                watchdog_counter <= 0;
                watchdog_timeout <= 0;
            end
        end
    end

    always @(*) begin
        error = (current_state == ERROR);
    end

endmodule