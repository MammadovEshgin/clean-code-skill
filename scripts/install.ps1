<#
.SYNOPSIS
  Install the clean-code skills into agent skill directories (Windows PowerShell 5.1+).

.EXAMPLE
  .\scripts\install.ps1                 project install: .\.claude\skills (run from the target repo)
  .\scripts\install.ps1 -Global         personal install: ~\.claude\skills (every project)
  .\scripts\install.ps1 -Codex          also install into .agents\skills
  .\scripts\install.ps1 -Cursor         also install into .cursor\skills
#>
param(
  [switch]$Global,
  [switch]$Codex,
  [switch]$Cursor
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

if ($Global) { $root = $HOME } else { $root = (Get-Location).Path }

$dests = @((Join-Path $root ".claude\skills"))
if ($Codex)  { $dests += (Join-Path $root ".agents\skills") }
if ($Cursor) { $dests += (Join-Path $root ".cursor\skills") }

foreach ($dest in $dests) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Get-ChildItem -Directory (Join-Path $repo "skills") | ForEach-Object {
    $target = Join-Path $dest $_.Name
    if (Test-Path $target) { Remove-Item -Recurse -Force $target }
    Copy-Item -Recurse -Path $_.FullName -Destination $target
    Write-Host "installed $($_.Name) -> $target"
  }
}

Write-Host ""
Write-Host "Done. In your agent:"
Write-Host "  /clean-code-setup        once per repo: lint gates, check command, CODING_STANDARDS.md"
Write-Host "  /finish                  before every commit: interrogate, deslop, gates, fresh-context review, findings applied"
Write-Host "  /deslop <path|repo>      clean existing code, behaviour-preserving; repo = the whole codebase, one commit per slice"
Write-Host "  /interrogate             challenge a finished change on its own"
Write-Host "  /clean-code-review main  fresh-context review of the diff since main, on its own"
Write-Host "The clean-code skill itself loads automatically whenever code is written or changed."
Write-Host "Scripts inside the skills (diff-stats.sh, complexity.sh, format-on-edit.sh) run under Git Bash."
