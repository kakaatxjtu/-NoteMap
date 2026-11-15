# NoteMap build script
# cjpm breaks on non-ASCII paths ("Invalid utf8 byte sequence"), so we call cjc directly.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root 'src'
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null

$files = Get-ChildItem $src -Recurse -Filter *.cj | ForEach-Object { $_.FullName }
if ($files.Count -eq 0) { throw "no source files in $src" }

Write-Host ("compiling {0} files ..." -f $files.Count)
& cjc @files -o (Join-Path $build 'notemap.exe')
if ($LASTEXITCODE -ne 0) { throw "build failed" }
Write-Host ("build ok -> {0}" -f (Join-Path $build 'notemap.exe'))