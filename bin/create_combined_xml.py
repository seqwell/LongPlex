#!/usr/bin/env python3
"""Build a combined ConsensusReadSet XML from a pool's demultiplexed BAMs.

Equivalent to:
    dataset create --generateIndices --force --type ConsensusReadSet \
        <pool_id>.combined.consensusreadset.xml <bams...>
"""
import argparse
import os
import subprocess

from pbcore.io import ConsensusReadSet


def build_combined_dataset(inputs, pool_id, threads=2):
    # inputs may be a mixed list of .bam and .bam.pbi paths (MERGE_READS
    # emits both together as bam_w_index) -- separate them out.
    bams = [f for f in inputs if f.endswith(".bam")]

    for bam in bams:
        if not os.path.exists(bam + ".pbi"):
            subprocess.run(["pbindex", "-j", str(threads), bam], check=True)

    ds = ConsensusReadSet(*bams, strict=True)
    ds.name = f"{pool_id} (combined)"

    xml_path = f"{pool_id}.combined.consensusreadset.xml"
    ds.write(xml_path)
    return xml_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pool_id")
    parser.add_argument("inputs", nargs="+", help="bam and/or bam.pbi files")
    parser.add_argument("-j", "--threads", type=int, default=2)
    args = parser.parse_args()

    xml_path = build_combined_dataset(args.inputs, args.pool_id, args.threads)
    print(f"Combined dataset: {xml_path}")


if __name__ == "__main__":
    main()
