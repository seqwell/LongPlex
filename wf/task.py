import subprocess
from pathlib import Path

from latch.functions.messages import message
from latch.resources.tasks import medium_task
from latch.types.directory import LatchDir, LatchOutputDir
from latch.types.file import LatchFile


@medium_task
def run_longplex_demux(samplesheet: LatchFile, output_directory: LatchOutputDir) -> LatchDir:
    output = Path("/root/outputs").resolve()
    output.mkdir(exist_ok=True)

    command = [
        "nextflow",
        "-log",
        "output/nextflow.log",
        "run",
        "-resume",
        "-profile",
        "docker",
        "main.nf",
        "--samplesheet",
        samplesheet.local_path,
        "--output",
        str(output),
    ]

    try:
        subprocess.run(command, check=True, capture_output=True)
    except subprocess.CalledProcessError as exception:
        stderr = exception.stderr.decode("utf-8")
        if stderr:
            message(
                "error",
                {"title": "seqWell LongPlex Demux failed", "body": f"Stderr: {stderr}"},
            )
        print(stderr)
        raise exception

    return LatchDir(path=str(output), remote_path=output_directory.remote_path)
