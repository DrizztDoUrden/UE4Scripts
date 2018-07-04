<#
.SYNOPSIS
Switch directory to make specified plugin default.

.DESCRIPTION
Supports usage of configuration files for saving some parameter values. It should be placed to source root with name uesp.json for full support. Cfg file format:
{
  "CppsRoot": "<path to implementations>",
  "HeadersRoot": "<path to public headers>",
  "PrivateHeadersRoot": "<path to private headers>",
  "ProjectRoot": "<path to the project root for header search and plugin system>"
}
#>

Param(
	# Name of plugin to switch to. Root means switch to project root
	[Parameter(Mandatory = $true)]
	[String]$Plugin = "",
	# Path to the config. Should be relative to cwd or to cwd/Source/$(cwd name). Should be a JSON object with fields CppsRoot, HeadersRoot, PrivateHeadersRoot, ProjectRoot
	[Parameter()]
	[String]$ConfigPath = "uesp.json"
)

. "$PSScriptRoot/Implementations/Plugins.ps1"
. "$PSScriptRoot/Implementations/ParseConfig.ps1"
