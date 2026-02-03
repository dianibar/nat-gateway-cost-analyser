#!/usr/bin/env python3
"""
Script to combine VPC Flow Logs timestamp and data lines into single lines.
Also removes the two unix timestamps before ACCEPT/OK columns.
Reads from sample_1.csv and outputs to sample_1_formatted.csv
"""

import sys
import re

def format_vpc_logs(input_file, output_file):
    """Combine timestamp and data lines into single lines, removing unix timestamps."""
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        lines = infile.readlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            # Check if this is a timestamp line (ISO 8601 format)
            if line and 'T' in line and 'Z' in line:
                timestamp = line
                # Get the next line (data line)
                if i + 1 < len(lines):
                    data = lines[i + 1].strip()
                    # Remove the two unix timestamps before ACCEPT/OK
                    # Pattern: remove two consecutive numbers before ACCEPT or SKIPDATA
                    data = re.sub(r'(\d+)\s+(\d+)\s+(ACCEPT|SKIPDATA)', r'\3', data)
                    # Combine timestamp and data with a space
                    combined = f"{timestamp} {data}\n"
                    outfile.write(combined)
                    i += 2
                else:
                    i += 1
            else:
                i += 1

if __name__ == "__main__":
    input_file = "vpc-flow-logs-datahub-example/sample_1.csv"
    output_file = "vpc-flow-logs-datahub-example/sample_1_formatted.csv"
    
    try:
        format_vpc_logs(input_file, output_file)
        print(f"Successfully formatted VPC logs from {input_file} to {output_file}")
    except FileNotFoundError as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
