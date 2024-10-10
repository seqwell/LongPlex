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

## Creating a New Release

In your local copy of the repository checkout the commit you wish to use for the next release.

Typically, this will be the latest commit on main.

```console
git checkout main
git pull
```

Update the version stored in the `version` file.
See [sematic versioning](https://semver.org/) for guidance on picking an appropriate version number.

Create a commit with the updated version file.

```console
git add version
git commit -m "chore: update to version D.D.D"
```

Register the workflow:

```console
latch login
latch register . --nf-script main.nf --nf-execution-profile docker
```

Create and tag a commit with the updated Latch files.

```console
git add .latch/Dockerfile
git add wf/entrypoint.py
git commit -m "chore: update Latch resource files"
```

Tag the commit with the version for traceability:

```console
git tag D.D.D
```

Push the commits and tag up to GitHub.

```console
git push --follow-tags
```
