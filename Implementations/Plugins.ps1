function Get-PluginPath([String]$ProjectRoot, [String]$Name)
{
	return "$ProjectRoot/Plugins/$Name/Source/$Name"
}