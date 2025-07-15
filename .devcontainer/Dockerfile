ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

RUN apk add --no-cache fish starship stow git gum

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
