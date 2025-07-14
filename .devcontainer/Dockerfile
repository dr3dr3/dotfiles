ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

RUN apk add --no-cache fish starship stow git
RUN git config --global user.name "Andre Dreyer" && git config --global user.email "git@andredreyer.com"

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
