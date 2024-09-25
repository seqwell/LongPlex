## Development Environment

A development environment for running the pipeline and executing tests can be created with [`mamba`](https://mamba.readthedocs.io/en/latest/installation/mamba-installation.html).

After installing mamba, the development environment can be created and activated with:
```bash
mamba env create --file environment-dev.yml
mamba activate longplex-nf-dev
```

The integration tests can be run with
```bash
pytest --tag integration
```
