## Development Environment

A development environment for running the pipeline and executing tests can be created with [`mamba`](https://mamba.readthedocs.io/en/latest/installation/mamba-installation.html).

After installing mamba, the development environment can be created and activated with:

```bash
mamba env create --file environment-dev.yml
mamba activate longplex-nf-dev
```

The integration tests can be run with:

```bash
pytest --tag integration
```

## Before Release

Before creating a new release, confirm `wf/entrypoint` has been updated to pass any newly added parameters to the underlying workflow.

## Creating a New Release

### Update the Version

In your local copy of the repository checkout the commit you wish to use for the next release.

Typically, this will be the latest commit on main.

```console
git checkout main
git pull
```

Update the version stored in the `version` file.
See [sematic versioning](https://semver.org/) for guidance on picking an appropriate version number.

Create a commit with the updated version file where `#.#.#` is the newly picked semantic version.

```console
git add version
git commit -m "chore: update to version #.#.#"
```

### Register the Workflow

```console
latch login
latch register .
```

> [!WARNING]
> Do not run `latch register . -nf-script main.nf --nf-execution-profile docker` as this will overwrite the custom `wf/entrypoint.py` file.

### Commit and Push Release to GitHub

```console
git add .latch/Dockerfile
git commit -m "chore: update Latch resource files"
```

Tag the commit with the version for traceability:

```console
git tag #.#.#
```

Push the commits and tag up to GitHub.

```console
git push --follow-tags
```

### Promote the Registered Workflow on Latch

1. On [Latch](https://console.latch.bio/workflows/), select the "seqWell LongPlex Demux" workflow.
2. Select the "Development" tab.
3. Expand the dropdown for the appropriate version.
4. Create an alias for the version, `v#.#.#`.
5. Fill in the "Version Notes" with a list of changes made since the previous release.
6. Select "Release".
7. Select "Make Public".
8. Select "Confirm".

### Switch the Main Branch version to a Dev Version

Follow the instructions under "Update the Version" but specify a dev version, `#.#.#-dev`.
Push the change to GitHub.
