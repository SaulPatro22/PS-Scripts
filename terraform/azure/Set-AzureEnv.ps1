function Test-SecureStringEmpty {
    param (
        [System.Security.SecureString]$SecureStr
    )

    if (-not $SecureStr) {
        return $true
    }

    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStr)

    try {
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        return [string]::IsNullOrEmpty($plain)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}


# Verify availability of the Az CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it from https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}
Write-Host "Azure CLI is installed."

# Verify if the user is logged in to Azure CLI
if (-not (az account show --query "id" --output tsv)) {
    Write-Error "You are not logged in to Azure CLI. Please log in using 'az login'."
    exit 2
}


# Reading Service Principal Name
$ServicePrincipalName = Read-Host "Enter the Service Principal Name (e.g., 'my-sp')"
if (-not $ServicePrincipalName) {
    Write-Error "Service Principal Name cannot be empty."
    exit 3
}

$ClientSecret = Read-Host "Enter the Client Secret (leave empty if not available)" -AsSecureString
Write-Host ""

# Flag to cheack if any error occurs
$ErrorFlag = $false

# Get Client ID
$clientId = (az ad sp list --display-name $ServicePrincipalName --query "[0].appId" --output tsv)
if (-not $clientId) {
    Write-Error "Was unable to find the Client ID for the Service Principal '$ServicePrincipalName'. Please check if the Service Principal exists."
    $ErrorFlag = $true
} else {
    Write-Host "Client ID found"
}

# Get Subscription ID
$subscriptionId = (az account show --query "id" --output tsv)
if (-not $subscriptionId) {
    Write-Error "Was unable to find the Subscription ID. Please check if you are logged in to the correct subscription."
    $ErrorFlag = $true
} else {
    Write-Host "Subscription ID found"
}

# Get Tenant ID
$tenantId = (az account show --query "tenantId" --output tsv)
if (-not $tenantId) {
    Write-Error "Was unable to find the Tenant ID. Please check if you are logged in to the correct tenant."
    $ErrorFlag = $true
} else {
    Write-Host "Tenant ID found"
}


if ($ErrorFlag) {
    Write-Host "Please check the errors above and try again."
    exit 4
}

Write-Host ""
Write-Host "All required information has been retrieved successfully."
Write-Host "Setting environment variables..."
# Export the variables to the environment
$Env:ARM_CLIENT_ID = $clientId
$Env:ARM_SUBSCRIPTION_ID = $subscriptionId
$Env:ARM_TENANT_ID = $tenantId


# Set client secret if available from params
if (-not (Test-SecureStringEmpty $ClientSecret)) {
    Write-Host ""
    Write-Host "Client Secret available, transforming SecureString to PlainString."
    # Convert the SecureString to a plain string
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
    try {
        $plainClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }

    # Set the environment variable for the client secret
    Write-Host "Setting ARM_CLIENT_SECRET environment variable."
    $Env:ARM_CLIENT_SECRET = $plainClientSecret
} else {
    # Show a message to the user to set the client secret manually
    Write-Host ""
    Write-Host "Client Secret is empty, please set the ARM_CLIENT_SECRET environment variable manually."
}