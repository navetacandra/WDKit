Param (
	[string]$url,
	[string]$filepath
)

$userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.3"
$dname=(Split-Path -Path $filepath)
$fname=(Split-Path -Path $filepath -Leaf)
$tempdir = "$dname\$fname-parts"
if (-not (Test-Path -Path $tempdir)) {
	New-Item -ItemType Directory -Path $tempdir | Out-Null
}

$num_parts = 8
$headers = (Invoke-WebRequest -Uri $url -Method Head -UserAgent $userAgent).Headers
if($headers.'Accept-Ranges' -ne 'bytes') {
	$num_parts = 1
}
$filesize = $headers.'Content-Length'
$filesize = [int]$filesize

$part_size = [math]::Ceiling($filesize / $num_parts)

$jobs = @()
for ($i = 0; $i -lt $num_parts; $i++) {
	$start = $i * $part_size
	$end = (($i + 1) * $part_size) - 1
	if ($i -eq ($num_parts - 1)) { $end = $filesize - 1 }

	$jobs += Start-Job -ScriptBlock {
		Param ($url, $start, $end, $tempdir, $part)
		
		$request = [System.Net.WebRequest]::Create($url)
		$request.Method = "GET"
		$request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0"
		$request.Accept = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
		$request.Headers.Add("Accept-Encoding", "gzip, deflate, br, zstd")
		$request.Headers.Add("Accept-Language", "en-US,en;q=0.9,id;q=0.8")
		$request.Headers.Add("DNT", "1")
		$request.Headers.Add("Sec-Fetch-Dest", "document")
		$request.Headers.Add("Sec-Fetch-Mode", "navigate")
		$request.Headers.Add("Sec-Fetch-Site", "none")
		$request.Headers.Add("Sec-Fetch-User", "?1")
		$request.Headers.Add("Upgrade-Insecure-Requests", "1")
		$request.Headers.Add("sec-ch-ua", "`"Microsoft Edge`";v=`"129`", `"Not=A?Brand`";v=`"8`", `"Chromium`";v=`"129`"")
		$request.Headers.Add("sec-ch-ua-mobile", "?0")
		$request.Headers.Add("sec-ch-ua-platform", "Windows")
		$request.AddRange('bytes', $start, $end)
		$response = $request.GetResponse()
		$stream = $response.GetResponseStream()
		$fileStream = [System.IO.File]::Create((Join-Path $tempdir $part))
		$buffer = New-Object byte[] 8192
		while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
			$fileStream.Write($buffer, 0, $bytesRead)
		}
		$stream.Close()
		$fileStream.Close()
	} -ArgumentList $url, $start, $end, $tempdir, "$fname.part$i"
}

$jobs | ForEach-Object { $_ | Wait-Job | Out-Null }

$output = [System.IO.File]::Create($filepath)
foreach ($i in 0..($num_parts-1)) {
	$part = Join-Path $tempdir "$fname.part$i"
	$buffer = New-Object byte[] 8192
	$fileStream = [System.IO.File]::OpenRead($part)
	while (($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
		$output.Write($buffer, 0, $bytesRead)
	}
	$fileStream.Close()
}
$output.Close()

Remove-Item -Recurse -Force $tempdir
