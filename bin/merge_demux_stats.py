#!/usr/bin/env python3
import argparse
import pandas as pd
import sys
import re
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Merge two-step lima + NanoStat stats into demux table")
    parser.add_argument("--report-both",          required=True,  help="lima_both.lima.report")
    parser.add_argument("--report-either",         required=True,  help="lima_either.lima.report")
    parser.add_argument("--counts-both",           required=True,  help="lima_both.lima.counts")
    parser.add_argument("--counts-either",         required=True,  help="lima_either.lima.counts")
    parser.add_argument("--nanostat",              required=True,  nargs="+", help="Per-sample NanoStat .txt files")
    parser.add_argument("--unbarcoded-nanostat",   required=True,  help="NanoStat .txt for unbarcoded BAM")
    parser.add_argument("--sample-map",            required=False, default=None,
                        help="Optional CSV with pool_ID.well_ID and sample_ID columns")
    parser.add_argument("--output",                required=True,  help="Output CSV for per-barcode stats")
    parser.add_argument("--summary-output",        required=True,  help="Output CSV for per-pool summary")
    return parser.parse_args()


def extract_well(barcode_name):
    """
    Extract well ID from lima barcode name.
    e.g. seqwell_UDI1_A01_P7 -> A01
         seqwell_UDI1_A01_P5 -> A01
    """
    m = re.search(r'([A-H]\d{2})', str(barcode_name))
    return m.group(1) if m else None


def infer_pool_id(counts_both_path):
    """
    Infer pool_ID from the both-end counts filename.
    e.g. i7_i5_bc1015.lima.counts -> bc1015
    """
    stem    = Path(counts_both_path).stem   # i7_i5_bc1015.lima
    stem    = stem.replace(".lima", "")     # i7_i5_bc1015
    pool_id = stem.split("_")[-1]          # bc1015
    return pool_id


def load_report(path, step_label):
    """
    Load lima .lima.report file.
    Uses ScoreCombined which matches MeanScore in .lima.counts.
    Returns dataframe with columns: Barcode, Score, step, well_ID
    """
    df = pd.read_csv(path, sep="\t")
    df.columns = [c.strip() for c in df.columns]

    score_col = None
    for candidate in ["ScoreCombined", "ScoreLead", "Score"]:
        if candidate in df.columns:
            score_col = candidate
            break

    barcode_col = next((c for c in df.columns if "CombinedNamed" in c or c == "BarcodeNamed"), None)

    if not score_col or not barcode_col:
        print(f"[ERROR] Cannot find Score or Barcode column in {path}", file=sys.stderr)
        print(f"  Available columns: {list(df.columns)}", file=sys.stderr)
        sys.exit(1)

    print(f"[info] Using score column: '{score_col}' from {path}", file=sys.stderr)

    df = df[[barcode_col, score_col]].copy()
    df.columns = ["Barcode", "Score"]
    df["step"]    = step_label
    df["well_ID"] = df["Barcode"].apply(extract_well)
    return df


def load_counts(path, group_by_well=False):
    """
    Load lima .lima.counts file.
    group_by_well=False: both-end — one row per well (P7 name only)
    group_by_well=True:  either-end — two rows per well (P5 + P7), sum them
    Returns (df with columns: well_ID, Counts), not_barcoded_count
    """
    df = pd.read_csv(path, sep="\t")
    df.columns = [c.strip() for c in df.columns]

    barcode_col = next((c for c in df.columns if "CombinedNamed" in c or c == "BarcodeNamed"), None)
    count_col   = next((c for c in df.columns if c.lower() == "counts"), None)

    if not barcode_col or not count_col:
        print(f"[ERROR] Cannot find Barcode or Counts column in {path}", file=sys.stderr)
        print(f"  Available columns: {list(df.columns)}", file=sys.stderr)
        sys.exit(1)

    df = df[[barcode_col, count_col]].copy()
    df.columns   = ["Barcode", "Counts"]
    df["well_ID"] = df["Barcode"].apply(extract_well)

    not_barcoded_count = df[df["well_ID"].isna()]["Counts"].sum()
    df_barcoded        = df[df["well_ID"].notna()].copy()

    if group_by_well:
        # Either-end: P5 and P7 are separate rows — sum per well
        df_barcoded = (
            df_barcoded
            .groupby("well_ID")
            .agg(Counts=("Counts", "sum"))
            .reset_index()
        )
    else:
        # Both-end: already one row per well (P7 name)
        df_barcoded = df_barcoded[["well_ID", "Counts"]].copy()

    return df_barcoded, not_barcoded_count


