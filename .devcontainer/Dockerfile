ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Dependencies for my dotfiles and work setup
RUN apk add --no-cache nushell fish starship stow git gum font-fira-code-nerd

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]

