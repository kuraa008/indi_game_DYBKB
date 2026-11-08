# Черновая озвучка кат-сцен: читает список заданий (JSON) и озвучивает каждое
# голосом Windows (OneCore: «Microsoft Pavel», «Microsoft Irina» — русский пакет речи).
# Вызывается из game/scripts/generate_cutscene_audio.js, руками запускать не нужно.
# Задание: { "voice": "Pavel", "ssml": "<speak ...>", "out": "C:\\...\\id.wav" }
param([string]$Jobs)
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) {
	$task = $asTaskGeneric.MakeGenericMethod($t).Invoke($null, @($op))
	$task.Wait(-1) | Out-Null
	$task.Result
}
$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$all = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
$list = Get-Content -Raw -Encoding UTF8 $Jobs | ConvertFrom-Json
foreach ($job in $list) {
	$v = $all | Where-Object { $_.DisplayName -like ("*" + $job.voice + "*") } | Select-Object -First 1
	if ($null -eq $v) { Write-Output ("no voice " + $job.voice); continue }
	$synth.Voice = $v
	$stream = Await ($synth.SynthesizeSsmlToStreamAsync($job.ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
	$size = [uint32]$stream.Size
	$reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
	$null = Await ($reader.LoadAsync($size)) ([uint32])
	$bytes = New-Object byte[] $size
	$reader.ReadBytes($bytes)
	[System.IO.File]::WriteAllBytes($job.out, $bytes)
	Write-Output ("ok " + $job.out)
}
