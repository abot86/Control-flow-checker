#!/usr/bin/env python3

import re

# Version check
print("Running analyze_results.py version 1.1")

def analyze_summary_log(filename):
    # Read the file
    with open(filename, 'r') as f:
        content = f.read()

    # Calculate time differences for each simulation
    latency = []
    fsm_latency = []
    watchdog_latency = []
    
    # Split content into simulation blocks
    simulation_blocks = content.split("Simulation")[1:]  # Skip first empty split

    # Count total errors
    total_detected = content.count("ERROR")
    fsm_errors = content.count("ERROR: FSM")
    watchdog_errors = content.count("ERROR: Watchdog")
    undetected = len(simulation_blocks) - total_detected
    
    for block in simulation_blocks:
        # Extract fault injection time
        fault_times = re.findall(r"Fault injected: (\d+\.?\d*)", block)
        if not fault_times:
            continue
            
        first_fault_time = float(fault_times[0])
        
        # Extract error times
        error_times = re.findall(r"ERROR: (?:FSM|Watchdog) (\d+\.?\d*)", block)
        if not error_times:
            continue
            
        first_error_time = float(error_times[0])
        
        # Calculate time difference
        time_diff = first_error_time - first_fault_time
        latency.append(time_diff)
        
        # If this is an FSM error, add to FSM-specific list
        if "ERROR: FSM" in block:
            fsm_latency.append(time_diff)
        # If this is an FSM error, add to FSM-specific list
        if "ERROR: Watchdog" in block:
            watchdog_latency.append(time_diff)

    # Print results
    print(f"Total detected: {total_detected}")
    print(f"FSM Errors: {fsm_errors}")
    print(f"Watchdog Errors: {watchdog_errors}")
    print(f"Total undetected: {undetected}")

    # print("\nTime differences between first fault and first error for each simulation:")
    # for i, diff in enumerate(latency, 1):
    #     print(f"Simulation {i}: {diff}")

    # Print FSM latencies
    # print("\nLatencies for FSM errors:")
    # for i, diff in enumerate(fsm_latency, 1):
    #     print(diff)

    # Print watchdog latencies
    # watchdog_latency.sort()
    # print("\nLatencies for watchdog errors:")
    # for i, diff in enumerate(watchdog_latency, 1):
    #     print(diff)


if __name__ == "__main__":
    analyze_summary_log("./simulation_results/summary.log") 