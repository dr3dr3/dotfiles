ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Install basic utilities
RUN apk add --no-cache fish gum yq git
RUN git config --global user.name "Andre Dreyer" && git config --global user.email "git@andredreyer.com"

# Install Starship and setup ZSH
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y
RUN mkdir -p ~/.config/fish
RUN mkdir -p ~/.config/fish && wget -O ~/.config/fish/config.fish https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/fish/config.fish
RUN mkdir -p ~/.config/fish/conf.d && wget -O ~/.config/fish/conf.d/abbrs.fish https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/fish/abbrs.fish
RUN mkdir -p ~/.config/starship && wget -O ~/.config/fish/starship.toml https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/.config/starship.toml
RUN mkdir -p ~/.config/starship/cache
ENV STARSHIP_CONFIG=~/.config/starship/starship.toml
ENV STARSHIP_CACHE=~/.config/starship/cache
ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
