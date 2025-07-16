$env.config.buffer_editor = "vim"
mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
$env.config.show_banner = false

# Aliases
alias k = kubectl