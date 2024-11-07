FROM mcr.microsoft.com/powershell:latest

RUN pwsh -Command "Install-Module -Name PSScriptAnalyzer -Force -Scope AllUsers -AllowClobber"

COPY analyze.ps1 /analyze.ps1
COPY profile.ps1 /root/.config/powershell/Microsoft.PowerShell_profile.ps1
COPY profile.ps1 /.config/powershell/Microsoft.PowerShell_profile.ps1

ENTRYPOINT [ "pwsh", "-Command" ]
