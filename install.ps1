param (
    [switch]$Global,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Styles and colors
function Write-Header ($text) {
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Header "Engineering Standards Automated Installer"

if ($Global) {
    $TargetDir = Join-Path $HOME ".engineering-standards"
    Write-Host "Mode: Global" -ForegroundColor White -FontWeight Bold
} else {
    $TargetDir = Get-Location
    Write-Host "Mode: Local (Project)" -ForegroundColor White -FontWeight Bold
}

Write-Host "Target directory: $TargetDir" -ForegroundColor Blue
Write-Host ""

# Ensure target directory exists
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# Create temp path
$TempDir = Join-Path [System.IO.Path]::GetTempPath() "eng-std-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    Write-Host "Downloading latest standards from GitHub..." -ForegroundColor Gray
    $ZipUrl = "https://github.com/S13G/engineering-standards-plugin/archive/refs/heads/main.zip"
    $ZipPath = Join-Path $TempDir "standards.zip"

    # Use native HttpClient or Invoke-WebRequest
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing

    Write-Host "Extracting archive..." -ForegroundColor Gray
    $ExtractDir = Join-Path $TempDir "extracted"
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force

    # Find the nested repository folder in zip extraction
    $RepoFolder = Get-ChildItem -Path $ExtractDir -Directory | Where-Object { $_.Name -like "*engineering-standards-plugin*" } | Select-Object -First 1

    if ($null -eq $RepoFolder) {
        throw "Failed to locate extracted standards folder."
    }

    $Items = "AGENTS.md", "CLAUDE.md", "GEMINI.md", ".cursorrules", "skills", ".cursor", ".github"

    foreach ($Item in $Items) {
        $Src = Join-Path $RepoFolder.FullName $Item
        $Dest = Join-Path $TargetDir $Item

        if (Test-Path $Src) {
            if ((Test-Path $Dest) -and -not $Force) {
                Write-Host "⚠ Skipped (already exists): $Item" -ForegroundColor Yellow
                continue
            }
            
            if (Test-Path $Dest) {
                Remove-Item -Path $Dest -Recurse -Force | Out-Null
            }

            Copy-Item -Path $Src -Destination $Dest -Recurse -Force | Out-Null
            Write-Host "✔ Installed: $Item" -ForegroundColor Green
        } else {
            Write-Host "⚠ Warning: Source item $Item not found." -ForegroundColor Red
        }
    }

    # If global setup, configure AI agent profiles
    if ($Global) {
        Write-Host ""
        Write-Host "Setting up global AI agent references..." -ForegroundColor White

        # 1. Claude Code
        $ClaudeDir = Join-Path $HOME ".claude"
        $ClaudeFile = Join-Path $ClaudeDir "CLAUDE.md"

        if (-not (Test-Path $ClaudeDir)) {
            New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        }

        $ShouldWriteClaude = $true
        if (Test-Path $ClaudeFile) {
            $Content = Get-Content -Path $ClaudeFile -Raw
            if ($Content -like "*engineering-standards*") {
                Write-Host "⚠ Global Claude Code rules already contain a reference to engineering-standards." -ForegroundColor Yellow
                $ShouldWriteClaude = $false
            }
        }

        if ($ShouldWriteClaude) {
            $ReferenceText = "`r`n# Engineering Standards`r`n`r`nThis workspace uses the global engineering standards plugin.`r`nTo load domain references, refer to rules inside \`$TargetDir\`.`r`n`r`n@$($TargetDir.Replace('\','/'))/AGENTS.md`r`n"
            Add-Content -Path $ClaudeFile -Value $ReferenceText
            Write-Host "✔ Added reference to global CLAUDE.md at: $ClaudeFile" -ForegroundColor Green
        }

        # 2. Gemini CLI
        $GeminiDir = Join-Path $HOME ".gemini"
        $GeminiFile = Join-Path $GeminiDir "GEMINI.md"

        if (-not (Test-Path $GeminiDir)) {
            New-Item -ItemType Directory -Path $GeminiDir -Force | Out-Null
        }

        $ShouldWriteGemini = $true
        if (Test-Path $GeminiFile) {
            $Content = Get-Content -Path $GeminiFile -Raw
            if ($Content -like "*engineering-standards*") {
                Write-Host "⚠ Global Gemini CLI rules already contain a reference to engineering-standards." -ForegroundColor Yellow
                $ShouldWriteGemini = $false
            }
        }

        if ($ShouldWriteGemini) {
            $ReferenceText = "`r`n# Engineering Standards`r`n`r`nThis workspace uses the global engineering standards plugin.`r`nTo load domain references, refer to rules inside \`$TargetDir\`.`r`n`r`n@$($TargetDir.Replace('\','/'))/AGENTS.md`r`n"
            Add-Content -Path $GeminiFile -Value $ReferenceText
            Write-Host "✔ Added reference to global GEMINI.md at: $GeminiFile" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "★ Installation completed successfully!" -ForegroundColor Green
    if ($Global) {
        Write-Host "Standards are now globally installed. Your AI agents have been configured to use them." -ForegroundColor Green
    } else {
        Write-Host "Standards are now local to this project and will be read automatically by your AI agents." -ForegroundColor Green
    }
    Write-Host ""

} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temp dir
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force | Out-Null
    }
}
