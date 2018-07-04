<#
.SYNOPSIS
Generates a UENUM based enum.

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
	# Name of the enum generated
	[Parameter(Mandatory=$true)]
	[String]$Name,
	# Name of plugin to generate enum for. Root means project root
	[Parameter()]
	[String]$Plugin = "",
	# Relative path to the enum header and implementation
	[Parameter()]
	[String]$Path = "",
	# Directory containing cpp files. Possible values: provided > found in config > plugin sources root > .
	[Parameter()]
	[String]$CppsRoot = "",
	# Directory containing header files. Possible values: provided > found in config > plugin sources root > .
	[Parameter()]
	[String]$HeadersRoot = "",
	# UENUM modifiers like BlueprintType
	[Parameter()]
	[String[]]$Mods = @(),
	# Path to the config. Should be relative to cwd or to cwd/Source/$(cwd name). Should be a JSON object with fields CppsRoot, HeadersRoot, PrivateHeadersRoot, ProjectRoot
	[Parameter()]
	[String]$ConfigPath = "uesp.json",
	# Generate header as private
	[Parameter()]
	[Switch]$Private,
	# Force the override of existing files
	[Parameter()]
	[Switch]$Force
)

$startPath = Get-Location

. "$PSScriptRoot/Implementations/Plugins.ps1"
. "$PSScriptRoot/Implementations/ParseConfig.ps1"

& $PSScriptRoot/Add-Cpp.ps1 `
	-Name $Name `
	-Path $Path `
	-CppsRoot $CppsRoot `
	-HeadersRoot $HeadersRoot `
	-DeclatationType "enum class" `
	-DeclarationPrefix "UENUM($([String]::Join(", ", $Mods)))" `
	-DeclarationNamePrefix E `
	-IncludeGeneratedHeader `
	-Force: $Force
	
Set-Location $startPath
