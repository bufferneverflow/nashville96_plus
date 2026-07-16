function git-protocol -d "Switch global git protocol between https and ssh"
    set -l mode $argv[1]
    set -l host github.com
    if set -q argv[2]
        set host $argv[2]
    end

    switch "$mode"
        case ssh
            git config --global --remove-section url."https://$host/" 2>/dev/null
            git config --global url."git@$host:".insteadOf "https://$host/"
            echo "git protocol: ssh  (https://$host/ -> git@$host:)"
        case https
            git config --global --remove-section url."git@$host:" 2>/dev/null
            git config --global url."https://$host/".insteadOf "git@$host:"
            echo "git protocol: https  (git@$host: -> https://$host/)"
        case '' status
            if git config --global --get url."git@$host:".insteadOf >/dev/null 2>&1
                echo "git protocol: ssh ($host)"
            else if git config --global --get url."https://$host/".insteadOf >/dev/null 2>&1
                echo "git protocol: https ($host)"
            else
                echo "git protocol: default — no URL rewrite configured for $host"
            end
        case '*'
            echo "usage: git-protocol [ssh|https|status] [host]" >&2
            echo "       host defaults to github.com" >&2
            return 1
    end
end
