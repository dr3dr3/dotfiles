ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Install basic utilities
RUN apk add --no-cache fish gum yq git
RUN git config --global user.name "Andre Dreyer" && git config --global user.email "git@andredreyer.com"

# Install Starship and setup ZSH
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y
RUN wget -O ~/.config/fish/config.fish https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/fish/config.fish
RUN wget -O ~/.config/fish/conf.d/abbrs.fish https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/fish/abbrs.fish
RUN wget -O ~/.config/fish/starship.toml https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/.config/starship.toml
ENV STARSHIP_CONFIG=~/.config/fish/starship.toml
RUN mkdir -p ~/.config/fish/starship/cache
ENV STARSHIP_CACHE=~/.config/fish/starship/cache
ENV FISH_CONFIG=~/.config/fish/config.fish
ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
