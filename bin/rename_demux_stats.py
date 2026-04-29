#!/usr/bin/env python3
import sys
import csv

def rename_stats(report_path, map_path, output_path):
    # 1. Load the map using index rather than header names
    rename_map = {}
    with open(map_path, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 2:
                continue
            # Column 0: bc1015.A01 | Column 1: bc1015.sample1
            key = row[0].strip()
            val = row[1].strip()
            rename_map[key] = val

    # 2. Process the report
    output_rows = []
    with open(report_path, 'r') as f:
        reader = csv.reader(f)
        
        for row in reader:
            # Handle empty rows or summary rows at the bottom
            if not row or not row[0] or row[0].startswith('###') or row[0] == 'well':
                output_rows.append(row)
                continue

            # Original label: seqwell_UDI1_A01
            original_label = row[0]
            
            # Extract the well (e.g., A01) from the end of the report label
            # This handles 'seqwell_UDI1_A01' -> 'A01'
            well_part = original_label.split('_')[-1]
            
            new_label = original_label
            # Match 'A01' against map keys like 'bc1015.A01'
            for map_key, sample_id in rename_map.items():
                if map_key.endswith(well_part):
                    new_label = sample_id
                    break
            
            row[0] = new_label
            output_rows.append(row)

    # 3. Write output
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(output_rows)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(1)
    rename_stats(sys.argv[1], sys.argv[2], sys.argv[3])