def load_sample_map(path, pool_id=None):
    """
    Load sample map CSV with columns: pool_ID.well_ID, sample_ID
    Filters to only entries matching pool_id if provided.
    Returns:
      - df with columns: pool_well_key, Sample_Name, well_ID
      - sample_to_well dict: sample_id_suffix -> well_ID
    """
    df = pd.read_csv(path)
    df.columns = [c.strip() for c in df.columns]

    well_col   = next((c for c in df.columns if "well" in c.lower() or "pool" in c.lower()), None)
    sample_col = next((c for c in df.columns if "sample" in c.lower()), None)

    if not well_col or not sample_col:
        print(f"[ERROR] Cannot find pool_ID.well_ID or sample_ID columns in {path}", file=sys.stderr)
        print(f"  Available columns: {list(df.columns)}", file=sys.stderr)
        sys.exit(1)

    df = df[[well_col, sample_col]].rename(
        columns={well_col: "pool_well_key", sample_col: "Sample_Name"}
    )
    df["well_ID"] = df["pool_well_key"].apply(lambda x: x.split(".")[-1])

    # Filter to only this pool's entries
    if pool_id:
        before = len(df)
        df     = df[df["pool_well_key"].str.startswith(pool_id + ".")].copy()
        print(f"[info] Sample map filtered: {before} -> {len(df)} entries for pool {pool_id}",
              file=sys.stderr)

    if df.empty:
        print(f"[WARN] No sample map entries found for pool {pool_id}", file=sys.stderr)

    # Reverse lookup: sample_id suffix -> well_ID
    sample_to_well = dict(
        zip(
            df["Sample_Name"].apply(lambda x: x.split(".")[-1]),
            df["well_ID"]
        )
    )
    print(f"[debug] sample_to_well for {pool_id}: {sample_to_well}", file=sys.stderr)

    return df, sample_to_well


def _parse_nanostat_metrics(path):
    """
    Shared parser for NanoStat --tsv format:
      number_of_reads    344
      number_of_bases    1575809.0
      mean_read_length   4580.8
      median_qual        39.8
    Returns dict of key -> float.
    """
    metrics = {}
    with open(path) as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) == 2:
                key, val = parts[0].strip(), parts[1].strip()
                try:
                    metrics[key] = float(val.replace(",", ""))
                except ValueError:
                    pass
    if not metrics:
        print(f"[WARN] No metrics parsed from {path}", file=sys.stderr)
    return metrics


def parse_nanostat_file(path, sample_to_well=None):
    """
    Parse a per-well NanoStat file.
    Filename: bc1015.sample1_nanostat.txt -> pool_well_key=bc1015.sample1
    well_ID resolved via sample_to_well lookup, else regex fallback.
    """
    stem          = Path(path).stem                        # bc1015.sample1_nanostat
    pool_well_key = stem.replace("_nanostat", "").strip()  # bc1015.sample1
    suffix        = pool_well_key.split(".")[-1]           # sample1 or A01

    if sample_to_well and suffix in sample_to_well:
        well_id = sample_to_well[suffix]
    else:
        m       = re.search(r'([A-H]\d{2})', suffix)
        well_id = m.group(1) if m else suffix

    metrics = _parse_nanostat_metrics(path)

    return {
        "pool_well_key":  pool_well_key,
        "well_ID":        well_id,
        "MeanReadLength": metrics.get("mean_read_length"),
        "MedianQuality":  metrics.get("median_qual"),
        "TotalBases":     metrics.get("number_of_bases"),
    }


def parse_unbarcoded_nanostat(path):
    """
    Parse NanoStat output for the unbarcoded BAM.
    Returns dict with MeanReadLength and TotalBases.
    """
    metrics = _parse_nanostat_metrics(path)
    return {
        "MeanReadLength": metrics.get("mean_read_length"),
        "TotalBases":     metrics.get("number_of_bases"),
    }


