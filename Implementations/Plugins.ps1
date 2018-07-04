function Get-PluginPath([String]$ProjectRoot, [String]$Name)
{
	if ($Name.ToLower() -eq "root")
	{
		return "$ProjectRoot"
	}

	return "$ProjectRoot/Plugins/$Name/Source/$Name"
}