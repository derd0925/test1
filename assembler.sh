#!/bin/bash

decimal_to_binary() {
    local mem=$1
    local membin=""
    local tmp=$mem

    for weight in 128 64 32 16 8 4 2 1
    do
        if (( tmp >= weight )); then
            bit=1
            tmp=$((tmp - weight))
        else
            bit=0
        fi

        membin="${membin}${bit}"
    done

    echo "$membin"
}

bin_to_hex() {
    printf '%02x' "$((2#$1))"
}

if [ $# -ne 1 ]; then
    echo "Error: assembler requires exactly one argument."
    exit 1
fi

filename=$1

if [[ "$filename" != *.vsc ]]; then
    echo "Error: input file must have a .vsc extension."
    exit 1
fi

if [ ! -f "$filename" ]; then
    echo "Error: file does not exist."
    exit 1
fi

if [ ! -s "$filename" ]; then
    echo "Warning: input file is empty."
    exit 1
fi

line1=$(sed -n '1p' "$filename" | tr -d '\r')

if [[ "$line1" != "0" && "$line1" != "2" ]]; then
    echo "Error: Line 1 must be 0 or 2."
    exit 1
fi

dataArray=()

if [[ "$line1" == "0" ]]; then
    line2=$(sed -n '2p' "$filename" | tr -d '\r')

    if [[ "$line2" != "QUIT,0,0" ]]; then
        echo "Error: Line 2 must be exactly QUIT,0,0."
        exit 1
    fi

    dataArray=()
    dataArray+=("20")
    dataArray+=("00")
fi

if [[ "$line1" == "2" ]]; then
    data1=$(sed -n '2p' "$filename")
    data2=$(sed -n '3p' "$filename")
        
    if ! [[ "$data1" =~ ^[0-9]+$ ]] || (( data1 < 0 || data1 >= 128 )); then
        echo "Error: invalid data on line 2."
        exit 1
    fi

    if ! [[ "$data2" =~ ^[0-9]+$ ]] || (( data2 < 0 || data2 >= 128 )); then
        echo "Error: invalid data on line 3."
        exit 1
    fi
    
    dataArray+=("$(bin_to_hex "$(decimal_to_binary "$data1")")")
    dataArray+=("$(bin_to_hex "$(decimal_to_binary "$data2")")")
 
    totalLines=$(wc -l < "$filename")
    lineNum=4
    count=0
    foundQuit=0
 
    while [ "$lineNum" -le "$totalLines" ]; do
        line=$(sed -n "${lineNum}p" "$filename")
 
        if [ -z "$line" ]; then
            echo "Error: empty line $lineNum."
            exit 1
        fi
 
        # Reject overly long lines before even trying to parse them
        if [ "${#line}" -gt 11 ]; then
            echo "Error: line $lineNum exceeds maximum instruction length."
            exit 1
        fi
 
        IFS=',' read -r ins reg mem <<< "$line"
 
        case "$ins" in
            LOAD)  opcode="000001" ;;
            STORE) opcode="000010" ;;
            ADD)   opcode="000011" ;;
            SUB)   opcode="000100" ;;
            QUIT)  opcode="001000" ;;
            PRINT) opcode="001001" ;;
            *)
                echo "Error: unknown instruction '$ins' on line $lineNum."
                exit 1
                ;;
        esac
 
        if [[ "$ins" == "QUIT" ]]; then
            if [[ "$line" != "QUIT,0,0" ]]; then
                echo "Error: QUIT must be QUIT,0,0 (line $lineNum)."
                exit 1
            fi
 
            byte1=$(bin_to_hex "${opcode}00")
            byte2=$(bin_to_hex "00000000")
 
            dataArray+=("$byte1")
            dataArray+=("$byte2")
 
            foundQuit=1
            break
        fi
 
        if ! [[ "$reg" =~ ^[0-9]+$ ]] || (( reg < 0 || reg > 3 )); then
            echo "Error: invalid register on line $lineNum."
            exit 1
        fi
 
        if ! [[ "$mem" =~ ^[0-9]+$ ]] || (( mem < 0 || mem > 255 )); then
            echo "Error: invalid memory address on line $lineNum."
            exit 1
        fi
 
        regbin=$(decimal_to_binary "$reg")
        regbin="${regbin: -2}"          # only the low 2 bits matter for reg (0-3)
 
        membin=$(decimal_to_binary "$mem")
 
        byte1=$(bin_to_hex "${opcode}${regbin}")
        byte2=$(bin_to_hex "$membin")
 
        dataArray+=("$byte1")
        dataArray+=("$byte2")
 
        count=$((count + 1))
        if [ "$count" -ge 100 ]; then
            echo "Error: exceeded maximum of 100 instructions."
            exit 1
        fi
 
        lineNum=$((lineNum + 1))
    done
 
    if [ "$foundQuit" -eq 0 ]; then
        echo "Error: no QUIT,0,0 found before end of file."
        exit 1
    fi
fi
 
outfile="${filename%.vsc}.bin"
> "$outfile"
 
for byte in "${dataArray[@]}"; do
    printf "\x$byte" >> "$outfile"
done
 
echo "*************"
echo "Done with the conversion"
echo "The content of the .bin file is:"
for byte in "${dataArray[@]}"; do
    echo "$byte"
done
 