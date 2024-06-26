# Docker Image for GitHub Actions Runner

## Usage

### Prerequisites

Create `.env` file with the following content:

```bash
GITHUB_PERSONAL_TOKEN=<token>
GITHUB_REPO_OWNER=<owner>
GITHUB_REPO_NAME=<repository-name>
RUNNER_LABELS=<labels>
```

### default image

```bash
# build
docker build . -f actions-runner.rockylinux.dockerfile --target linux-runner --platform linux/x86_64 --tag rocky-action-runner --progress=plain

# run
docker run -it --rm \
  --name ghe-linux-runner \
  --env-file=.env \
  --platform linux/x86_64 \
  rocky-action-runner
```

### DIND image

```bash
# build
docker build . -f actions-runner.rockylinux.dockerfile --target linux-runner-dind --platform linux/x86_64 --tag rocky-action-runner-dind --progress=plain

# run
docker run -it --rm --privileged \
  --name ghe-linux-runner-dind \
  --env-file=.env \
  --platform linux/x86_64 \
  rocky-action-runner-dind
#  -v /var/run/docker.sock:/var/run/docker.sock \
```

