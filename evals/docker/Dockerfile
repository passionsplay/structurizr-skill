# Trial environment for evals: a plain Linux box with an agent CLI, bash, jq, curl, and a
# Docker client. No Java, no Structurizr install, no repo, no home directory from the host.
# The Docker client talks to the host daemon through a mounted socket (see agents/pi-docker.sh).

FROM docker:29-cli AS docker-cli

FROM node:22-slim

ARG PI_VERSION=1.1.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl jq \
 && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

RUN npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}" \
 && npm cache clean --force

ENTRYPOINT ["pi"]
