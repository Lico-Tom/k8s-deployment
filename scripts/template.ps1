# 本地渲染模板（PowerShell 版），输出所有 K8s 清单
# 用法:
#   .\scripts\template.ps1 -Env prod
#   .\scripts\template.ps1 -Env dev -Release api -OutputFile render.yaml

param(
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Env,

    [string]$Release = 'api',
    [string]$Helm = 'helm',
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'

$chartDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Push-Location $chartDir

try {
    $argsList = @('template', $Release, '.')
    if ($Env) {
        $valuesFile = Join-Path 'environments' "values-$Env.yaml"
        if (-not (Test-Path $valuesFile)) { throw "环境配置不存在: $valuesFile" }
        $argsList += @('--values', $valuesFile)
    }

    if ($OutputFile) {
        & $Helm @argsList | Out-File -FilePath $OutputFile -Encoding utf8
        Write-Host "==> 已输出到 $OutputFile"
    }
    else {
        & $Helm @argsList
    }
    if ($LASTEXITCODE -ne 0) { throw "渲染失败" }
}
finally {
    Pop-Location
}
