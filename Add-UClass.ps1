<#
.SYNOPSIS
Generates a UCLASS based class.

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
	# Name of plugin to generate class for
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
	# UCLASS modifiers like BlueprintType
	[Parameter()]
	[String[]]$Mods = @(),
	# Path to the config
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

function Get-PluginPath([String]$ProjectRoot, [String]$Name)
{
	return "$ProjectRoot/Plugins/$Name/Source/$Name"
}

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

$CppsRootArg = $CppsRoot
$HeadersRootArg = $HeadersRoot

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

$body =
"public:`r`n`t`r`n`t"

$ueIncludes = @("CoreMinimal.h")
$includes = $null

if ($Base.Length -ne 0)
{
	$finalBase = $Base

	if ($BasePath.Length -eq 0)
	{
		switch ($Base)
		{
			"UObject" {}
			"UActorComponent" { $ueIncludes += "Components/ActorComponent.h" }
			"AActor" { $ueIncludes += "GameFramework/Actor.h" }
			default
			{
				$fileName = $Base.Substring(1)
				Resolve-Header "$fileName.h"
			}
		}
	}
	else
	{
		if ($BasePath.StartsWith("UE::"))
		{
			$BasePath = $BasePath.Substring(4)
			$ueIncludes += $BasePath
		}
		else
		{
			$includes += $BasePath
		}
	}
}

if ($finalBase.StartsWith("U")) { $prefix = "U" }
else { $prefix = "A" }

$declPrefix = "UCLASS($([String]::Join(", ", $Mods)))"

& $PSScriptRoot/Add-Cpp.ps1 `
	-Name $Name `
	-Path $Path `
	-CppsRoot $CppsRoot `
	-HeadersRoot $HeadersRoot `
	-DeclatationType class `
	-DeclarationPrefix $declPrefix `
	-DeclarationNamePrefix $prefix `
	-Base "public $finalBase" `
	-UEHeaderIncludes $ueIncludes `
	-HeaderIncludes $includes `
	-BodyContent $body `
	-IncludeGeneratedHeader `
	-UsingUC `
	-UsingUP `
	-UsingUF `
	-GeneratedBody `
	-Force: $Force
