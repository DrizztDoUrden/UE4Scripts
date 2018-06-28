function Load-Config([String]$cfgPath)
{
	return (Get-Content $cfgPath) -join "`r`n" | ConvertFrom-Json
}

function Parse-Config([String]$cfgPath)
{
	if (Test-Path $cfgPath)
	{
		return Load-Config $cfgPath
	}
	else
	{
		$config = New-Object -TypeName PSObject
		$config | Add-Member -MemberType NoteProperty -Name CppsRoot -Value "."
		$config | Add-Member -MemberType NoteProperty -Name HeadersRoot -Value "."
		$config | Add-Member -MemberType NoteProperty -Name ProjectRoot -Value "../.."
		return $config
	}
}