def write_pool_summary(final_df, not_barcoded_reads, unbarcoded_nano, output_path):
    """
    Generate per-pool run-level summary table.
    Writes plain CSV without quoting of values containing commas.
    """
    barcoded_reads   = final_df["HiFi_Reads_count"].sum()
    unbarcoded_reads = not_barcoded_reads
    total_reads      = barcoded_reads + unbarcoded_reads

    barcoded_yield   = final_df["HiFi_Yield(bp)"].sum()
    unbarcoded_yield = unbarcoded_nano.get("TotalBases") or 0
    total_yield      = barcoded_yield + unbarcoded_yield

    valid = final_df[final_df["Mean_HiFi_Read_Length(bp)"].notna()].copy()
    if len(valid) > 0:
        barcoded_mean_len = (
            (valid["Mean_HiFi_Read_Length(bp)"] * valid["HiFi_Reads_count"]).sum()
            / valid["HiFi_Reads_count"].sum()
        )
    else:
        barcoded_mean_len = None

    unbarcoded_mean_len = unbarcoded_nano.get("MeanReadLength")

    def fmt_gb(val):
        return f"{val / 1e9:.2f} Gb" if val else "N/A"

    def fmt_kb(val):
        return f"{val / 1000:.2f} kb" if val else "N/A"

    def fmt_pct(num, den):
        return f"{100 * num / den:.2f}%" if den > 0 else "N/A"

    rows = [
        ("Unique Barcodes",
         str(int(final_df["Barcode"].nunique()))),

        ("Barcoded HiFi Reads",
         str(int(barcoded_reads))),

        ("Unbarcoded HiFi Reads",
         str(int(unbarcoded_reads))),

        ("Barcoded HiFi Reads (%)",
         fmt_pct(barcoded_reads, total_reads)),

        ("Barcoded HiFi Yield (Gb)",
         fmt_gb(barcoded_yield)),

        ("Unbarcoded HiFi Yield (Gb)",
         fmt_gb(unbarcoded_yield)),

        ("Barcoded HiFi Yield (%)",
         fmt_pct(barcoded_yield, total_yield)),

        ("Mean HiFi Reads per Barcode",
         str(int(barcoded_reads / max(final_df["Barcode"].nunique(), 1)))),

        ("Max HiFi Reads per Barcode",
         str(int(final_df["HiFi_Reads_count"].max()))),

        ("Min HiFi Reads per Barcode",
         str(int(final_df["HiFi_Reads_count"].min()))),

        ("Barcoded HiFi Read Length (mean kb)",
         fmt_kb(barcoded_mean_len)),

        ("Unbarcoded HiFi Read Length (mean kb)",
         fmt_kb(unbarcoded_mean_len)),
    ]

    summary_df = pd.DataFrame(rows, columns=["Analysis_Metric", "Value"])

    # Write without quoting — avoids pandas adding quotes around values with commas
    with open(output_path, "w") as f:
        f.write("Analysis_Metric,Value\n")
        for _, row in summary_df.iterrows():
            f.write(f"{row['Analysis_Metric']},{row['Value']}\n")

    print(f"[done] Pool summary written: {output_path}", file=sys.stderr)
    print(summary_df.to_string(index=False))


