$CppsRootArg = $CppsRoot
$HeadersRootArg = $HeadersRoot

if (-not (Test-Path -PathType Leaf $ConfigPath))
{
	Set-Location "Source/$((Get-Item .).Name)"
}

if (Test-Path -PathType Leaf $ConfigPath)
{
	$config = Parse-Config $ConfigPath
	$CppsRoot = $config.CppsRoot
	$HeadersRoot = $config.HeadersRoot
	$ProjectRoot = $config.ProjectRoot
}

if ($Plugin.Length -gt 0)
{
	$pluginPath = $(Get-PluginPath $ProjectRoot $Plugin)

	if (-not (Test-Path $pluginPath -PathType Container))
	{
		throw "-Plugin should be an existing plugin. Possible values: $([String]::Join(', ', (Get-ChildItem $ProjectRoot/Plugins | % Name)))."
	}

	Set-Location $(Get-PluginPath $ProjectRoot $Plugin)
	$config = Parse-Config uesp.json
	$CppsRoot = $config.CppsRoot
	if ($Private) { $HeadersRoot = $config.PrivateHeadersRoot }
	else { $HeadersRoot = $config.HeadersRoot }
	$ProjectRoot = $config.ProjectRoot
}

if ($CppsRootArg.Length -gt 0) { $CppsRoot = $CppsRootArg }
if ($HeadersRootArg.Length -gt 0) { $HeadersRoot = $HeadersRootArg }

Write-Verbose "CPPs root: $CppsRoot"
Write-Verbose "Headers root: $HeadersRoot"
Write-Verbose "Project root: $ProjectRoot"
