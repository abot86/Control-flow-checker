import sys

def parse_hex_file(input_path, output_path, endian='big'):
    with open(input_path, 'r') as f:
        lines = f.readlines()

    memory = {}
    addr = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith('@'):
            addr = int(line[1:], 16)
        else:
            bytes_str = line.split()
            for byte_str in bytes_str:
                memory[addr] = int(byte_str, 16)
                addr += 1

    # Word-align and write to output
    min_addr = min(memory.keys())
    max_addr = max(memory.keys())
    aligned_output = []
    aligned_output.append("@00000040")
    for addr in range(min_addr, max_addr + 1, 4):
        word_bytes = [memory.get(addr + i, 0) for i in range(4)]
        if endian == 'big':
            word = ''.join(f'{b:02x}' for b in word_bytes)
        else:  # little-endian
            word = ''.join(f'{b:02x}' for b in reversed(word_bytes))
        aligned_output.append(word)

    with open(output_path, 'w') as f:
        for word in aligned_output:
            f.write(word + '\n')

    print(f"Word-aligned output written to {output_path}")


if __name__ == '__main__':
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("Usage: python parse_hex_file.py <input_file> <output_file> [endian: big|little]")
        sys.exit(1)

    input_file = sys.argv[1]
    print(input_file)
    output_file = sys.argv[2]
    print(output_file)
    endian = sys.argv[3] if len(sys.argv) == 4 else 'big'

    if endian not in ['big', 'little']:
        print("Error: Endian must be either 'big' or 'little'")
        sys.exit(1)

    parse_hex_file(input_file, output_file, endian)
