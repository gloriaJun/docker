FROM rockylinux/rockylinux:9.3 AS base

ARG RUNNER_VERSION="2.314.1"
ARG RUNNER_ZIP_FILE_NAME="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

ARG RUNNER_UID=1000
ARG DOCKER_GID=1001

ENV RUNNER_HOME=/home/runner

# Install packages
RUN dnf update -y && \
    dnf upgrade -y && \
    dnf install -y --allowerasing \
    'dnf-command(config-manager)' \
    dnf-utils \
    ca-certificates \
    git \
    glibc \
    sudo \
    curl \
    rsync \
    procps-ng \
    tar \
    gzip \
    unzip \
    wget \
    jq \
    vim && \
    dnf clean all

# Add runner user
RUN useradd -c "" --uid ${RUNNER_UID} runner && \
    passwd -l runner && \
    groupadd docker --gid $DOCKER_GID && \
    usermod -aG wheel runner && \
    usermod -aG docker runner

# Configure sudoers file
RUN echo "%wheel   ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers && \
    echo 'Defaults env_keep += "DEBIAN_FRONTEND"' | tee -a /etc/sudoers

# Download and install dumb-init
RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 && \
    chmod +x /usr/local/bin/dumb-init

# Switch to runner user
WORKDIR $RUNNER_HOME
USER runner

## Donwnload and install the GitHub Actions Runner
RUN mkdir -p actions-runner && \
    cd actions-runner && \
    curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ZIP_FILE_NAME} && \
    tar xzf ./${RUNNER_ZIP_FILE_NAME} && \
    rm -f ./${RUNNER_ZIP_FILE_NAME} && \
    sudo ./bin/installdependencies.sh

WORKDIR /home/runner/actions-runner

COPY entrypoint.sh logger.sh $RUNNER_HOME/actions-runner/
RUN sudo chown runner:runner entrypoint.sh && \
    sudo chmod +x entrypoint.sh




FROM base as linux-runner

ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "./entrypoint.sh"]



FROM base as linux-runner-dind

ARG DOCKER_VERSION=24.0.7
ARG DOCKER_COMPOSE_VERSION=v2.23.0

## Install Docker
RUN sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    sudo dnf install -y --allowerasing \
      device-mapper-persistent-data \
      lvm2 \
      dnf-plugins-core \
      epel-release \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-compose-plugin && \
    dnf clean all \

RUN docker --version && \
    docker compose version

ENV DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \
    DOCKER_HOST=tcp://127.0.0.1:2375

RUN sudo curl "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o /usr/local/bin/dind && \
    sudo chmod +x /usr/local/bin/dind

COPY daemon.json /etc/docker/daemon.json
COPY Dockerfile ../Dockerfile

VOLUME /var/lib/docker
EXPOSE 2375

# Run with Docker Daemon
#ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "./entrypoint.sh", "dind"]



#FROM base as nvm_image
#
#ARG NVM_VERSION="0.39.7"
#ARG NODE_VERSION="21.7.3"
#
#ENV NVM_DIR $RUNNER_HOME/.nvm
#
#RUN mkdir $NVM_DIR && \
#    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash
#RUN source $NVM_DIR/nvm.sh && \
#    nvm install $NODE_VERSION && \
#    nvm alias default $NODE_VERSION && \
#    nvm use default
#
## add node and npm to path so the commands are available
#ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
#ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH