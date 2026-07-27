# SchweisOS Release Artifacts

Version: 0.3
Status: Active staging root
Date: 2026-07-27

This directory is the canonical local staging root for SchweisOS release
artifacts.

Generated release directories are not version-controlled. A successful release
artifact preparation step creates one immutable directory per release:

```text
release/
    YYYY.MM.DD/
        iso/
        checksum/
        manifests/
        logs/
        RELEASE_NOTES.md
```

The release identifier uses the `YYYY.MM.DD` format. The artifact pipeline must
never overwrite an existing release directory. If a release must be replaced,
the existing directory must be reviewed and removed explicitly outside the
pipeline.

This directory is not a publication endpoint. It is local release evidence that
can later feed signing, repository publication, mirror synchronization, and
GitHub release steps.

Local release evidence is generated state, not a public endpoint. Old local
ISOs in `out/iso/` are not release evidence. Production ISO evidence is created
by the approved production release pipeline after the current repository commit
has been pulled and mandatory validators have passed.
