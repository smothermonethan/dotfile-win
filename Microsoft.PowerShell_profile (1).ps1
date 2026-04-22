New-Alias k kubectl
Remove-Alias h
New-Alias h helm
New-Alias g goto

function goto {
    param (
        $location
    )

    Switch ($location) {
        "pr" {
            Set-Location -Path "$HOME/projects"
        }
        "bp" {
            Set-Location -Path "$HOME/projects/boilerplates"
        }
        "cs" {
            Set-Location -Path "$HOME/projects/cheat-sheets"
        }
        default {
            echo "Invalid location"
        }
    }
}

function kn {
    param (
        $namespace
    )

    if ($namespace -in "default","d") {
        kubectl config set-context --current --namespace=default
    } else {
        kubectl config set-context --current --namespace=$namespace
    }
}

$ENV:STARSHIP_CONFIG = "C:\Users\ethan\Downloads"
$ENV:STARSHIP_DISTRO = "者  $env:username"
Invoke-Expression (&starship init powershell)
