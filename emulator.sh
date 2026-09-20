#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Error: emulator requires exactly one argument."
    exit 1
fi

filename=$1

if [[ "$filename" != *.bin ]]; then
    echo "Error: input file must have a .bin extension."
    exit 1
fi

if [ ! -f "$filename" ]; then
    echo "Error: file does not exist."
    exit 1
fi

if [ ! -s "$filename" ]; then
    echo "Error: .bin file is empty."
    exit 1
fi

mapfile -t hexBytes < <(xxd -p "$filename" | fold -w2)
fileSize=${#hexBytes[@]}

memory=()
for ((i = 0; i < 256; i++)); do
    memory[i]=0
done
registers=(0 0 0 0)

for ((i = 0; i < fileSize; i++)); do
    memory[i]=$((16#${hexBytes[i]}))
done

if [ "$fileSize" -eq 2 ]; then
    pc=0
else
    pc=2
fi

while true; do
    if (( pc + 1 > 255 )); then
        echo "Error: program counter ran off the end of memory."
        exit 1
    fi

    byte1=${memory[pc]}
    byte2=${memory[$((pc + 1))]}

    opcode=$((byte1 >> 2))
    reg=$((byte1 & 3))
    memAddr=$byte2

    case "$opcode" in
        1) # LOAD: Register <- Memory[Address]
            registers[reg]=${memory[memAddr]}
            ;;
        2) # STORE: Memory[Address] <- Register
            memory[memAddr]=${registers[reg]}
            ;;
        3) # ADD: Register <- Register + Memory[Address]
            registers[reg]=$((registers[reg] + memory[memAddr]))
            ;;
        4) # SUB: Register <- Register - Memory[Address], only if Register >= Memory[Address]
            if (( registers[reg] >= memory[memAddr] )); then
                registers[reg]=$((registers[reg] - memory[memAddr]))
            else
                echo "Error: SUB would underflow (register $reg < memory[$memAddr]); register and memory unchanged."
            fi
            ;;
        8) # QUIT
            break
            ;;
        9) # PRINT: display Register on STDOUT
            echo "${registers[reg]}"
            ;;
        *)
            echo "Error: unknown opcode $opcode at memory address $pc."
            exit 1
            ;;
    esac

    pc=$((pc + 2))
done

echo "Program finished (QUIT reached)."
