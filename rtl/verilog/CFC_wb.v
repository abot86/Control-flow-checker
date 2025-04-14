module CFC_wb (
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface
    input  wire [31:0] wb_adr_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    
    // Optional: external connections if needed
    output wire        fsm_error,
    output wire        watchdog_timeout  // New: watchdog timeout signal
);

    // Address map
    localparam ADDR_INPUT  = 32'hF000;  // CHANGE FOR DIFF MMIO ADDRESS
    localparam ADDR_STATUS = 32'h8000_0004;  // Read error status
    localparam ADDR_WATCHDOG = 32'h8000_0008;  // New: watchdog status address

    // Internal signals
    reg [31:0] input_sig;
    reg        flag;
    wire       error;
    reg        write_pending;  // New: track write operation

    // FSM instance
    fsm_generated fsm (
        .clk(clk),
        .reset(rst),
        .flag(flag),
        .input_sig(input_sig),
        .error(error),
        .watchdog_timeout(watchdog_timeout)  // New: connect watchdog timeout
    );

    assign fsm_error = error;

    // Write pending logic
    always @(posedge clk) begin
        if (rst) begin
            write_pending <= 1'b0;
        end else begin
            if (wb_cyc_i & wb_stb_i & wb_we_i & ~wb_ack_o & (wb_adr_i == ADDR_INPUT))
                write_pending <= 1'b1;
            else if (flag)
                write_pending <= 1'b0;
        end
    end

    // Flag generation
    always @(posedge clk) begin
        if (rst) begin
            flag <= 1'b0;
        end else begin
            flag <= write_pending & ~flag;  // Generate one-cycle pulse after write
        end
    end

    // Wishbone interface logic
    always @(posedge clk) begin
        if (rst) begin
            wb_ack_o <= 1'b0;
            input_sig <= 32'h0;
        end else begin
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
            
            if (wb_cyc_i & wb_stb_i & wb_we_i & ~wb_ack_o) begin
                case (wb_adr_i)
                    ADDR_INPUT: input_sig <= wb_dat_i;
                endcase
            end
        end
    end

    // Read logic
    always @(*) begin
        wb_dat_o = 32'h0;
        if (wb_cyc_i & wb_stb_i & ~wb_we_i) begin
            case (wb_adr_i)
                ADDR_INPUT:  wb_dat_o = input_sig;
                ADDR_STATUS: wb_dat_o = {31'h0, error};
                ADDR_WATCHDOG: wb_dat_o = {31'h0, watchdog_timeout};  // New: read watchdog status
                default:     wb_dat_o = 32'h0;
            endcase
        end
    end

endmodule