# Pester tests for NetworkDriverTool

Describe 'NetworkDriverTool Tests' {
    It 'Should have config file' {
        $configPath = Join-Path $PSScriptRoot 'config.json'
        Test-Path $configPath | Should Be $true
    }

    It 'Should have main script' {
        $scriptPath = Join-Path $PSScriptRoot 'NetworkDriverTool.ps1'
        Test-Path $scriptPath | Should Be $true
    }

    It 'Should have analytics module' {
        $analyticsPath = Join-Path $PSScriptRoot 'analytics.ps1'
        Test-Path $analyticsPath | Should Be $true
    }

    It 'Should have voice module' {
        $voicePath = Join-Path $PSScriptRoot 'voice.ps1'
        Test-Path $voicePath | Should Be $true
    }

    It 'Should have dashboard module' {
        $dashboardPath = Join-Path $PSScriptRoot 'dashboard.ps1'
        Test-Path $dashboardPath | Should Be $true
    }

    It 'Should have security module' {
        $securityPath = Join-Path $PSScriptRoot 'security.ps1'
        Test-Path $securityPath | Should Be $true
    }

    It 'Should have README' {
        $readmePath = Join-Path $PSScriptRoot 'README.md'
        Test-Path $readmePath | Should Be $true
    }

    It 'Should have LICENSE' {
        $licensePath = Join-Path $PSScriptRoot 'LICENSE'
        Test-Path $licensePath | Should Be $true
    }

    It 'Should have Dockerfile' {
        $dockerfilePath = Join-Path $PSScriptRoot 'Dockerfile'
        Test-Path $dockerfilePath | Should Be $true
    }

    It 'Should have docker-compose file' {
        $composePath = Join-Path $PSScriptRoot 'docker-compose.yml'
        Test-Path $composePath | Should Be $true
    }
}