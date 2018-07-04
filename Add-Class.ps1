<#
.SYNOPSIS
Generates a class.

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
	# Name of the class generated
	[Parameter(Mandatory=$true)]
	[String]$Name,
	# Name of plugin to generate class for. Root means project root
	[Parameter(ParameterSetName = "Plugin", Mandatory = $true)]
	[Parameter(ParameterSetName = "PluginBase", Mandatory = $true)]
	[String]$Plugin = "",
	# Name of the base class
	[Parameter(ParameterSetName = "Base", Mandatory = $true)]
	[Parameter(ParameterSetName = "PluginBase", Mandatory = $true)]
	[String]$Base = "UObject",
	# Relative path to the class header and implementation
	[Parameter()]
	[String]$Path = "",
	# Directory containing cpp files. Possible values: provided > found in config > plugin sources root > .
	[Parameter()]
	[String]$CppsRoot = "",
	# Directory containing header files. Possible values: provided > found in config > plugin sources root > .
	[Parameter()]
	[String]$HeadersRoot = "",
	# Path to the config. Should be relative to cwd or to cwd/Source/$(cwd name). Should be a JSON object with fields CppsRoot, HeadersRoot, PrivateHeadersRoot, ProjectRoot
	[Parameter()]
	[String]$ConfigPath = "uesp.json",
	# Generate header as private
	[Parameter(ParameterSetName = "Plugin")]
	[Parameter(ParameterSetName = "PluginBase")]
	[Switch]$Private,
	# Force the override of existing files
	[Parameter(ParameterSetName = "Common")]
	[Parameter(ParameterSetName = "Base")]
	[Parameter(ParameterSetName = "Plugin")]
	[Parameter(ParameterSetName = "PluginBase")]
	[Switch]$Force,
	# Path to the base class. It may be found automaticaly in project source tree if not provided
	[Parameter(ParameterSetName = "Base")]
	[Parameter(ParameterSetName = "PluginBase")]
	[String]$BasePath = ""
)

$startPath = Get-Location

. "$PSScriptRoot/Implementations/ParseConfig.ps1"

$ueIncludes = @("CoreMinimal.h")
$includes = $null

. "$PSScriptRoot/Implementations/ResolveBase.ps1"

$body =
"public:`r`n`t`r`n`t"

if ($finalBase.Length -gt 0)
{
	$finalBase = "public $finalBase"
}

& $PSScriptRoot/Add-Cpp.ps1 `
	-Name $Name `
	-Path $Path `
	-CppsRoot $CppsRoot `
	-HeadersRoot $HeadersRoot `
	-DeclatationType class `
	-Base $finalBase `
	-UEHeaderIncludes $ueIncludes `
	-HeaderIncludes $includes `
	-BodyContent $body `
	-Force: $Force

Set-Location $startPath
