starship init fish | source

# Disable new user greeting.
set -U fish_greeting

# Set default text editor
set -gx EDITOR vim

# date/time
abbr -a -- ds 'date +%Y-%m-%d'
abbr -a -- ts 'date +%Y-%m-%dT%H:%M:%SZ'
abbr -a -- yyyymmdd 'date +%Y%m%d'

# git
abbr -a -- ga 'git add . '
abbr -a -- gc 'git commit -am '
abbr -a -- gco 'git checkout'
abbr -a -- gcob 'git checkout -b '
abbr -a -- gcod 'git checkout develop'
abbr -a -- gcom 'git checkout master'
abbr -a -- glog git\ log\ --Uraph\ --pretty=\'\%Cred\%h\%Creset\ -\%C\(auto\)\%d\%Creset\ \%s\ \%Cgreen\(\%ad\)\ \%C\(bold\ blue\)\<\%an\>\%Creset\'\ --date=short
abbr -a -- gpll 'git pull'
abbr -a -- gp 'git push'
abbr -a -- gclone 'git clone git@github.com:dr3dr3/'
abbr -a -- gwhoami 'echo "user.name:" (git config user.name) && echo "user.email:" (git config user.email)'

# kubernetes
# https://github.com/ahmetb/kubectl-aliases/blob/master/.kubectl_aliases
abbr -a -- k 'kubectl'
abbr -a -- kn 'kubectl config set-context --current --namespace'
abbr -a -- kge 'kubectl get events --sort-by=.lastTimestamp'
abbr -a -- kdesc 'kubectl describe'
abbr -a -- kgn 'kubectl get nodes'
abbr -a -- kgp 'kubectl get pods'
abbr -a -- kgpa 'kubectl get pods -- all-namespaces'
abbr -a -- kgs 'kubectl get services'
abbr -a -- kgd 'kubectl get deployments'

# talos
abbr -a -- t 'talosctl'
abbr -a -- tgc 'talosctl gen config'
abbr -a -- ta 'talosctl apply-config -n $TALOSIP -e $TALOSIP --talosconfig=$TALOSCONF'
abbr -a -- tl 'talosctl logs -f'
abbr -a -- tm 'talosctl dmesg -f -e $TALOSIP -n $TALOSIP'