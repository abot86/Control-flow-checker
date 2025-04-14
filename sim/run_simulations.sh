#!/bin/bash

# Number of simulations to run
NUM_SIMULATIONS=100

# Create results directory if it doesn't exist
mkdir -p simulation_results

# Clear previous summary log
> simulation_results/summary.log

# Compile once
echo "Compiling testbench..."
iverilog -Wimplicit -I../rtl/verilog -c filelist.txt -s CFC_tb -o CFC_tb.vvp

# Function to generate a random 32-bit hex number
generate_random_seed() {
    # Use /dev/urandom to get 4 bytes of random data
    local seed=$(od -An -N4 -tu4 < /dev/urandom | tr -d ' ')
    printf "%08X" $seed
}

# Run simulations
echo "Running $NUM_SIMULATIONS simulations..."
for ((i=1; i<=NUM_SIMULATIONS; i++)); do
    echo "Simulation $i of $NUM_SIMULATIONS"
    seed=$(generate_random_seed)
    echo "Using random seed: 32'h$seed"
    
    # Run simulation and capture output
    vvp CFC_tb.vvp +sim_random_seed=$seed 2>&1 | tee "simulation_results/simulation_$i.log"
    
    # Extract key events from the log
    echo "Simulation $i Results:" >> simulation_results/summary.log
    grep -E "Fault injected|ERROR: Watchdog|ERROR: FSM" "simulation_results/simulation_$i.log" >> simulation_results/summary.log
    echo "----------------------------------------" >> simulation_results/summary.log
done

echo "All simulations completed. Results are in simulation_results/"
echo "Summary of all simulations is in simulation_results/summary.log" 