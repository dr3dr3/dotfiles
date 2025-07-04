ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Install basic utilities
RUN apk add --no-cache shadow zsh starship nano fzf eza bat zoxide nerd-fonts gum yq git
RUN git config --global user.name "Andre Dreyer" && git config --global user.email "git@andredreyer.com"

# Install and setup Starship for ZSH
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y
RUN mkdir -p $HOME/.zsh
RUN wget -O $HOME/.zsh/.zshenv https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/zshenv
RUN wget -O $HOME/.zsh/.zshrc https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/zshrc
RUN wget -O $HOME/.zsh/starship.toml https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/.config/starship.toml
ENV STARSHIP_CONFIG=$HOME/.zsh/starship.toml
ENV STARSHIP_CACHE=$HOME/.zsh/starship/cache
ENV ZDOTDIR=$HOME/.zsh
RUN chsh -s $(which zsh)

ENTRYPOINT ["/bin/zsh"]
