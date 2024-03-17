FROM ubuntu:jammy
# Supported platforms https://github.com/actions/runner
# Release downloads https://github.com/actions/runner/releases
# Dockerfile contains code snippets inspired by resources found at: https://github.com/actions/actions-runner-controller/blob/master/runner/

ENV LC_ALL C
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ENV AGENT_TOOLSDIRECTORY=${RUNNER_TOOL_CACHE}

ARG CONTEXT_ROOT_PATH
ARG RUNNER_USER
ARG RUNNER_USER_UID=1000
ARG RUNNER_USER_GID=$RUNNER_USER_UID
ARG RUNNER_VERSION
ARG DOCKER_VERSION=24.0.7
ARG DOCKER_GROUP_GID=999

ARG DUMB_INIT_VERSION=1.2.5
ENV RUNNER_USER=${RUNNER_USER}
ENV RUNNER_HOME=/${RUNNER_USER}
ENV HOME=/home/${RUNNER_USER}
ENV TZ="UTC"
ENV RUNNER_VERSION=${RUNNER_VERSION}
ENV RUNNER_ASSETS_DIR=/runnertmp

RUN apt-get update -y \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
  curl \
  tzdata \
  jq \
  ca-certificates \
  apt-utils \
  apt-transport-https \
  software-properties-common \
  build-essential \
  wget \
  git \
  iptables \
  ssh \
  gnupg \
  zip \
  unzip \
  lsb-release \
  sudo \
  && apt-get autoremove -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download latest git-lfs version
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
  apt-get install -y --no-install-recommends git-lfs

RUN if [ "$(getent group ${DOCKER_GROUP_GID} | cut -d: -f3)" = "${DOCKER_GROUP_GID}" ] ; then \
  groupdel $(getent group ${DOCKER_GROUP_GID} | cut -d: -f1) ; \
  fi \
  && groupadd -g ${DOCKER_GROUP_GID} docker

RUN if [ "$(getent group ${RUNNER_USER_GID} | cut -d: -f3)" = "${RUNNER_USER_GID}" ] ; then \
  groupdel $(getent group ${RUNNER_USER_GID} | cut -d: -f1) ; \
  fi \
  && addgroup --system --gid ${RUNNER_USER_GID} ${RUNNER_USER}

RUN adduser --system --home ${HOME} --uid ${RUNNER_USER_GID} --gecos "" --gid ${RUNNER_USER_GID} --disabled-password ${RUNNER_USER} \
  && usermod -aG docker ${RUNNER_USER} \
  && usermod -aG sudo ${RUNNER_USER} \
  && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers    

RUN export ARCH=$(dpkg --print-architecture) \
  && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
  && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
  && curl -fLo /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
  && chmod +x /usr/bin/dumb-init

RUN export ARCH=$(dpkg --print-architecture) \
  && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi \
  && mkdir -p "$RUNNER_ASSETS_DIR" \
  && cd "$RUNNER_ASSETS_DIR" \
  && curl -fLo runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
  && tar xzf ./runner.tar.gz \
  && rm -f runner.tar.gz \
  && ./bin/installdependencies.sh \
  # libyaml-dev is required for ruby/setup-ruby action.
  # It is installed after installdependencies.sh and before removing /var/lib/apt/lists
  # to avoid rerunning apt-update on its own.
  && apt-get install -y libyaml-dev \
  && apt-get autoremove -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# https://github.com/actions/setup-python/issues/459#issuecomment-1182946401
RUN mkdir -p ${RUNNER_TOOL_CACHE} \
  && chown ${RUNNER_USER}:docker ${RUNNER_TOOL_CACHE} \
  && chmod g+rwx ${RUNNER_TOOL_CACHE}

RUN LSB_RELEASE=$(lsb_release -rs) \
  && wget -q https://packages.microsoft.com/config/ubuntu/$LSB_RELEASE/packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && rm packages-microsoft-prod.deb \
  && apt-get update -y \
  && apt-get upgrade -y \
  && apt-get install -y powershell \
  && apt-get autoremove -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*        

RUN curl -fsSLO https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  && unzip awscli-exe-linux-x86_64.zip \
  && ./aws/install -i /usr/local/aws -b /usr/local/bin \
  && rm awscli-exe-linux-x86_64.zip

# Add the repository to Apt sources:
RUN apt-get update -y \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  && apt-get autoremove -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/*  

RUN mkdir -p /etc/docker

COPY ${CONTEXT_ROOT_PATH}/daemon.json /etc/docker/daemon.json

COPY ${CONTEXT_ROOT_PATH}/entrypoint.sh ${CONTEXT_ROOT_PATH}/logger.sh ${CONTEXT_ROOT_PATH}/graceful-stop.sh ${CONTEXT_ROOT_PATH}/update-status /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh /usr/bin/logger.sh /usr/bin/graceful-stop.sh /usr/bin/update-status

COPY ${CONTEXT_ROOT_PATH}/docker-exec.sh /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker

# Configure hooks folder structure.
COPY ${CONTEXT_ROOT_PATH}/hooks /etc/actions-runner/hooks/
RUN mkdir -p ${RUNNER_HOME} \
  && chown -R ${RUNNER_USER}:docker ${RUNNER_HOME} $RUNNER_ASSETS_DIR ${HOME} \
  && chmod -R +x /etc/actions-runner/hooks

VOLUME /var/lib/docker

ENV PATH="${RUNNER_HOME}:/usr/local/bin:${HOME}/.local/bin:${PATH}"
ENV ImageOS=ubuntu-jammy

RUN echo "PATH=${PATH}" >> /etc/environment \
  && echo "ImageOS=${ImageOS}" >> /etc/environment

USER ${RUNNER_USER}

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["entrypoint.sh"]
