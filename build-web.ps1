param(
    [string]$ProjectName = "out-of-signal",
    [string]$Version = "0.1.0",
    [string]$OutputRoot = "",
    [string]$LoveJsRef = "main",
    [switch]$ForceDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($projectRoot)) {
    $projectRoot = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot "dist"
}

$buildName = "{0}_html5_{1}" -f $ProjectName, ($Version -replace "\.", "_")
$buildDir = Join-Path $OutputRoot $buildName
$stageDir = Join-Path $buildDir "_stage"
$playerCacheDir = Join-Path $OutputRoot "_lovejs_cache"
$loveFileName = "$ProjectName.love"
$loveFile = Join-Path $buildDir $loveFileName
$zipFile = Join-Path $OutputRoot ($buildName + ".zip")
$userAgent = "Codex-WebBuild"

$includeRoots = @(
    "main.lua",
    "conf.lua",
    "src",
    "assets"
)

$excludedDirectoryNames = @(
    ".git",
    ".codex",
    ".vscode",
    "dist",
    "docs"
)

$excludedFileNames = @(
    ".gitignore",
    "AGENTS.md",
    "build.ps1",
    "build-web.ps1"
)

$excludedExtensions = @(
    ".love",
    ".zip"
)

$loveJsAssets = @(
    @{ RelativePath = "player.js"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/player.js" },
    @{ RelativePath = "style.css"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/style.css" },
    @{ RelativePath = ".htaccess"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/.htaccess" },
    @{ RelativePath = "nogame.love"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/nogame.love" },
    @{ RelativePath = "11.5/love.js"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/11.5/love.js" },
    @{ RelativePath = "11.5/love.wasm"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/11.5/love.wasm" },
    @{ RelativePath = "11.5/license.txt"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/11.5/license.txt" },
    @{ RelativePath = "lua/normalize1.lua"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/lua/normalize1.lua" },
    @{ RelativePath = "lua/normalize2.lua"; Url = "https://raw.githubusercontent.com/2dengine/love.js/$LoveJsRef/lua/normalize2.lua" }
)

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseUri = [Uri]((Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\')
    $fullUri = [Uri](Resolve-Path -LiteralPath $FullPath).Path
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString()).Replace('/', '\')
}

function Should-IncludeFile {
    param(
        [string]$ProjectRootPath,
        [System.IO.FileInfo]$FileInfo
    )

    $relativePath = Get-RelativePath -BasePath $ProjectRootPath -FullPath $FileInfo.FullName
    $segments = $relativePath -split '[\\/]'

    foreach ($segment in $segments) {
        if ($excludedDirectoryNames -contains $segment) {
            return $false
        }
    }

    if ($excludedFileNames -contains $FileInfo.Name) {
        return $false
    }

    if ($excludedExtensions -contains $FileInfo.Extension.ToLowerInvariant()) {
        return $false
    }

    return $true
}

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8WithoutBom)
}

function Create-ZipFromDirectory {
    param(
        [string]$SourceDirectory,
        [string]$DestinationZip
    )

    $archive = [System.IO.Compression.ZipFile]::Open($DestinationZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File) {
            $entryName = (Get-RelativePath -BasePath $SourceDirectory -FullPath $file.FullName).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $file.FullName,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Invoke-DownloadFile {
    param(
        [string]$Url,
        [string]$DestinationPath
    )

    $destinationDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    Invoke-WebRequest -Headers @{ "User-Agent" = $userAgent } -Uri $Url -OutFile $DestinationPath
}

function Ensure-LoveJsAssets {
    param(
        [string]$CacheDirectory,
        [string]$DestinationDirectory
    )

    foreach ($asset in $loveJsAssets) {
        $cachePath = Join-Path $CacheDirectory $asset.RelativePath
        if ($ForceDownload -or -not (Test-Path -LiteralPath $cachePath)) {
            Invoke-DownloadFile -Url $asset.Url -DestinationPath $cachePath
        }

        $destinationPath = Join-Path $DestinationDirectory $asset.RelativePath
        $destinationParent = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationParent)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }

        Copy-Item -LiteralPath $cachePath -Destination $destinationPath -Force
    }
}

function Get-WebIndexHtml {
    param(
        [string]$GameTitle,
        [string]$PackageUri
    )

    return @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>$GameTitle</title>
    <link rel="stylesheet" href="style.css">
  </head>
  <body>
    <canvas id="canvas"></canvas>
    <div id="spinner" class="pending"></div>
    <noscript>This HTML5 build needs JavaScript enabled in the browser.</noscript>
    <script src="player.js?g=$PackageUri&v=11.5"></script>
  </body>
</html>
"@
}

function Get-WebReadme {
    param(
        [string]$BuildName,
        [string]$PackageFileName
    )

    return @"
$BuildName

Contents:
- index.html: launch page for the HTML5 build
- ${PackageFileName}: packaged LOVE game data
- player.js, style.css, 11.5/*, lua/*: love.js runtime files

Upload notes:
- itch.io: upload the ZIP generated by build-web.ps1 as an HTML5 project.
- itch.io: if the page offers a SharedArrayBuffer / cross-origin isolation option, enable it for this build.
- Other hosts: serve this folder over HTTP/HTTPS and set:
  - Cross-Origin-Opener-Policy: same-origin
  - Cross-Origin-Embedder-Policy: require-corp
- Do not open index.html directly from disk. love.js must be served by a web server.

This HTML5 build is intentionally offline-first:
- local saves and personal bests work in browser storage
- desktop-only online features are disabled in the web build
"@
}

if (Test-Path -LiteralPath $buildDir) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
}

if (Test-Path -LiteralPath $zipFile) {
    Remove-Item -LiteralPath $zipFile -Force
}

New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
New-Item -ItemType Directory -Path $playerCacheDir -Force | Out-Null

$filesToStage = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($entry in $includeRoots) {
    $sourcePath = Join-Path $projectRoot $entry
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        continue
    }

    $item = Get-Item -LiteralPath $sourcePath
    if ($item.PSIsContainer) {
        foreach ($file in Get-ChildItem -LiteralPath $sourcePath -Recurse -File) {
            if (Should-IncludeFile -ProjectRootPath $projectRoot -FileInfo $file) {
                [void]$filesToStage.Add($file)
            }
        }
    }
    else {
        if (Should-IncludeFile -ProjectRootPath $projectRoot -FileInfo $item) {
            [void]$filesToStage.Add($item)
        }
    }
}

foreach ($file in $filesToStage) {
    $relativePath = Get-RelativePath -BasePath $projectRoot -FullPath $file.FullName
    $targetPath = Join-Path $stageDir $relativePath
    $targetDir = Split-Path -Parent $targetPath

    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force
}

$zipArchive = [System.IO.Compression.ZipFile]::Open($loveFile, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $stageDir -Recurse -File) {
        $entryName = (Get-RelativePath -BasePath $stageDir -FullPath $file.FullName).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zipArchive,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $zipArchive.Dispose()
}

Ensure-LoveJsAssets -CacheDirectory $playerCacheDir -DestinationDirectory $buildDir

$gameTitle = ($ProjectName -replace "[-_]+", " ")
$gameTitle = (Get-Culture).TextInfo.ToTitleCase($gameTitle)
$packageCacheKey = Get-Date -Format "yyyyMMddHHmmss"
$packageUri = [Uri]::EscapeDataString("${loveFileName}?cb=$packageCacheKey")
Write-Utf8NoBomFile -Path (Join-Path $buildDir "index.html") -Content (Get-WebIndexHtml -GameTitle $gameTitle -PackageUri $packageUri)
Write-Utf8NoBomFile -Path (Join-Path $buildDir "README.txt") -Content (Get-WebReadme -BuildName $buildName -PackageFileName $loveFileName)

Remove-Item -LiteralPath $stageDir -Recurse -Force

Create-ZipFromDirectory -SourceDirectory $buildDir -DestinationZip $zipFile

Write-Host "Built HTML5 directory: $buildDir"
Write-Host "Built HTML5 zip: $zipFile"
