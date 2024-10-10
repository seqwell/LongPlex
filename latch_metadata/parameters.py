
from dataclasses import dataclass
import typing
import typing_extensions
from pathlib import Path
import csv

from flytekit.core.annotation import FlyteAnnotation

from latch.types.metadata import NextflowParameter
from latch.types.file import LatchFile
from latch.types.directory import LatchDir, LatchOutputDir

POOL_ID: str = "pool_ID"
POOL_PATH: str = "pool_path"
I7_PATH: str = "i7_barcode"
I5_PATH: str = "i5_barcode"

@dataclass(frozen=True)
class Pool:
    """Describes a seqWell Longplex sequencing pool

    Attributes:
        pool_ID: Name of the sequencing pool
        pool_path: Path to unmapped BAM file
        i7_barcode: Path to i7 barcodes in fasta format
        i5_barcode: Path to i5 barcodes in fasta format 
    """
    pool_ID: str
    pool_path: LatchFile
    i7_barcode: LatchFile
    i5_barcode: LatchFile

# Import these into your `__init__.py` file:
#
# from .parameters import generated_parameters

generated_parameters = {
    "pool_sheet": NextflowParameter(
        type=typing.List[Pool],
        default=None,
        samplesheet=True,
        samplesheet_type="csv",
        section_title="Input & Output Options",
        description="CSV file containing pools with headers: pool_ID, pool_path, i7_barcode, i5_barcode",
    ),
    "output": NextflowParameter(
        type=LatchOutputDir,
        default=None,
        section_title="Input & Output Options",
        description="Output directory",
    )
}
