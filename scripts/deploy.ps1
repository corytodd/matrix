Get-Content (Join-Path $PSScriptRoot "../.env") | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
    }
}

$Remote = "$($env:USER)@$($env:HOST)"
$Dest = $env:DEST
$Sha = git rev-parse HEAD

ssh $Remote "mkdir -p $Dest/caddy $Dest/tuwunel"
scp docker-compose.yml "${Remote}:${Dest}/docker-compose.yml"
scp caddy/Caddyfile "${Remote}:${Dest}/caddy/Caddyfile"
scp tuwunel/tuwunel.toml "${Remote}:${Dest}/tuwunel/tuwunel.toml"

ssh $Remote "cd $Dest && GIT_SHA=$Sha docker compose up -d --pull always --remove-orphans"
