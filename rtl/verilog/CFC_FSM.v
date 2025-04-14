module CFC_FSM (
    input wire clk,
    input wire reset,
    input wire flag,
    input wire [31:0] input_sig,
    output reg error,
    output reg watchdog_timeout  // New output for watchdog timeout
);

    parameter ERROR = 32'hFFFFFFFF;
    parameter START = 32'h00000000;
    parameter WATCHDOG_TIMEOUT_CYCLES = 500;  // Adjust this value as needed
    
    reg [31:0] current_state, next_state;
    reg [31:0] watchdog_counter;  // Counter for watchdog timer
    reg flag_prev;  // Previous value of flag to detect edges

    // Next-state logic
    always @(*) begin
        next_state = current_state;
        if (flag) begin
            case (current_state)
                START: next_state = (input_sig == 32'hB593) ? 32'hB593 : ERROR;
                32'hB593: next_state = (input_sig == 32'ha1c2) ? 32'ha1c2 : ERROR;
                32'ha1c2: next_state = (input_sig == 32'h3be7) ? 32'h3be7 : ERROR;
                32'h3be7: next_state = (input_sig == 32'h7dde) ? 32'h7dde : ERROR;
                32'h7dde: next_state = (input_sig == 32'h99ab) ? 32'h99ab : ERROR;
                32'h99ab: next_state = (input_sig == 32'hB593) ? 32'hB593 : ERROR;
                default: next_state = ERROR;
            endcase
        end
    end

    // State transition
    always @(posedge clk) begin
        if (reset) begin
            current_state <= START;
            watchdog_counter <= 0;
            watchdog_timeout <= 0;
            flag_prev <= 0;
        end else begin
            current_state <= next_state;
            
            // Store previous flag value
            flag_prev <= flag;
            
            // Watchdog timer logic
            if (current_state != ERROR) begin
                // Reset counter on rising edge of flag
                if (flag && !flag_prev) begin
                    watchdog_counter <= 0;
                    watchdog_timeout <= 0;
                end else if (watchdog_counter >= WATCHDOG_TIMEOUT_CYCLES) begin
                    watchdog_timeout <= 1;
                end else begin
                    watchdog_counter <= watchdog_counter + 1;
                end
            end else begin
                // Reset watchdog when in ERROR state
                watchdog_counter <= 0;
                watchdog_timeout <= 0;
            end
        end
    end

    // Output logic
    always @(*) begin
        error = (current_state == ERROR);
    end

endmodule