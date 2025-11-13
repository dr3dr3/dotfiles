ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Dependencies for my dotfiles and work setup
RUN apk add --no-cache nushell fish starship stow git github-cli gum font-fira-code-nerd

# Install git and configure user
RUN git config --global user.name "André Dreyer" && git config --global user.email "github@andredreyer.com"

# Set fish as default shell
ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
