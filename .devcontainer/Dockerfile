ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

RUN apk add --no-cache nushell fish starship stow git gum font-fira-code-nerd

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
