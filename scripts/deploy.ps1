# 部署/升级到指定环境（PowerShell 版）
# 用法:
#   .\scripts\deploy.ps1 -Env dev
#   .\scripts\deploy.ps1 -Env prod -Namespace prod -Release api
#   .\scripts\deploy.ps1 -Env dev -DryRun          # 只渲染不落集群

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Env,

    [string]$Namespace,
    [string]$Release = 'api',
    [string]$Helm = 'helm',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$chartDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Push-Location $chartDir

try {
    if ([string]::IsNullOrWhiteSpace($Namespace)) { $Namespace = $Env }
    $valuesFile = Join-Path 'environments' "values-$Env.yaml"

    if (-not (Test-Path $valuesFile)) {
        throw "环境配置不存在: $valuesFile"
    }

    Write-Host "==> 前置 lint 检查" -ForegroundColor Cyan
    & $Helm lint . --values $valuesFile
    if ($LASTEXITCODE -ne 0) { throw "lint 未通过" }

    $common = @('upgrade', '--install', $Release, '.',
        '--namespace', $Namespace,
        '--create-namespace',
        '--values', $valuesFile,
        '--timeout', '5m',
        '--history-max', '10')

    if ($DryRun) {
        Write-Host "==> DryRun 渲染（不落集群）" -ForegroundColor Cyan
        & $Helm template $Release '.' '--values' $valuesFile
        return
    }

    Write-Host "==> 部署 release=$Release namespace=$Namespace env=$Env" -ForegroundColor Cyan
    & $Helm @common --atomic --wait
    if ($LASTEXITCODE -ne 0) {
        Write-Host "==> 部署失败，回滚到上一版本" -ForegroundColor Red
        & $Helm rollback $Release --namespace $Namespace
        throw "部署失败，已执行回滚"
    }

    & $Helm status $Release --namespace $Namespace
}
finally {
    Pop-Location
}
