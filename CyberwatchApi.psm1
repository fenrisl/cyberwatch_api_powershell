# Powershell Cyberwatch Api Client

Function SendApiRequest
{
<#
.SYNOPSIS
        Cyberwatch API Powershell Client.
.DESCRIPTION
        Send REST Query to Cyberwatch API
.EXAMPLE
        SendApiRequest -api_url $API_URL -api_key $API_KEY -secret_key $SECRET_KEY -http_method $http_method -request_URI $request_URI
.PARAMETER api_url
        Your Cyberwatch instance base url
#>
Param    (
    [PARAMETER(Mandatory=$true)][string]$api_url = 'https://cyberwatch.local',
    [PARAMETER(Mandatory=$true)][string]$api_key,
    [PARAMETER(Mandatory=$true)][string]$secret_key,
    [PARAMETER(Mandatory=$true)][string]$http_method = 'GET',
    [PARAMETER(Mandatory=$true)][string]$request_URI = '/api/v3/ping',
    [PARAMETER(Mandatory=$false)][Hashtable]$content
    )

    if ($content -and ($http_method -ne "GET")) {
        $content_type = 'application/json'
        $body_content = $content | ConvertTo-Json
    }
    elseif ($content -and ($http_method -eq "GET")) {
        Add-Type -AssemblyName System.Web
        $query_strings = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)

        foreach ($key in $content.Keys) {
            $query_strings.Add($key, $content.$key)
        }

        $uriRequest = [System.UriBuilder]"${API_URL}${request_URI}"
        $uriRequest.Query = $query_strings.ToString()
        $params = $uriRequest.Query
        $body_content = $content
    }

    $content_MD5 = ''
    $timestamp = [System.DateTime]::UtcNow.ToString('R')
    $message = "$http_method,$content_type,$content_MD5,$request_URI$params,$timestamp"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($SECRET_KEY)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($message))
    $signature = [Convert]::ToBase64String($signature)

    Invoke-WebRequest -Uri "${API_URL}${request_URI}" -Method $http_method -Headers @{
        "accept"        = "application/json";
        "Date"          = $timestamp
        "Authorization" = "Cyberwatch APIAuth-HMAC-SHA256 ${API_KEY}:$signature"
    } -ContentType $content_type -Body $body_content
}

Function SendApiRequestPagination
{
Param    (
    [PARAMETER(Mandatory=$true)][string]$api_url = 'https://cyberwatch.local',
    [PARAMETER(Mandatory=$true)][string]$api_key,
    [PARAMETER(Mandatory=$true)][string]$secret_key,
    [PARAMETER(Mandatory=$true)][string]$http_method = 'GET',
    [PARAMETER(Mandatory=$true)][string]$request_URI = '/api/v3/ping',
    [PARAMETER(Mandatory=$false)][Hashtable]$content = @{}
    )

    if ($content.ContainsKey("per_page") -eq $false) {
        $content.Add("per_page", 100)
    }

    $response = SendApiRequest -api_url $api_url -api_key $api_key -secret_key $secret_key -http_method $http_method -request_URI $request_URI -content $content

    if ($response.headers["link"] -match "[?&]page=(\d*)" -and $content.ContainsKey("page") -eq $false) {
        $last_page_number = $matches[1]
        1..$last_page_number | % {
        $content["page"] = $_;
        SendApiRequest -api_url $api_url -api_key $api_key -secret_key $secret_key -http_method $http_method -request_URI $request_URI -content $content | ConvertFrom-Json | % { $_ }
        }
    }

    else { $response | ConvertFrom-JSON }

}

