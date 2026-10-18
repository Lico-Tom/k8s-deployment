# 卸载 release（PowerShell 版）
# 用法: .\scripts\uninstall.ps1 -Env dev

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Env,

    [string]$Namespace,
    [string]$Release = 'api',
    [string]$Helm = 'helm'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Namespace)) { $Namespace = $Env }

Write-Host "==> 卸载 release=$Release namespace=$Namespace" -ForegroundColor Cyan
& $Helm uninstall $Release --namespace $Namespace --wait
if ($LASTEXITCODE -ne 0) { throw "卸载失败" }

Write-Host "==> 完成" -ForegroundColor Green
