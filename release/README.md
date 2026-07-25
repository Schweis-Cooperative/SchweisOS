# SchweisOS Release Artifacts

Version: 0.1
Status: Active
Date: 2026-07-25

This directory is the canonical local staging root for SchweisOS release
artifacts.

Generated release directories are not version-controlled. A successful future
release artifact preparation step creates one immutable directory per release:

```text
release/
    YYYY.MM/
        iso/
        checksum/
        manifests/
        logs/
        RELEASE_NOTES.md
```

The release identifier uses the `YYYY.MM` format. The artifact pipeline must
never overwrite an existing release directory. If a release must be replaced,
the existing directory must be reviewed and removed explicitly outside the
pipeline.

This directory is not a publication endpoint. It is local release evidence that
can later feed signing, repository publication, mirror synchronization, and
GitHub release steps.