Class CbwApiClient {
    [string]$api_url
    [string]$api_key
    [string]$secret_key

    CbwApiClient ([string]$api_url, [string]$api_key, [string]$secret_key)
    {
        $this.api_url = $api_url
        $this.api_key = $api_key
        $this.secret_key = $secret_key
    }

    [object] request([string]$http_method, [string]$request_URI) {
        return SendApiRequest -api_url $this.api_url -api_key $this.api_key -secret_key $this.secret_key -http_method $http_method -request_URI $request_URI | ConvertFrom-JSON
    }

    [object] request([string]$http_method, [string]$request_URI, [Hashtable]$content) {
        return SendApiRequest  -api_url $this.api_url -api_key $this.api_key -secret_key $this.secret_key -http_method $http_method -request_URI $request_URI -content $content | ConvertFrom-JSON
    }

    [object] request_pagination([string]$http_method, [string]$request_URI) {
        return SendApiRequestPagination -api_url $this.api_url -api_key $this.api_key -secret_key $this.secret_key -http_method $http_method -request_URI $request_URI
    }

    [object] request_pagination([string]$http_method, [string]$request_URI, [Hashtable]$content) {
        return SendApiRequestPagination -api_url $this.api_url -api_key $this.api_key -secret_key $this.secret_key -http_method $http_method -request_URI $request_URI -content $content
    }

    [object] ping()
    {
        return $this.request('GET', '/api/v3/ping')
    }

    [object] servers()
    {
        return $this.request('GET', '/api/v2/servers')
    }

    [object] server([string]$id)
    {
        return $this.request('GET', "/api/v2/servers/${id}")
    }

    [object] update_server([string]$id, [Object]$content)
    {
        return $this.request('PUT', "/api/v2/servers/${id}", $content)
    }

    [object] delete_server([string]$id)
    {
        return $this.request('DELETE', "/api/v2/servers/${id}")
    }

    [object] server_schedule_updates([string]$id, [Object]$content)
    {
        return $this.request('POST', "/api/v2/servers/${id}/updates", $content)
    }

    [object] remote_accesses()
    {
        return $this.request('GET', '/api/v2/remote_accesses')
    }

    [object] create_remote_access([Object]$content)
    {
        return $this.request('POST', '/api/v2/remote_accesses', $content)
    }

    [object] remote_access([string]$id)
    {
        return $this.request('GET', "/api/v2/remote_accesses/${id}")
    }

    [object] update_remote_access([string]$id, [Object]$content)
    {
        return $this.request('PATCH', "/api/v2/remote_accesses/${id}", $content)
    }

    [object] delete_remote_access([string]$id)
    {
        return $this.request('DELETE', "/api/v2/remote_accesses/${id}")
    }

    [object] groups()
    {
        return $this.request('GET', "/api/v2/groups")
    }

    [object] cve_announcement([string]$id)
    {
        return $this.request('GET', "/api/v3/cve_announcements/${id}")
    }

    [object] cve_announcements()
    {
        return $this.request_pagination('GET', "/api/v3/cve_announcements")
    }

    [object] cve_announcements([Hashtable]$filter)
    {
        return $this.request_pagination('GET', "/api/v3/cve_announcements", $filter)
    }

    [object] users()
    {
        return $this.request('GET', "/api/v2/users")
    }
}


function Get-CyberwatchApi
{
<#
.SYNOPSIS
        Cyberwatch API Powershell Client.
.DESCRIPTION
        Send REST Query to Cyberwatch API
.EXAMPLE
        Get-CyberwatchApi -api_url $API_URL -api_key $API_KEY -secret_key $SECRET_KEY
        Get-CyberwatchApi -api_url $API_URL -api_key $API_KEY -secret_key $SECRET_KEY -trust_all_certificates $ALLOW_SELFSIGNED
.PARAMETER api_url
        Your Cyberwatch instance base url
#>
Param    (
    [PARAMETER(Mandatory=$true)][string]$api_url = 'https://cyberwatch.local',
    [PARAMETER(Mandatory=$true)][string]$api_key,
    [PARAMETER(Mandatory=$true)][string]$secret_key,
    [PARAMETER(Mandatory=$false)][bool]$trust_all_certificates = $false
    )

    # Allow request to self-signed certificate
    if($trust_all_certificates) {
        add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
          public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
          }
        }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    return [CbwApiClient]::new($api_url, $api_key, $secret_key)
}

