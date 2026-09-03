# =============================================================================
# env.nu — runs BEFORE config.nu on every nushell start.
#
# Intentionally minimal. Starship init used to live here, writing
# ~/.cache/starship/init.nu (starship's documented nushell pattern), but nothing
# ever sourced it — the matching `use ~/.cache/starship/init.nu` was never added
# to config.nu, so it was dead work generating a file no one read.
#
# Starship is set up in config.nu instead, via $nu.data-dir/vendor/autoload/ —
# the same mechanism zoxide and mise use there. Do NOT re-add starship here:
#
#   * one mechanism, not two competing ones;
#   * autoload degrades safely — a missing file is a silent no-op, whereas
#     `use <path>` is resolved at PARSE time and cannot be wrapped in an `if`,
#     so an absent init.nu (starship not installed) breaks all of config.nu;
#   * the trade-off is a one-startup lag on a brand-new machine: the file
#     written during config.nu is picked up on the NEXT launch. Self-healing.
#
# This file is still the right home for anything that must be set before
# config.nu is parsed. Plain env vars belong in config.nu with the others.
# =============================================================================
