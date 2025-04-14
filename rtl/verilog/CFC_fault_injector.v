/* ****************************************************************************
  SPDX-License-Identifier: CERN-OHL-W-2.0

  Description: Fault injector module for mor1kx processor
  Randomly injects bit flips into PC with randomized timing between 50-500ns.
  Only modifies the least significant 8 bits of the PC.

  Copyright (C) 2024 Authors
***************************************************************************** */

`include "mor1kx-defines.v"

module CFC_fault_injector
  #(
    parameter OPTION_OPERAND_WIDTH = 32
    )
   (
    input                                  clk,
    input                                  rst,
    input                                  enable_fault_injection,
    input [31:0]                          random_seed_i,  // New input port for random seed
    
    // PC interface
    input [OPTION_OPERAND_WIDTH-1:0]      pc_i,
    output [OPTION_OPERAND_WIDTH-1:0]     pc_o,
    output                                 fault_injected_o
    );

   // Internal registers
   reg [31:0]                             random_seed;
   reg [OPTION_OPERAND_WIDTH-1:0]         fault_mask;
   reg                                    inject_fault;
   reg [31:0]                             time_to_next_fault;
   reg [31:0]                             fault_counter;
   
   // Initialize random seed using input
   initial begin
      random_seed = random_seed_i;
      time_to_next_fault = 32'd50; // Start with minimum delay
   end

   // Generate random numbers using LFSR
   always @(posedge clk) begin
      if (rst) begin
         random_seed <= random_seed_i;
         // Generate a random initial delay to avoid consistent timing
         time_to_next_fault <= 50 + (random_seed % 1451); // Random initial delay
         fault_counter <= time_to_next_fault; // Start with the random delay
      end else if (enable_fault_injection) begin
         // Modified LFSR polynomial for better randomization
         random_seed <= {random_seed[30:0], random_seed[31] ^ random_seed[21] ^ 
                        random_seed[1] ^ random_seed[0]};
         
         // Count down to next fault
         if (fault_counter > 0) begin
            fault_counter <= fault_counter - 1;
         end else begin
            // Generate new random delay between 50-500ns (50-500 clock cycles at 1ns/cycle)
            time_to_next_fault <= 50 + (random_seed[31:0] % 451); // 451 = 500-50+1
            fault_counter <= time_to_next_fault;
         end
      end
   end

   // Decide whether to inject fault based on timing
   always @(posedge clk) begin
      if (rst) begin
         inject_fault <= 1'b0;
         fault_mask <= {6'b0};
      end else if (enable_fault_injection && fault_counter == 0) begin
         // Generate random fault mask (flip one random bit in the least significant 8 bits)
         // Using more bits from the random seed for better randomization
         fault_mask <= (1'b1 << (random_seed[5:0] % 6)); // Using 5 bits instead of 3 for more variety
         inject_fault <= 1'b1;
      end else begin
         inject_fault <= 1'b0;
         fault_mask <= {OPTION_OPERAND_WIDTH{1'b0}};
      end
   end

   // Apply fault to PC only (only affects the least significant 8 bits)
   assign pc_o = (inject_fault) ? {pc_i[OPTION_OPERAND_WIDTH-1:8], pc_i[7:2] ^ fault_mask, pc_i[1:0]} : pc_i;
   assign fault_injected_o = inject_fault;

endmodule 