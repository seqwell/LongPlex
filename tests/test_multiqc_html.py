from pathlib import Path
import glob
import pytest

@pytest.mark.workflow('LongPlex Integration Test')
def test_multiqc_html(workflow_dir):
    multiqc_html = glob.glob(str(Path(workflow_dir, "output")))
    assert len(multiqc_html) != 0
