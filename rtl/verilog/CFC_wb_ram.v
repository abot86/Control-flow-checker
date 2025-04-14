module CFC_wb_ram #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter MEM_SIZE   = 1024,         // Number of 32-bit words
  parameter INIT_FILE  = "../mem_files/testAsm_0.vmem"  // Set to file name to initialize memory
)(
  input                      clk,
  input                      rst,
  input  [ADDR_WIDTH-1:0]    wb_adr_i,
  input                      wb_cyc_i,
  input                      wb_stb_i,
  input                      wb_we_i,
  input  [DATA_WIDTH-1:0]    wb_dat_i,
  input  [3:0]               wb_sel_i,
  output reg [DATA_WIDTH-1:0] wb_dat_o,
  output reg                 wb_ack_o
);

  // Word-addressable memory array
  reg [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];

  // Declare loop variable outside procedural blocks
  integer i;

  // Optionally initialize memory from a hex file
  initial begin
    if (INIT_FILE != "")
      $readmemh(INIT_FILE, mem);
  end

  // Generate ack signal (one-cycle delay response)
  always @(posedge clk or posedge rst) begin
    if (rst)
      wb_ack_o <= 1'b0;
    else
      wb_ack_o <= wb_stb_i && wb_cyc_i;
  end

  // Memory read/write operations (using word addressing)
  always @(posedge clk) begin
    if (wb_stb_i && wb_cyc_i) begin
      if (wb_we_i) begin
        // Write operation (using byte enables)
        for (i = 0; i < 4; i = i + 1) begin
          if (wb_sel_i[i])
            mem[wb_adr_i[ADDR_WIDTH-1:2]][8*i +: 8] <= wb_dat_i[8*i +: 8];
        end
      end else begin
        // Read operation
        wb_dat_o <= mem[wb_adr_i[ADDR_WIDTH-1:2]];
      end
    end
  end

endmodule
