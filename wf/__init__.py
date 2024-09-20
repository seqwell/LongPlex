from wf.task import run_longplex_demux

from latch.resources.launch_plan import LaunchPlan
from latch.resources.workflow import workflow
from latch.types.directory import LatchDir, LatchOutputDir
from latch.types.file import LatchFile
from latch.types.metadata import LatchAuthor, LatchMetadata, LatchParameter, LatchRule

"""The metadata included here will be injected into your interface."""
metadata = LatchMetadata(
    display_name="LongPlex Demux",
    documentation="https://github.com/seqwell/LongPlex",
    author=LatchAuthor(name="seqWell"),
    parameters={
        "samplesheet": LatchParameter(
            display_name="Sample Sheet",
            description="CSV file containing samples with headers: sample_ID, sample_path, i7_barcode, i5_barcode",
            batch_table_column=True,
            rules=[
                LatchRule(
                    regex="(.csv)$",
                    message="Only '.csv' extension is valid!",
                )
            ],
        ),
        "output_directory": LatchParameter(
            display_name="Output Directory",
            description="Where to place the results.",
            batch_table_column=True,
        ),
    },
)


@workflow(metadata)
def longplex_demux(samplesheet: LatchFile, output_directory: LatchOutputDir) -> LatchDir:
    return run_longplex_demux(samplesheet=samplesheet, output_directory=output_directory)


LaunchPlan(
    longplex_demux,
    # "Test Data",
    # {
    #     "samplesheet": LatchFile("s3://latch-public/init/nfcore_example_ids.csv"),
    #     "output_directory": LatchOutputDir("latch:///nfcore_fetchngs_output"),
    # },
)
