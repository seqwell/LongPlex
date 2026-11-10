#!/usr/bin/env python3
"""Build a combined ConsensusReadSet XML from a pool's demultiplexed BAMs.

Equivalent to:
    dataset create --generateIndices --force --type ConsensusReadSet \
        <pool_id>.combined.consensusreadset.xml <bams...>
"""
import argparse
import os
import subprocess

import numpy as np
from pbcore.io import ConsensusReadSet


def build_combined_dataset(inputs, pool_id, threads=2, prefix=None):
    # inputs may be a mixed list of .bam and .bam.pbi paths (MERGE_READS
    # emits both together as bam_w_index) -- separate them out.
    bams = [f for f in inputs if f.endswith(".bam")]
    prefix = prefix or f"{pool_id}.combined"

    for bam in bams:
        if not os.path.exists(bam + ".pbi"):
            subprocess.run(["pbindex", "-j", str(threads), bam], check=True)

    ds = ConsensusReadSet(*bams, strict=True)
    ds.name = prefix

    # pbcore sums int32 qStart/qEnd with Python's sum(), which overflows past
    # ~2.1 Gb under NumPy 2; recompute in int64.
    lengths = ds.index.qEnd.astype(np.int64) - ds.index.qStart.astype(np.int64)
    ds.metadata.totalLength = int(lengths.sum())
    ds.metadata.numRecords = int(len(lengths))

    xml_path = f"{prefix}.consensusreadset.xml"
    ds.write(xml_path)
    return xml_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pool_id")
    parser.add_argument("inputs", nargs="+", help="bam and/or bam.pbi files")
    parser.add_argument("-j", "--threads", type=int, default=2)
    parser.add_argument("--prefix", default=None, help="output prefix and dataset name (default: <pool_id>.combined)")
    args = parser.parse_args()

    xml_path = build_combined_dataset(args.inputs, args.pool_id, args.threads, args.prefix)
    print(f"Combined dataset: {xml_path}")


if __name__ == "__main__":
    main()
