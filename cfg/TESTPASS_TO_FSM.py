import re
import sys
from collections import defaultdict


def parse_cfg_from_dump(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()

    function_entry = {}
    function_order = []
    current_function = None

    for line in lines:
        line = line.strip()
        func_match = re.match(r"^;; Function (\S+)", line)
        if func_match:
            current_function = func_match.group(1)
            function_order.append(current_function)
            continue

        bb_match = re.match(r"<bb (\d+)> :", line)
        if bb_match and current_function:
            block_id = int(bb_match.group(1))
            if current_function not in function_entry:
                function_entry[current_function] = block_id
            continue

    cfg = defaultdict(list)
    function_blocks = defaultdict(dict)
    call_sites = []
    current_function = None
    current_block = None
    prev_block = None
    call_and_branch_exception = None
    call_and_branch_exception_list = defaultdict(list)
    mem_signatures = defaultdict(dict)

    for line in lines:
        line = line.strip()
        func_match = re.match(r"^;; Function (\S+)", line)
        if func_match:
            current_function = func_match.group(1)
            current_block = None
            prev_block = None
            call_and_branch_exception = None
            continue

        bb_match = re.match(r"<bb (\d+)> :", line)
        if bb_match and current_function:
            block_id = int(bb_match.group(1))
            current_block = block_id
            function_blocks[current_function][current_block] = []
            if prev_block is not None:
                cfg[(current_function, prev_block)].append((current_function, current_block))
            prev_block = current_block
            call_and_branch_exception = None
            continue

        if current_block is not None and current_function:
            function_blocks[current_function][current_block].append(line)

        mem_match = re.match(r".*MEM <int> \[\(void \*\)ptr_tmp\.\d+_\d+\] = (\d+);", line)
        if mem_match:
            signature = mem_match.group(1)
            mem_signatures[current_function][current_block] = signature

        goto_match = re.match(r".*goto <bb (\d+)>;", line)
        if goto_match and current_block is not None:
            target_block = int(goto_match.group(1))
            if call_and_branch_exception is None:
                cfg[(current_function, current_block)].append((current_function, target_block))
                prev_block = None
            else:
                call_and_branch_exception_list[(current_function, current_block)].append((current_function, target_block))

        call_match = re.match(r".* (\w+) \(.*\);", line)
        if call_match:
            callee = call_match.group(1)
            if callee in function_entry:
                entry_block = function_entry[callee]
                if current_block is not None:
                    cfg[(current_function, current_block)] = [(callee, entry_block)]
                    call_sites.append((current_function, current_block, callee))
                    prev_block = None
                    call_and_branch_exception = current_block

    return_points = {}
    for caller_func, caller_bb, callee_func in call_sites:
        if caller_bb is None:
            continue
        caller_blocks = sorted(bb for bb in function_blocks[caller_func].keys() if bb is not None)
        next_bb = next((bb for bb in caller_blocks if bb > caller_bb), None)
        if next_bb is not None:
            if (caller_func, caller_bb) in call_and_branch_exception_list:
                return_points[(callee_func, function_entry[callee_func])] = call_and_branch_exception_list[(caller_func, caller_bb)]
            else:
                return_points[(callee_func, function_entry[callee_func])] = [(caller_func, next_bb)]

    for (func, src), dests in return_points.items():
        if func in function_blocks and function_blocks[func]:
            return_block = max(function_blocks[func].keys())
            for a in dests:
                cfg[(func, return_block)].append(a)

    return function_blocks, cfg, mem_signatures


def convert_cfg_to_signature_based(cfg, mem_signatures):
    signature_cfg = defaultdict(list)
    signature_nodes = set()
    bb_to_signature = {}
    for func, blocks in mem_signatures.items():
        for bb, sig in blocks.items():
            bb_to_signature[(func, bb)] = int(sig)
    for (func, src), dests in cfg.items():
        src_sig = bb_to_signature.get((func, src))
        if src_sig is None:
            continue
        for dest_func, dest_bb in dests:
            dest_sig = bb_to_signature.get((dest_func, dest_bb))
            if dest_sig is None:
                continue
            signature_cfg[src_sig].append(dest_sig)
            signature_nodes.update([src_sig, dest_sig])
    return signature_cfg, sorted(signature_nodes)


def generate_verilog_fsm(states, transitions, initial_state):
    verilog = []
    verilog.append("module CFC_FSM (")
    verilog.append("    input wire clk,")
    verilog.append("    input wire reset,")
    verilog.append("    input wire flag,")
    verilog.append("    input wire [31:0] input_sig,")
    verilog.append("    output reg error,")
    verilog.append("    output reg watchdog_timeout")
    verilog.append(");\n")
    verilog.append("    parameter ERROR = 32'hFFFFFFFF;")
    verilog.append(f"    parameter START = 32'h{00000000};")
    verilog.append("    parameter WATCHDOG_TIMEOUT_CYCLES = 500;\n")
    verilog.append("    reg [31:0] current_state, next_state;")
    verilog.append("    reg [31:0] watchdog_counter;")
    verilog.append("    reg flag_prev;\n")
    verilog.append("    always @(*) begin")
    verilog.append("        next_state = current_state;")
    verilog.append("        if (flag) begin")
    verilog.append("            case (current_state)")
    verilog.append(f"                START: next_state = (input_sig = 32'h{initial_state});")
    for state in states:
        if state in transitions:
            conds = transitions[state]
            if len(conds) == 1:
                verilog.append(f"                32'h{state}: next_state = (input_sig == 32'h{conds[0]}) ? 32'h{conds[0]} : ERROR;")
            else:
                verilog.append(f"                32'h{state}: begin")
                for idx, target in enumerate(conds):
                    keyword = "if" if idx == 0 else "else if"
                    verilog.append(f"                    {keyword} (input_sig == 32'h{target})")
                    verilog.append(f"                        next_state = 32'h{target};")
                verilog.append("                    else")
                verilog.append("                        next_state = ERROR;")
                verilog.append("                end")
        else:
            verilog.append(f"                32'h{state}: next_state = ERROR;")
    verilog.append("                default: next_state = ERROR;")
    verilog.append("            endcase")
    verilog.append("        end")
    verilog.append("    end\n")
    verilog.append("    always @(posedge clk) begin")
    verilog.append("        if (reset) begin")
    verilog.append(f"            current_state <= START;")
    verilog.append("            watchdog_counter <= 0;")
    verilog.append("            watchdog_timeout <= 0;")
    verilog.append("            flag_prev <= 0;")
    verilog.append("        end else begin")
    verilog.append("            current_state <= next_state;")
    verilog.append("            flag_prev <= flag;")
    verilog.append("            if (current_state != ERROR) begin")
    verilog.append("                if (flag && !flag_prev) begin")
    verilog.append("                    watchdog_counter <= 0;")
    verilog.append("                    watchdog_timeout <= 0;")
    verilog.append("                end else if (watchdog_counter >= WATCHDOG_TIMEOUT_CYCLES) begin")
    verilog.append("                    watchdog_timeout <= 1;")
    verilog.append("                end else begin")
    verilog.append("                    watchdog_counter <= watchdog_counter + 1;")
    verilog.append("                end")
    verilog.append("            end else begin")
    verilog.append("                watchdog_counter <= 0;")
    verilog.append("                watchdog_timeout <= 0;")
    verilog.append("            end")
    verilog.append("        end")
    verilog.append("    end\n")
    verilog.append("    always @(*) begin")
    verilog.append("        error = (current_state == ERROR);")
    verilog.append("    end\n")
    verilog.append("endmodule")
    return "\n".join(verilog)


def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: python3 TESTPASS_TO_FSM.py <input_file_path> [output_file_path]")
        sys.exit(1)

    input_path = sys.argv[1]
    
    # Use provided output path or default to ../rtl/verilog/CFC_FSM.v
    output_path = sys.argv[2] if len(sys.argv) == 3 else "../rtl/verilog/CFC_FSM.v"

    function_blocks, cfg, mem_signatures = parse_cfg_from_dump(input_path)
    signature_cfg, signature_nodes = convert_cfg_to_signature_based(cfg, mem_signatures)
    initial_state = signature_nodes[0]
    verilog_code = generate_verilog_fsm(signature_nodes, signature_cfg, initial_state)

    with open(output_path, "w") as f:
        f.write(verilog_code)

    print(f"FSM Verilog generated in {output_path}")



if __name__ == "__main__":
    main()
