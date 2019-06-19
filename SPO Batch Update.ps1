$global:webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Site Collection URL
$_url = "https://sharepointdevlab.sharepoint.com/sites/spike"

# Connect to SPO PnP and use the Auth cookies for web request.
function Init-SPOConnection {
    param($Url)

    # Get credentials to connect to SPO
    $cred = Get-Credential -Message "Credentials for SPO"
    Connect-PnPOnline $Url -Credentials $cred

    # Get the Authetication Cookies
    $webCtx = (Get-PnPWeb).Context
    $authCookies = $webCtx.Credentials.GetAuthenticationCookie($Url, $true)

    #Set webSession Auth cookies
    $global:webSession.Cookies.SetCookies($Url, $authCookies)
    $global:webSession.Headers.Add("Accept", "application/json;odata=verbose")
}

# Call this function before each web request to renew page security validation
function Update-RequestDigest {
    $global:webSession.Headers.Remove("X-RequestDigest") #If header already available, remove it and add new page validation
    $global:webSession.Headers.Add("X-RequestDigest", (Get-PnPWeb).Context.GetFormDigestDirect().DigestValue)
}

# Update the logic below to read from CSV and create Object Array as per your list schema
# Keep in mind the SPO REST API can take upto 100 request in one batch.
$itemPayload = @(
    @{"__metadata" = @{"type" = "SP.Data.ListAListItem"}; "Title"="Test 1"},
    @{"__metadata" = @{"type" = "SP.Data.ListAListItem"}; "Title"="Test 2"},
    @{"__metadata" = @{"type" = "SP.Data.ListAListItem"}; "Title"="Test 3"},
    @{"__metadata" = @{"type" = "SP.Data.ListAListItem"}; "Title"="Test 4"},
    @{"__metadata" = @{"type" = "SP.Data.ListAListItem"}; "Title"="Test 5"},
    @{"__metadata" = @{"type" = "SP.Data.ListAListItem"}; "Title"="Test 6"}
)

$listUrl = "$_url/_api/web/lists/getbytitle('ListA')/Items"

#Init Batch request from here (Do not change any of the logic b/w this and #End-Init batch comment.
$batchGUID = [System.guid]::NewGuid().toString()
$changeSetGUID = [System.guid]::NewGuid().toString()

$changesetBody = "";

$itemPayload | ForEach-Object {
    $changesetBody = -join($changesetBody, "--changeset_$changeSetGUID", "`r`n")
    $changesetBody = -join($changesetBody, "Content-Type: application/http", "`r`n")
    $changesetBody = -join($changesetBody, "Content-Transfer-Encoding: binary", "`r`n`r`n")
    $changesetBody = -join($changesetBody, "POST $listUrl HTTP/1.1", "`r`n")
    $changesetBody = -join($changesetBody, "Content-Type: application/json;odata=verbose", "`r`n`r`n")
    $changesetBody = -join($changesetBody, ($_ | ConvertTo-Json -Compress), "`r`n`r`n")
}

$changesetBody = -join($changesetBody, "--changeset_$changeSetGUID--", "`r`n")

$body = "--batch_$batchGUID`r`n"
$body = -join($body, "Content-Type: multipart/mixed; boundary=changeset_$changeSetGUID", "`r`n")
$body = -join($body, "Content-Length: $($changesetBody.Length)", "`r`n")
$body = -join($body, "Content-Transfer-Encoding: binary", "`r`n`r`n")

$body = -join($body, $changesetBody, "`r`n")

$body = -join($body, "--batch_$batchGUID--", "`r`n")

$enc = [system.Text.Encoding]::ASCII
$data = $enc.GetBytes($body)
#End-init batch

Init-SPOConnection -Url $_url
Update-RequestDigest
#Single request
$jsonObj = Invoke-WebRequest -Uri "$_url/_api/`$batch" -Method Post -Headers @{"Content-Type"="multipart/mixed; boundary=batch_$batchGUID"; "Content-Length"=$data.Length; "Host"="sharepointdevlab.sharepoint.com"} -Body $data -WebSession $global:webSession
