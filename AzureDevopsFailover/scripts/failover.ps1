function Write-Log {
    param ([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Output "$timestamp [$Level] $Message"
}

function Invoke-WithRetry {
    param (
        [scriptblock]$Operation,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 10
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            & $Operation
            Write-Log "Success on attempt $i"
            break
        } catch {
            Write-Log "Attempt $i failed: $_" "WARN"
            if ($i -eq $MaxRetries) { throw $_ }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

Write-Log "Starting regional failover..."

Invoke-WithRetry -Operation {
    Start-AzSqlDatabaseFailover -ResourceGroupName 'Prod-RG' -ServerName 'sql-primary' -FailoverGroupName 'fg-prod'
}

Invoke-WithRetry -Operation {
    Set-AzApplicationGatewayBackendAddressPool -Name 'SecondaryPool' -GatewayName 'AppGW01' -ResourceGroupName 'Prod-RG'
}

Invoke-WithRetry -Operation {
    Start-AzRecoveryServicesAsrUnplannedFailover -RecoveryPlanName 'DRPlan01' -ResourceGroupName 'Prod-RG'
}

Write-Log "Failover completed successfully."