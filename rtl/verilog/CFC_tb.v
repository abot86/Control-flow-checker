`timescale 1ns/1ps
module CFC_tb;

  // Clock and reset signals
  reg clk;
  reg rst;

  // Clock generation: 10 ns period
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Reset generation: assert reset for 20 ns
  initial begin
    rst = 1'b1;
    #20 rst = 1'b0;
  end

  // Wishbone interface signals for instruction bus
  wire [31:0] iwbm_adr_o;
  wire        iwbm_stb_o;
  wire        iwbm_cyc_o;
  wire [3:0]  iwbm_sel_o;
  wire        iwbm_we_o;
  wire [2:0]  iwbm_cti_o;
  wire [1:0]  iwbm_bte_o;
  wire [31:0] iwbm_dat_o;
  reg         iwbm_err_i;
  wire        iwbm_ack_i;
  wire [31:0] iwbm_dat_i;
  reg         iwbm_rty_i;

  // Wishbone interface signals for data bus
  wire [31:0] dwbm_adr_o;
  wire        dwbm_stb_o;
  wire        dwbm_cyc_o;
  wire [3:0]  dwbm_sel_o;
  wire        dwbm_we_o;
  wire [2:0]  dwbm_cti_o;
  wire [1:0]  dwbm_bte_o;
  wire [31:0] dwbm_dat_o;
  reg         dwbm_err_i;
  wire        dwbm_ack_i;
  wire [31:0] dwbm_dat_i;
  reg         dwbm_rty_i;

  // Debug interface signals
  reg  [15:0] du_addr_i;
  reg         du_stb_i;
  reg  [31:0] du_dat_i;
  wire [31:0] du_dat_o;
  wire        du_ack_o;
  reg         du_we_i;
  reg         du_stall_i;
  wire        du_stall_o;

  // Interrupt signals
  reg  [31:0] irq_i;

  // Trace port signals
  wire        traceport_exec_valid_o;
  wire [31:0] traceport_exec_pc_o;
  wire        traceport_exec_jb_o;
  wire        traceport_exec_jal_o;
  wire        traceport_exec_jr_o;
  wire [31:0] traceport_exec_jbtarget_o;
  wire [31:0] traceport_exec_insn_o;
  wire [31:0] traceport_exec_wbdata_o;
  wire [4:0]  traceport_exec_wbreg_o;
  wire        traceport_exec_wben_o;

  // Multicore signals
  reg  [31:0] multicore_coreid_i;
  reg  [31:0] multicore_numcores_i;

  // Snoop signals
  reg  [31:0] snoop_adr_i;
  reg         snoop_en_i;

  // FSM signals
  wire [31:0] fsm_wb_dat_o;
  wire        fsm_wb_ack_o;
  wire        fsm_error;
  wire        fsm_watchdog_timeout;

  // Instantiate fault injector
  wire [31:0] pc_faulty;
  wire fault_injected;
  
  // Define random seed as a parameter
  // parameter SIM_RANDOM_SEED = 32'hA1B2_C3D4;  // Default seed, will be overridden by script

  // Define random seed as an input (reg)
  reg [31:0] sim_random_seed;
  // Instantiate the mor1kx processor
  mor1kx #(
    .OPTION_CPU0("CAPPUCCINO"),
    .FEATURE_DATACACHE("NONE"),
    .FEATURE_INSTRUCTIONCACHE("NONE"),
    .FEATURE_DEBUGUNIT("NONE"),
    .FEATURE_PERFCOUNTERS("NONE"),
    .FEATURE_MAC("NONE"),
    .FEATURE_MULTICORE("NONE"),
    .FEATURE_TRACEPORT_EXEC("ENABLED"),
    .OPTION_RF_CLEAR_ON_INIT(1),
    .OPTION_RF_NUM_SHADOW_GPR(0),
    .FEATURE_STORE_BUFFER("ENABLED"),
    .OPTION_RESET_PC(32'h00000100)
  ) uut (
    .clk(clk),
    .rst(rst),

    // Instruction bus
    .iwbm_adr_o(iwbm_adr_o),
    .iwbm_stb_o(iwbm_stb_o),
    .iwbm_cyc_o(iwbm_cyc_o),
    .iwbm_sel_o(iwbm_sel_o),
    .iwbm_we_o(iwbm_we_o),
    .iwbm_cti_o(iwbm_cti_o),
    .iwbm_bte_o(iwbm_bte_o),
    .iwbm_dat_o(iwbm_dat_o),
    .iwbm_err_i(iwbm_err_i),
    .iwbm_ack_i(iwbm_ack_i),
    .iwbm_dat_i(iwbm_dat_i),
    .iwbm_rty_i(iwbm_rty_i),

    // Data bus
    .dwbm_adr_o(dwbm_adr_o),
    .dwbm_stb_o(dwbm_stb_o),
    .dwbm_cyc_o(dwbm_cyc_o),
    .dwbm_sel_o(dwbm_sel_o),
    .dwbm_we_o(dwbm_we_o),
    .dwbm_cti_o(dwbm_cti_o),
    .dwbm_bte_o(dwbm_bte_o),
    .dwbm_dat_o(dwbm_dat_o),
    .dwbm_err_i(dwbm_err_i),
    .dwbm_ack_i(dwbm_ack_i),
    .dwbm_dat_i(dwbm_dat_i),
    .dwbm_rty_i(dwbm_rty_i),

    // Debug interface
    .du_addr_i(du_addr_i),
    .du_stb_i(du_stb_i),
    .du_dat_i(du_dat_i),
    .du_dat_o(du_dat_o),
    .du_ack_o(du_ack_o),
    .du_we_i(du_we_i),
    .du_stall_i(du_stall_i),
    .du_stall_o(du_stall_o),

    // Interrupts
    .irq_i(irq_i),

    // Trace port
    .traceport_exec_valid_o(traceport_exec_valid_o),
    .traceport_exec_pc_o(traceport_exec_pc_o),
    .traceport_exec_jb_o(traceport_exec_jb_o),
    .traceport_exec_jal_o(traceport_exec_jal_o),
    .traceport_exec_jr_o(traceport_exec_jr_o),
    .traceport_exec_jbtarget_o(traceport_exec_jbtarget_o),
    .traceport_exec_insn_o(traceport_exec_insn_o),
    .traceport_exec_wbdata_o(traceport_exec_wbdata_o),
    .traceport_exec_wbreg_o(traceport_exec_wbreg_o),
    .traceport_exec_wben_o(traceport_exec_wben_o),

    // Multicore
    .multicore_coreid_i(multicore_coreid_i),
    .multicore_numcores_i(multicore_numcores_i),

    // Snoop
    .snoop_adr_i(snoop_adr_i),
    .snoop_en_i(snoop_en_i),

		.external_pc_inject_i             (fault_injected),   // FAULT INJECTION PC
    .external_pc_i                    (pc_faulty)         // FAULT INJECTION PC
  );

  // Instruction memory
  CFC_wb_ram #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .MEM_SIZE(64000),
    .INIT_FILE("testAsm_0.vmem")  //-----------------------------INSERT VMEM FILE HERE--------------------------------
  ) inst_mem (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(iwbm_adr_o),
    .wb_cyc_i(iwbm_cyc_o),
    .wb_stb_i(iwbm_stb_o),
    .wb_we_i(iwbm_we_o),
    .wb_dat_i(iwbm_dat_o),
    .wb_sel_i(iwbm_sel_o),
    .wb_dat_o(iwbm_dat_i),
    .wb_ack_o(iwbm_ack_i)
  );

  // Data memory
  CFC_wb_ram #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .MEM_SIZE(64000),
    .INIT_FILE("")
  ) data_mem (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(dwbm_adr_o),
    .wb_cyc_i(dwbm_cyc_o),
    .wb_stb_i(dwbm_stb_o),
    .wb_we_i(dwbm_we_o),
    .wb_dat_i(dwbm_dat_o),
    .wb_sel_i(dwbm_sel_o),
    .wb_dat_o(dwbm_dat_i),
    .wb_ack_o(dwbm_ack_i)
  );

  CFC_wb fsm_inst (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(dwbm_adr_o),
    .wb_cyc_i(dwbm_cyc_o),
    .wb_stb_i(dwbm_stb_o),
    .wb_we_i(dwbm_we_o),
    .wb_dat_i(dwbm_dat_o),
    .wb_sel_i(dwbm_sel_o),
    .wb_dat_o(fsm_wb_dat_o),
    .wb_ack_o(fsm_wb_ack_o),
    .fsm_error(fsm_error),
    .watchdog_timeout(fsm_watchdog_timeout)
  );
  // wire [31:0] data_mem_dat_o;
  // wire        data_mem_ack_o;

  // assign dwbm_dat_i = (dwbm_adr_o[15:0] == 16'hF000) ? fsm_wb_dat_o : data_mem_dat_o;
  // assign dwbm_ack_i = (dwbm_adr_o[15:0] == 16'hF000) ? fsm_wb_ack_o : data_mem_ack_o;

  // Traceport monitor
  mor1kx_traceport_monitor #(
    .OPTION_OPERAND_WIDTH(32),
    .OPTION_RF_ADDR_WIDTH(5)
  ) monitor (
    .clk(clk),
    .rst(rst),
    .traceport_exec_valid(traceport_exec_valid_o),
    .traceport_exec_pc(traceport_exec_pc_o),
    .traceport_exec_insn(traceport_exec_insn_o),
    .traceport_exec_wbdata(traceport_exec_wbdata_o),
    .traceport_exec_wbreg(traceport_exec_wbreg_o),
    .traceport_exec_wben(traceport_exec_wben_o),
    .finish_cross(1'b0),
    .finish()
  );

  // Initialize testbench signals
  initial begin
    // Initialize debug interface
    du_addr_i = 16'h0;
    du_stb_i = 1'b0;
    du_dat_i = 32'h0;
    du_we_i = 1'b0;
    du_stall_i = 1'b0;

    // Initialize multicore signals
    multicore_coreid_i = 32'h0;
    multicore_numcores_i = 32'h1;

    // Initialize snoop signals
    snoop_adr_i = 32'h0;
    snoop_en_i = 1'b0;

    // Initialize error and retry signals
    iwbm_err_i = 1'b0;
    iwbm_rty_i = 1'b0;
    dwbm_err_i = 1'b0;
    dwbm_rty_i = 1'b0;

    // Initialize interrupts
    irq_i = 32'h0;

    // Dump waveforms
    $dumpfile("mor1kx_tb.vcd");
    $dumpvars(0, mor1kx_tb);

    if (! $value$plusargs("sim_random_seed=%h", sim_random_seed)) begin
        $display("ERROR: please specify +sim_random_seed=<value> to start.");
        $finish;
     end
    // Add monitoring
    // $monitor("Time=%0t PC=%d insn=%h valid=%b wben=%b wbreg=%d wbdata=%d dwbm_adr = %h dwbm_we=%b dwbm_dat=%h dwbm_dat_i=%h", 
    //          $time, traceport_exec_pc_o, traceport_exec_insn_o, 
    //          traceport_exec_valid_o, traceport_exec_wben_o,
    //          traceport_exec_wbreg_o, traceport_exec_wbdata_o,
    //          dwbm_adr_o, dwbm_we_o, dwbm_dat_o, dwbm_dat_i);
    $monitor("Time=%0t PC=%h insn=%h dwbm_adr = %h dwbm_we=%b dwbm_dat=%h", 
             $time, traceport_exec_pc_o, traceport_exec_insn_o, 
             dwbm_adr_o, dwbm_we_o, dwbm_dat_o);
    // Run for a reasonable time
    #20000 $finish;  //-----------------------------INSERT TIME HERE--------------------------------
  end

  // Monitor FSM error and watchdog status
  always @(fsm_error or fsm_watchdog_timeout) begin
      // if (fsm_error)
      //     $display("\033[1;31mFSM Error Status Changed @ Time=%0t: Error=%b\033[0m", $time, fsm_error);
      // if (fsm_watchdog_timeout) begin
      //     $display("\033[1;31mWatchdog Timeout @ Time= %0t\033[0m", $time);
      //     $finish;
      // end
      if (fsm_watchdog_timeout) begin
          $display("ERROR: Watchdog %0t", $time);
          $finish;
      end
  end

  always @(fsm_error) begin
      if (fsm_error) begin
          $display("ERROR: FSM %0t", 
                  $time);
          $finish;  // This will exit the simulation
      end
  end

  
  CFC_fault_injector #(
    .OPTION_OPERAND_WIDTH(32)
  ) fault_inj (
    .clk(clk),
    .rst(rst),
    .enable_fault_injection(1'b1),  // Always enable fault injection
    .random_seed_i(sim_random_seed),  // Connect the random seed input
    .pc_i(traceport_exec_pc_o),
    .pc_o(pc_faulty),
    .fault_injected_o(fault_injected)
  );

  // Monitor fault injection
  always @(posedge clk) begin
    if (fault_injected) begin
      // $display("\033[1;33mFault injected at time %0t: PC=%h -> %h\033[0m", 
      //          $time, traceport_exec_pc_o, pc_faulty);
      $display("Fault injected: %0t", 
               $time);
    end
  end

endmodule