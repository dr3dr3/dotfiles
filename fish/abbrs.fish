#
# abbrs
#

set -q MY_ABBRS_INITIALIZED; and return

# date/time
abbr -a -- ds 'date +%Y-%m-%d'
abbr -a -- ts 'date +%Y-%m-%dT%H:%M:%SZ'
abbr -a -- yyyymmdd 'date +%Y%m%d'

# git
# abbr -a -- gad 'git add'
# abbr -a -- gbn 'git rev-parse --abbrev-ref HEAD'
# abbr -a -- gcl 'git clean'
# abbr -a -- gcmt 'git commit -am '
# abbr -a -- gco 'git checkout'
# abbr -a -- gcob 'git checkout -b '
# abbr -a -- gcod 'git checkout develop'
# abbr -a -- gcom 'git checkout master'
# abbr -a -- get git
# abbr -a -- glg 'git log'
# abbr -a -- glog git\ log\ --Uraph\ --pretty=\'\%Cred\%h\%Creset\ -\%C\(auto\)\%d\%Creset\ \%s\ \%Cgreen\(\%ad\)\ \%C\(bold\ blue\)\<\%an\>\%Creset\'\ --date=short
# abbr -a -- gpll 'git pull'
# abbr -a -- gpristine 'git reset --hard && git clean -fdx'
# abbr -a -- gpsh 'git push'
# abbr -a -- gpsuo 'git push --set-Upstream origin (git rev-parse --abbrev-ref HEAD)'
# abbr -a -- grm 'git rm'
# abbr -a -- grv 'git remote -v'
# abbr -a -- gsh 'git stash'
# abbr -a -- gst 'git status -sb'
abbr -a -- gclone 'git clone git@github.com:dr3dr3/'
abbr -a -- gwhoami 'echo "user.name:" (git config user.name) && echo "user.email:" (git config user.email)'

# no need to run over-and-over
set -g MY_ABBRS_INITIALIZED true