# URL for the Windows 11 release information page
$url = "https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information"

try {
    # Download the page as raw text
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $content = $response.Content
}
catch {
    Write-Error "Error downloading the page: $_"
    return
}

# --- Extract the Table Block ---
# Find the section that starts with "<strong>Version 24H2 (OS build 26100)</strong>" and capture the following <table>...</table>
$sectionRegex = '(?s)<strong>\s*Version\s+24H2\s*\(OS build 26100\)\s*</strong>.*?(<table.*?>.*?</table>)'
$tableMatch = [regex]::Match($content, $sectionRegex)
if (-not $tableMatch.Success) {
    Write-Error "Could not find the table under 'Version 24H2 (OS build 26100)'."
    return
}
$tableHtml = $tableMatch.Groups[1].Value

# --- Extract Table Rows ---
# Get all rows within the table.
$rowMatches = [regex]::Matches($tableHtml, '(?s)<tr.*?>(.*?)</tr>')
if ($rowMatches.Count -eq 0) {
    Write-Error "No table rows found."
    return
}

# --- Parse the Header Row ---
# Assume the first row contains headers. Try to get <th> elements; fallback to <td> if necessary.
$headerRowHtml = $rowMatches[0].Groups[1].Value
$headerMatches = [regex]::Matches($headerRowHtml, '(?s)<th.*?>(.*?)</th>')
if ($headerMatches.Count -eq 0) {
    $headerMatches = [regex]::Matches($headerRowHtml, '(?s)<td.*?>(.*?)</td>')
}

$headers = @()
foreach ($cell in $headerMatches) {
    $headers += $cell.Groups[1].Value.Trim()
}

# Determine the column indices needed for processing:
# We're interested in "Availability", "Update type", "Build", and "KB article"
$availabilityIndex = $headers.FindIndex({ $_ -match '(?i)Availability' })
$updateTypeIndex   = $headers.FindIndex({ $_ -match '(?i)Update\s*type' })
$buildIndex        = $headers.FindIndex({ $_ -match '(?i)\bBuild\b' })
$kbArticleIndex    = $headers.FindIndex({ $_ -match '(?i)KB\s*article' })

if ($availabilityIndex -lt 0 -or $updateTypeIndex -lt 0 -or $buildIndex -lt 0 -or $kbArticleIndex -lt 0) {
    Write-Error "Could not determine necessary columns. Found headers: $($headers -join ', ')"
    return
}

$results = @()

# --- Process Each Data Row ---
# Skip the header row (starting at index 1)
for ($i = 1; $i -lt $rowMatches.Count; $i++) {
    $rowHtml = $rowMatches[$i].Groups[1].Value
    $cellMatches = [regex]::Matches($rowHtml, '(?s)<td.*?>(.*?)</td>')
    if ($cellMatches.Count -eq 0) { continue }

    # Get the "Update type" cell text and trim it.
    $updateType = ($cellMatches[$updateTypeIndex].Groups[1].Value).Trim()
    # Filter: Only include rows where the Update type ends with "D"
    if ($updateType -notmatch 'D\s*$') { continue }

    # Extract the Availability date and Build from their respective columns.
    $availability = ($cellMatches[$availabilityIndex].Groups[1].Value).Trim()
    $build        = ($cellMatches[$buildIndex].Groups[1].Value).Trim()

    # For the KB article column, extract only the href value from the <a> tag.
    $kbCellHtml = $cellMatches[$kbArticleIndex].Groups[1].Value
    $kbHrefMatch = [regex]::Match($kbCellHtml, '<a\s+[^>]*href\s*=\s*["'']([^"'']+)["'']', 'IgnoreCase')
    $kbHref = if ($kbHrefMatch.Success) { $kbHrefMatch.Groups[1].Value.Trim() } else { "" }

    # Create an object with the desired properties.
    $obj = [PSCustomObject]@{
        Availability = $availability
        Build        = $build
        KbArticle    = $kbHref
    }
    $results += $obj
}

# Output the results
$results