
from dataclasses import dataclass
import typing
import typing_extensions

from flytekit.core.annotation import FlyteAnnotation

from latch.types.metadata import NextflowParameter
from latch.types.file import LatchFile
from latch.types.directory import LatchDir, LatchOutputDir

# Import these into your `__init__.py` file:
#
# from .parameters import generated_parameters

generated_parameters = {
    'samplesheet': NextflowParameter(
        type=LatchFile,
        default=None,
        section_tile='Input & Output Options',
        description='CSV file containing samples with headers: sample_ID, sample_path, i7_barcode, i5_barcode',
    ),
    'output': NextflowParameter(
        type=LatchOutputDir,
        default=None,
        section_tile='Input & Output Options',
        description='Output directory',
    )
}

