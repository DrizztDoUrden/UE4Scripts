. "$PSScriptRoot/Configs.ps1"

function TryResolveFromDirectory([String]$FileName, [String]$Path, [Int]$cutOff)
{
	Write-Verbose "Searching for header <$fileName> in <$($Path | Resolve-Path)>..."
	$files = Get-ChildItem $Path -Recurse -File -Filter $fileName | Resolve-Path -Relative

	if (($files | Measure-Object).Count -eq 1)
	{
		$headerPath = $files.Substring($cutOff + 1).Replace("\", "/");
		$includes += $headerPath
		Write-Verbose "Using <$headerPath> as base class"
		return $true
	}

	return $false
}

function TryResolve([String]$FileName, [String]$Path, $cfg, [Bool]$IncludePrivate = $false)
{
	if ($IncludePrivate -and ($cfg.PrivateHeadersRoot.Length -gt 0) -and ($cfg.PrivateHeadersRoot -ne $cfg.HeadersRoot))
	{
		if (TryResolveFromDirectory $FileName $Path/$($cfg.PrivateHeadersRoot) $Path.Length) { return $true }
	}

	return TryResolveFromDirectory $FileName $Path/$($cfg.HeadersRoot) $Path.Length
}

function Resolve-Header([String]$FileName)
{
	if (-not (TryResolve $fileName . $config $true))
	{
		$found = $false

		if ($ProjectRoot.Length -gt 0)
		{
			foreach ($pluginSearched in (Get-ChildItem $ProjectRoot/Plugins))
			{
				if ($Plugin -eq $pluginSearched -or -not (Test-Path -PathType Leaf $pluginPath/uesp.json)) { continue }
				$pluginPath = $(Get-PluginPath $ProjectRoot $pluginSearched)

				if (TryResolve $fileName $pluginPath (Load-Config $pluginPath/uesp.json))
				{
					$found = $true
					break
				}
			}
		}

		if (-not $found -and $Plugin.Length -gt 0)
		{
			if ($Plugin -eq $pluginSearched -or -not (Test-Path -PathType Leaf $pluginPath/uesp.json)) { continue }
			$rootSourcePath = "$ProjectRoot/Source/$((Get-Item $ProjectRoot).Name)"
			TryResolve $fileName $rootSourcePath (Load-Config $rootSourcePath/uesp.json);
		}
	}
}
