# Running tests

The local dev environment does not have Python installed (no system `python`/`pip`).
Tests must be run the same way CI runs them: inside Docker, using the same images
and `--shm-size` the GitHub Actions workflow uses (`.github/workflows/test.yaml`).

## Build the images once

```
docker build -t indy-plenum-base:local -f Dockerfile.base .
docker build --build-arg BASE_IMAGE=indy-plenum-base:local -t indy-plenum-test:local .
```

Rebuild `indy-plenum-test:local` after any code change (it does a fresh `COPY . .`
+ `pip3 install .[tests]`); `indy-plenum-base:local` only needs rebuilding if
`Dockerfile.base` itself changes (it's slow — builds rocksdb/ursa/libindy from source).

## Run tests

For a single test file/dir where you don't care about cross-module config state,
plain pytest is fine:

```
docker run --rm --shm-size=256m indy-plenum-test:local -m pytest -l -vv <path>
```

e.g. `storage/` for the storage/RocksDB layer.

For anything spanning multiple test modules (e.g. `plenum` as a whole), you MUST
use `runner.py`, the same wrapper CI uses — do NOT invoke `pytest` directly on a
whole package:

```
docker run --rm --shm-size=256m indy-plenum-test:local runner.py \
  --pytest "python3 -m pytest -l -vv" --dir plenum --output test-result-plenum.txt \
  --test-only-slice "1/8"   # CI splits plenum into 8 slices; see test.yaml
```

Why: `plenum.config`'s `getConfig()` caches a process-global `CONFIG` singleton on
first use. `runner.py` runs each top-level test module in its own `os.system()`
subprocess, so each module gets a correctly-initialized config. Running raw
`pytest plenum` in one process means only the first module that touches `tconf`
builds a valid config (merging in `GENESIS_DIR` etc. from the copied
`ubuntu_platform_config.py`); every module after it silently reuses that same
cached config object, and if the first module's setup didn't trigger it, you get
widespread `AttributeError: module 'plenum.config' has no attribute 'GENESIS_DIR'`
errors that look like a regression but are just a test-process artifact.

Do not attempt to run pytest on the host — required native deps (python-rocksdb,
libindy, libursa, pyzmq built against bundled zmq) are only present in the image.
