ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Install basic utilities
RUN apk add --no-cache shadow zsh starship nano fzf eza bat nerd-fonts gum yq git
RUN git config --global user.name "Andre Dreyer" && git config --global user.email "git@andredreyer.com"

# Install and setup Starship for ZSH
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y
RUN chsh -s $(which zsh)

ENTRYPOINT ["/bin/zsh"]
