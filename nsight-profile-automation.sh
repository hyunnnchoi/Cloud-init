#!/bin/bash

BASE_DIR=$(pwd)
NSYS_REP_DIR="$BASE_DIR/nsys-rep-combined"
OUTPUT_DIR="$BASE_DIR/nsys-processed"
FINAL_EXCEL_FILE="$OUTPUT_DIR/combined_results.xlsx"

pip install pandas openpyxl

echo "Step 0: Moving all worker_0.nsys-rep files to $NSYS_REP_DIR..."
mkdir -p "$NSYS_REP_DIR"
find "$BASE_DIR" -type f -name "*worker_0.nsys-rep" -exec cp {} "$NSYS_REP_DIR" \;
echo "All worker_0.nsys-rep files have been moved to $NSYS_REP_DIR!"

mkdir -p "$OUTPUT_DIR"

for nsys_file in $(ls "$NSYS_REP_DIR"/*.nsys-rep | sort -V); do
    full_file_name=$(basename "$nsys_file" .nsys-rep)
    sqlite_file="$NSYS_REP_DIR/$full_file_name.sqlite"
    csv_file="$OUTPUT_DIR/$full_file_name.csv"
    csv_with_hij="$OUTPUT_DIR/${full_file_name}_with_hij.xlsx"

    echo "Processing: $full_file_name"

    nsys stats "$nsys_file" -o "$sqlite_file" --force-export=true

    nsys analyze -r "gpu_gaps:gap=1:rows=5000" "$sqlite_file" | \
    tail -n +3 | sort -k 3 -n | \
    awk 'BEGIN {print "Row#,Duration,Start,PID,Device ID,Context ID"} NR < 1 || NR > 14 {print $1","$2","$3","$4","$5","$6}' > "$csv_file"

    python3 - <<EOF
import pandas as pd
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Alignment

input_csv = "$csv_file"
output_excel = "$csv_with_hij"

data = pd.read_csv(input_csv)
data["H"] = data["Duration"]
data["I"] = data["Start"]

data["J"] = None
for i in range(1, len(data)):
    prev_row = data.iloc[i - 1]
    current_row = data.iloc[i]
    data.at[i, "J"] = current_row["I"] - (prev_row["I"] + prev_row["H"])

data.to_excel(output_excel, index=False, sheet_name="Sheet1")

wb = load_workbook(output_excel)
ws = wb.active

ws["N3"] = "COMPUTE TIME"
ws["O3"] = "=SUM(I:I)"
ws["N4"] = "NETWORK TIME"
ws["O4"] = "=SUM(G:G)"

ws["N10"] = "COMPUTE/10 (s)"
ws["O10"] = "=O3/1000000000/10"
ws["N11"] = "NETWORK/10 (s)"
ws["O11"] = "=O4/1000000000/10"

for cell in ["N3", "N4", "N10", "N11"]:
    ws[cell].alignment = Alignment(horizontal="center")
for cell in ["O3", "O4", "O10", "O11"]:
    ws[cell].alignment = Alignment(horizontal="center")

wb.save(output_excel)
EOF

    echo "Completed: $full_file_name"
done

echo "Step 4: Combining all Excel files into one with Summary sheet..."

python3 - <<EOF
from openpyxl import load_workbook, Workbook
import os

output_dir = "$OUTPUT_DIR"
final_excel_file = "$FINAL_EXCEL_FILE"

wb_combined = Workbook()
wb_combined.remove(wb_combined.active)

summary_data = [["Sheet Name", "COMPUTE/10 (s)", "NETWORK/10 (s)"]]

for file_name in sorted(os.listdir(output_dir), key=lambda x: int(x.split('_')[0][1:]) if x.startswith('t') else x):
    if file_name.endswith("_with_hij.xlsx"):
        file_path = os.path.join(output_dir, file_name)
        wb = load_workbook(file_path)
        sheet_name = file_name.replace("_with_hij.xlsx", "")
        sheet_name_short = sheet_name[:31]
        sheet = wb.active

        new_sheet = wb_combined.create_sheet(title=sheet_name_short)
        for row in sheet.iter_rows(values_only=True):
            new_sheet.append(row)

        compute_10 = f"='{sheet_name_short}'!O10"
        network_10 = f"='{sheet_name_short}'!O11"
        summary_data.append([sheet_name_short, compute_10, network_10])

summary_sheet = wb_combined.create_sheet(title="Summary", index=0)
for row in summary_data:
    summary_sheet.append(row)

wb_combined.save(final_excel_file)
print(f"All Excel files have been combined into {final_excel_file} with a Summary sheet.")
EOF

echo "모든 파일 처리 완료! 최종 통합 파일과 Summary 시트는 $FINAL_EXCEL_FILE에 저장되었습니다."