def main():
    args = parse_args()

    # ── Infer pool_ID from counts filename ────────────────────────────────────
    pool_id = infer_pool_id(args.counts_both)
    print(f"[info] Inferred pool_ID: {pool_id}", file=sys.stderr)

    # ── 1. Barcode Quality — per-read ScoreCombined, grouped by well_ID ──────
    rep_both   = load_report(args.report_both,   "both")
    rep_either = load_report(args.report_either, "either")
    all_reads  = pd.concat([rep_both, rep_either], ignore_index=True)

    all_reads_barcoded = all_reads[all_reads["well_ID"].notna()].copy()

    bq = (
        all_reads_barcoded
        .groupby("well_ID")
        .agg(Barcode_Quality=("Score", "mean"))
        .round({"Barcode_Quality": 1})
        .reset_index()
    )
    print(f"[debug] Barcode quality computed for {len(bq)} wells", file=sys.stderr)

    # ── 2. HiFi Read Counts ───────────────────────────────────────────────────
    cnt_both_df,   nb_both   = load_counts(args.counts_both,   group_by_well=False)
    cnt_either_df, nb_either = load_counts(args.counts_either, group_by_well=True)

    not_barcoded_reads = nb_both + nb_either
    print(f"[debug] Not Barcoded reads: both={nb_both} either={nb_either} "
          f"total={not_barcoded_reads}", file=sys.stderr)

    counts_by_well = pd.merge(
        cnt_both_df.rename(columns={"Counts": "Counts_both"}),
        cnt_either_df.rename(columns={"Counts": "Counts_either"}),
        on="well_ID", how="outer"
    ).fillna(0)
    counts_by_well["HiFi_Reads_count"] = (
        counts_by_well["Counts_both"] + counts_by_well["Counts_either"]
    )
    counts_by_well = counts_by_well[["well_ID", "HiFi_Reads_count"]]
    print(f"[debug] Wells with read counts: {len(counts_by_well)}", file=sys.stderr)

    # ── 3. Sample map (before NanoStat — needed for well_ID lookup) ───────────
    if args.sample_map:
        sample_map_df, sample_to_well = load_sample_map(args.sample_map, pool_id=pool_id)
        print(f"[info] Sample map loaded: {len(sample_map_df)} entries for {pool_id}",
              file=sys.stderr)
    else:
        sample_map_df  = None
        sample_to_well = None
        print("[info] No sample map — Sample_Name defaults to pool_well_key", file=sys.stderr)

    # ── 4. NanoStat per well — filter to this pool only ──────────────────────
    pool_nanostat = [
        f for f in args.nanostat
        if Path(f).name.startswith(pool_id + ".")
        or Path(f).name.startswith(pool_id + "_")
    ]
    if not pool_nanostat:
        print(f"[WARN] No NanoStat files matched pool {pool_id} — using all files",
              file=sys.stderr)
        pool_nanostat = args.nanostat

    print(f"[debug] NanoStat files for pool {pool_id}: "
          f"{[Path(f).name for f in pool_nanostat]}", file=sys.stderr)

    nano_rows = [parse_nanostat_file(f, sample_to_well=sample_to_well)
                 for f in pool_nanostat]
    nano = pd.DataFrame(nano_rows)
    print(f"[debug] NanoStat wells:\n{nano[['pool_well_key','well_ID']].to_string()}",
          file=sys.stderr)

    # ── 5. NanoStat unbarcoded ────────────────────────────────────────────────
    unbarcoded_nano = parse_unbarcoded_nanostat(args.unbarcoded_nanostat)
    print(f"[debug] Unbarcoded NanoStat: {unbarcoded_nano}", file=sys.stderr)

    # ── 6. Merge everything on well_ID ────────────────────────────────────────
    final = (
        bq
        .merge(counts_by_well, on="well_ID", how="outer")
        .merge(
            nano[["well_ID", "pool_well_key", "MeanReadLength", "MedianQuality", "TotalBases"]],
            on="well_ID", how="left"
        )
    )

    # Sample_Name and Barcode resolution
    if sample_map_df is not None and not sample_map_df.empty:
        final = final.merge(
            sample_map_df[["well_ID", "Sample_Name", "pool_well_key"]],
            on="well_ID", how="left",
            suffixes=("", "_map")
        )
        final["Sample_Name"] = final["Sample_Name"].fillna(
            final["pool_well_key_map"].fillna(final["well_ID"])
        )
        # Barcode = original pool_well_key from sample map (e.g. bc1015.A01)
        final["Barcode"] = final["pool_well_key_map"].fillna(final["well_ID"])
    else:
        final["Sample_Name"] = final["pool_well_key"].fillna(final["well_ID"])
        final["Barcode"]     = final["pool_well_key"].fillna(final["well_ID"])

    # ── 7. Filter: keep only rows with HiFi Yield reported ───────────────────
    before = len(final)
    final  = final[final["TotalBases"].notna()].copy()
    after  = len(final)
    print(f"[info] Removed {before - after} rows with no HiFi Yield (bleed-through barcodes)",
          file=sys.stderr)

    # ── 8. Select, rename, sort, write per-barcode CSV ────────────────────────
    final = final[[
        "Sample_Name", "Barcode", "Barcode_Quality",
        "HiFi_Reads_count", "MeanReadLength", "MedianQuality", "TotalBases"
    ]].rename(columns={
        "MeanReadLength": "Mean_HiFi_Read_Length(bp)",
        "MedianQuality":  "Median_HiFi_Read_Quality",
        "TotalBases":     "HiFi_Yield(bp)",
    })

    final = final.sort_values("HiFi_Reads_count", ascending=False)
    final.to_csv(args.output, sep=",", index=False)
    print(f"[done] Per-barcode stats written: {args.output}", file=sys.stderr)
    print(final.to_string(index=False))

    # ── 9. Write per-pool summary ─────────────────────────────────────────────
    write_pool_summary(
        final_df=final,
        not_barcoded_reads=not_barcoded_reads,
        unbarcoded_nano=unbarcoded_nano,
        output_path=args.summary_output
    )


if __name__ == "__main__":
    main()
