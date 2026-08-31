$clientId = "97c651f5-6f20-44e6-941c-ae5c9f2296f1"
$clientSecret = "qfcs_a397381eee834fd7a4c23007e8b7a4a7f53c29790b3c42569d970af3c4e6cd6d"

$pair = "${clientId}:${clientSecret}"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

$response = Invoke-RestMethod -Method Post -Uri "https://oauth2.quran.foundation/oauth2/token" -Headers @{ "Authorization" = "Basic $basicAuth"; "Content-Type" = "application/x-www-form-urlencoded" } -Body "grant_type=client_credentials&scope=content"

$token = $response.access_token
Write-Host "Token OK, panjang: $($token.Length) karakter"

$result = Invoke-RestMethod -Method Get -Uri "https://apis.quran.foundation/content/api/v4/verses/by_page/1?words=true&word_fields=code_v2,line_number,page_number&mushaf=1" -Headers @{ "x-auth-token" = $token; "x-client-id" = $clientId }

$result | ConvertTo-Json -Depth 10