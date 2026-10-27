
#!/usr/bin/env python3
"""Create a per-sample PacBio ConsensusReadSet XML."""

import argparse
from pathlib import Path
import xml.etree.ElementTree as ET
from urllib.parse import urlparse, unquote
import numpy as np

from pbcore.io import ConsensusReadSet


def create_sample_dataset(pool_id, sample_id, output_dir, inputs):
    bams = sorted(
        Path(p).resolve()
        for p in inputs
        if p.endswith(".bam")
    )

    if len(bams) != 1:
        raise ValueError(
            f"Expected exactly one merged BAM for {sample_id}; "
            f"found {len(bams)}"
        )

    bam = bams[0]

    if not Path(str(bam) + ".pbi").exists():
        raise FileNotFoundError(f"Missing PBI index: {bam}.pbi")

    if not Path(str(bam) + ".bai").exists():
        raise FileNotFoundError(f"Missing BAI index: {bam}.bai")

    output_base = Path(output_dir)

    if not output_base.is_absolute():
        raise ValueError(
            f"Output directory must be an absolute path: {output_base}"
        )

    published_dir = output_base / pool_id / "merged_bam"

    xml_path = Path(
        f"{sample_id}.consensusreadset.xml"
    )

    ds = ConsensusReadSet(str(bam), strict=True)
    # Recalculate total read length using 64-bit arithmetic.
    read_lengths = (
        ds.index.qEnd.astype(np.int64)
        - ds.index.qStart.astype(np.int64)
    )

    total_length = int(np.sum(read_lengths, dtype=np.int64))
    num_records = len(read_lengths)

    ds.metadata.totalLength = total_length
    ds.metadata.numRecords = num_records
    ds.name = sample_id
    ds.newUuid()
    ds.write(str(xml_path))

    # Rewrite staged resource locations to published BAM locations.
    tree = ET.parse(xml_path)
    root = tree.getroot()

    allowed_resources = {
        bam.name,
        bam.name + ".pbi",
        bam.name + ".bai",
    }

    for element in root.iter():
        resource = element.get("ResourceId")

        if not resource:
            continue

        parsed = urlparse(resource)

        if parsed.scheme == "file":
            filename = Path(unquote(parsed.path)).name
        elif parsed.scheme == "":
            filename = Path(resource).name
        else:
            raise ValueError(
                f"Unsupported resource URI: {resource}"
            )

        if filename not in allowed_resources:
            raise ValueError(
                f"Unexpected dataset resource: {resource}"
            )

        published_path = published_dir / filename
        element.set("ResourceId", str(published_path))

    tree.write(
        xml_path,
        encoding="utf-8",
        xml_declaration=True
    )

    ns = {"pbds": "http://pacificbiosciences.com/PacBioDatasets.xsd"}

    written_tree = ET.parse(xml_path)
    written_total = written_tree.findtext(
        ".//pbds:TotalLength", namespaces=ns
    )

    if written_total != str(total_length):
        raise ValueError(
            f"Incorrect serialized TotalLength: {written_total}; "
            f"expected {total_length}"
        )
    print(f"Created: {xml_path}")
    print(f"Sample: {sample_id}")
    print(f"BAM: {published_dir / bam.name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pool-id", required=True)
    parser.add_argument("--sample-id", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument(
        "inputs",
        nargs="+",
        help="Merged BAM and index files"
    )
    args = parser.parse_args()

    create_sample_dataset(
        args.pool_id,
        args.sample_id,
        args.output_dir,
        args.inputs
    )


if __name__ == "__main__":
    main()
