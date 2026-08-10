# GitHub Actions Workflows

The [ci.yaml](ci.yaml) workflow runs on all Pull Requests and pushes to the main branch.
It builds Docker images and runs tests.

The [release-start.yaml](release-start.yaml) and [release-publish.yaml](release-publish.yaml)
workflows handle the release process.

The [test.yaml](test.yaml) workflow runs the tests inside the production Docker image.
