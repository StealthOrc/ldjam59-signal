param(
    [string]$LoveRoot = "C:\Program Files\LOVE",
    [string]$ProjectName = "out-of-signal",
    [string]$Version = "0.1.0",
    [string]$OutputRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$envFileName = ".env"
$buildEnvFileName = "build.env"
$nativeHttpsModuleRelativePath = "third_party\native\windows\x64\https.dll"
$envKeys = @(
    "API_KEY",
    "API_BASE_URL",
    "HMAC_SECRET"
)

$projectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($projectRoot)) {
    $projectRoot = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot "dist"
}

$buildName = "{0}_{1}" -f $ProjectName, ($Version -replace "\.", "_")
$buildDir = Join-Path $OutputRoot $buildName
$stageDir = Join-Path $buildDir "_stage"
$loveFile = Join-Path $buildDir ($buildName + ".love")
$exeFile = Join-Path $buildDir ($buildName + ".exe")
$zipFile = Join-Path $OutputRoot ($buildName + "_windows.zip")
$loveExe = Join-Path $LoveRoot "love.exe"
$projectEnvFile = Join-Path $projectRoot $envFileName
$nativeHttpsModulePath = Join-Path $projectRoot $nativeHttpsModuleRelativePath

if (-not (Test-Path -LiteralPath $loveExe)) {
    throw "LOVE executable not found at '$loveExe'."
}

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
    "dist"
)

$excludedFileNames = @(
    ".gitignore",
    "AGENTS.md",
    "build.ps1"
)

$excludedExtensions = @(
    ".love",
    ".zip"
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

function Join-BinaryFiles {
    param(
        [string[]]$InputPaths,
        [string]$OutputPath
    )

    $outputStream = [System.IO.File]::Create($OutputPath)
    try {
        foreach ($inputPath in $InputPaths) {
            $inputStream = [System.IO.File]::OpenRead($inputPath)
            try {
                $inputStream.CopyTo($outputStream)
            }
            finally {
                $inputStream.Dispose()
            }
        }
    }
    finally {
        $outputStream.Dispose()
    }
}

function Create-ZipFromDirectory {
    param(
        [string]$SourceDirectory,
        [string]$DestinationZip,
        [string[]]$ExcludedFileNames = @()
    )

    $archive = [System.IO.Compression.ZipFile]::Open($DestinationZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File) {
            if ($ExcludedFileNames -contains $file.Name) {
                continue
            }

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

function Get-BuildEnvContent {
    param(
        [string]$ProjectEnvFilePath
    )

    if (Test-Path -LiteralPath $ProjectEnvFilePath) {
        return Get-Content -LiteralPath $ProjectEnvFilePath -Raw
    }

    $envLines = New-Object System.Collections.Generic.List[string]

    foreach ($envKey in $envKeys) {
        $envValue = [Environment]::GetEnvironmentVariable($envKey)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            [void]$envLines.Add(($envKey + "=" + $envValue))
        }
    }

    if ($envLines.Count -eq 0) {
        throw "No build environment source was found. Create '$envFileName' in the project root or set one of these process environment variables: $($envKeys -join ', ')."
    }

    return ($envLines -join [Environment]::NewLine) + [Environment]::NewLine
}

if (Test-Path -LiteralPath $buildDir) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
}

if (Test-Path -LiteralPath $zipFile) {
    Remove-Item -LiteralPath $zipFile -Force
}

New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

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

$buildEnvContent = Get-BuildEnvContent -ProjectEnvFilePath $projectEnvFile
$stageEnvFile = Join-Path $stageDir $buildEnvFileName
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($stageEnvFile, $buildEnvContent, $utf8WithoutBom)

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

Join-BinaryFiles -InputPaths @($loveExe, $loveFile) -OutputPath $exeFile

$runtimeFiles = Get-ChildItem -LiteralPath $LoveRoot -File | Where-Object {
    $_.Extension -ieq ".dll" -or $_.Name -in @("license.txt", "game.ico")
}

foreach ($runtimeFile in $runtimeFiles) {
    Copy-Item -LiteralPath $runtimeFile.FullName -Destination (Join-Path $buildDir $runtimeFile.Name) -Force
}

if (Test-Path -LiteralPath $nativeHttpsModulePath) {
    Copy-Item -LiteralPath $nativeHttpsModulePath -Destination (Join-Path $buildDir "https.dll") -Force
}

Remove-Item -LiteralPath $stageDir -Recurse -Force

Create-ZipFromDirectory -SourceDirectory $buildDir -DestinationZip $zipFile -ExcludedFileNames @($buildName + ".love")

Remove-Item -LiteralPath $buildDir -Recurse -Force

Write-Host "Built distributable zip: $zipFile"
