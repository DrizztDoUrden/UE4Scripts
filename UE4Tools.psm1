function Add-Prefix(
	[String]$prefix,
	[Parameter(ValueFromPipeline=$true)]
	[String]$base)
{
	process { "$prefix $base" }
}

class CppTypeDeclaration
{
	[String]$declarationType
	[String]$Name
	[String[]]$bases
	[String]$prefix
	[Bool]$generatedBody
	[String]$body

	[String]Generate()
	{
		$declStr = ""
		if ($this.prefix.Length -gt 0) { $declStr += "$($this.prefix)`r`n" }
		$declStr += "$($this.declarationType) $($this.Name)"
		if ($this.bases.Length -gt 0) { $declStr += " : $([String]::Join(',', ($this.bases | Add-Prefix 'public')))" }
		$declStr += "`r`n{"
		if ($this.generatedBody) { $declStr += "`r`nGENERATED_BODY()`r`n" }
		if ($this.body.Length -gt 0) { $declStr += "`r`n$($this.body)" }
		$declStr += "`r`n}"

		return $declStr
	}
}

class CppFile
{
	[String[]]$includes
	[String[]]$ueIncludes
	[String[]]$stdIncludes
	[String]$generatedInclude
	[String[]]$usingNamespaces
	[CppTypeDeclaration[]]$declarations

	[String]GenerateHeadersSection([String[]]$headers, [Bool]$first)
	{
		$body = ""
		if ($headers.Length -gt 0 -and -not $first) { $body += "`r`n" }

		foreach ($header in ($headers | Sort-Object))
		{
			if (-not $first) { $body += "`r`n" }
			$body += "#include <$header>"
			$first = $false
		}

		return $body
	}

	[String]GenerateHeaders([Bool]$first)
	{
		$body = $this.GenerateHeadersSection($this.includes, $first)
		$body += $this.GenerateHeadersSection($this.ueIncludes, $first -and $body.Length -eq 0)
		$body += $this.GenerateHeadersSection($this.stdIncludes, $first -and $body.Length -eq 0)

		if ($this.generatedInclude.Length -gt 0)
		{
			if (-not ($first -and $body.Length -eq 0)) { $body += "`r`n`r`n" }
			$body += "#include `"$($this.generatedInclude)`""
		}

		return $body
	}

	[String]GenerateUsings([Bool]$first)
	{
		$body = ""
		if ($this.usingNamespaces.Length -gt 0 -and -not $first) { $body += "`r`n" }

		foreach ($using in $this.usingNamespaces)
		{
			if (-not $first) { $body += "`r`n" }
			$body += "using namespace $using;"
			$first = $false
		}

		return $body
	}

	[String]Generate([Bool]$IsHeader)
	{
		$body = ""
		if ($IsHeader) { $body += "#pragma once" }
		$body += $this.GenerateHeaders($body.Length -eq 0)
		$body += $this.GenerateUsings($body.Length -eq 0)

		foreach ($declaration in $this.declarations)
		{
			if ($body.Length -gt 0) { $body += "`r`n`r`n" }
			$body += $declaration.Generate() + ";"
		}

		$body += "`r`n"
		return $body
	}
}

class UE4CfgFile
{
	[String]$privateHeaders
	[String]$headers
	[String]$cpps
	[String]$root
	[String]$location
	[String]$filename

	UE4CfgFile([String]$path)
	{
		$sep = $path.LastIndexOf('/');
		$found = Test-Path $path -PathType Leaf
		$this.location = if ($sep -ge 0) { $path.Substring(0, $sep) } else { "." }
		$this.filename = if ($sep -ge 0) { $path.Substring($sep + 1) } else { $path }

		if (-not $found -and ((Test-Path -PathType Leaf "$($this.location)/*.uproject") -or (Test-Path -PathType Leaf "$($this.location)/*.uplugin")))
		{
			$this.location = "$($this.location)/Source/$((Get-Item ($this.location)).Name)"
			$found = Test-Path "$($this.location)/$($this.filename)" -PathType Leaf
		}

		if ($found)
		{
			$path = "$($this.location)/$($this.filename)";
			Write-Verbose "Parsing config at <$(Resolve-Path $path -Relative)>..."
			$file = (Get-Content "$path") -join "`r`n" | ConvertFrom-Json
			$this.cpps = $file.CppsRoot
			$this.headers = $file.HeadersRoot
			$this.privateHeaders = $file.PrivateHeadersRoot
			$this.root = $file.ProjectRoot
		}
		else
		{
			Write-Verbose "Config not found."
			$this.cpps = "."
			$this.headers = "."
			$this.privateHeaders = "."
			$this.root = "../.."
		}
	}

	[void]Save()
	{
		@{
			CppsRoot = $this.cpps;
			HeadersRoot = $this.headers;
			PrivateHeadersRoot = $this.privateHeaders;
			ProjectRoot = $this.root;
		} | ConvertTo-Json | Out-File "$($this.location)/$($this.filename)"
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
		Write-Verbose "Resolved <$headerPath>"
		return $headerPath
	}

	return ""
}

function TryResolve([String]$FileName, [String]$Path, [UE4CfgFile]$cfg, [Bool]$IncludePrivate = $false)
{
	if ($IncludePrivate -and ($cfg.privateHeaders.Length -gt 0) -and ($cfg.privateHeaders -ne $cfg.headers))
	{
		$resolved = TryResolveFromDirectory $FileName $Path/$($cfg.privateHeaders) $Path.Length
		if ($resolved.Length -gt 0) { return $resolved }
	}

	return TryResolveFromDirectory $FileName $Path/$($cfg.headers) $Path.Length
}

function Resolve-Header([String]$FileName, [UE4CfgFile]$cfg, [String]$Plugin)
{
	$path = TryResolve $fileName $cfg.location $cfg $true
	$root = "$($cfg.location)/$($cfg.root)" | Resolve-Path -Relative

	if ($path.Length -eq 0)
	{
		foreach ($pluginSearched in (Get-ChildItem "$root/Plugins"))
		{
			$pluginPath = $(Get-PluginPath $root $pluginSearched) | Resolve-Path -Relative
			if ($Plugin -eq $pluginSearched -or -not (Test-Path -PathType Leaf $pluginPath/uesp.json)) { continue }
			$path = TryResolve $fileName $pluginPath ([UE4CfgFile]::New("$pluginPath/uesp.json"))
			if ($path.Length -gt 0) { return $path }
		}

		if ($Plugin.ToLower() -ne "root")
		{
			$rootSourcePath = "$root/Source/$((Get-Item $root).Name)" | Resolve-Path -Relative
			if (-not (Test-Path -PathType Leaf "$rootSourcePath/uesp.json")) { continue }
			return TryResolve $fileName $rootSourcePath ([UE4CfgFile]::New("$rootSourcePath/uesp.json"))
		}
	}

	return $path
}

function PluginLocation([String]$Plugin, [UE4CfgFile]$cfg)
{
	if ($Plugin.Length -gt 0)
	{
		if ($Plugin.ToLower() -eq "root")
		{
			$pluginRoot = "$($cfg.location)/$($cfg.root)"
		}
		else
		{
			$pluginRoot = "$($cfg.location)/$($cfg.root)/Plugins/$Plugin"
			if (-not (Test-Path -PathType Container $pluginRoot)) { throw "Plugin <$Plugin> not found at <$pluginRoot>" }
		}

		return "$pluginRoot/Source/$((Get-Item $pluginRoot).Name)"
	}

	return ""
}

function Get-HeaderPath([UE4CfgFile]$cfg, [String]$HeadersRoot, [Bool]$Private)
{
	if ($HeadersRoot.Length -eq 0)
	{
		if ($Private) { $HeadersRoot = Resolve-Path -Relative "$($cfg.location)/$($cfg.privateHeaders)" }
		else { $HeadersRoot = Resolve-Path -Relative "$($cfg.location)/$($cfg.headers)" }
	}

	Write-Verbose "Headers root: $HeadersRoot"
	"$HeadersRoot/$Path/$Name.h"
}

function Get-CppPath([UE4CfgFile]$cfg, [String]$CppsRoot)
{
	if ($CppsRoot.Length -eq 0) { $CppsRoot = Resolve-Path -Relative "$($cfg.location)/$($cfg.cpps)" }
	Write-Verbose "CPPs root: $CppsRoot"
	"$CppsRoot/$Path/$Name.cpp"
}

function Generate-File([String]$Content, [String]$Path, [Bool]$WhatIf)
{
	Write-Verbose ">>>>>>>>>> File start ($Path):`r`n$Content`r`n>>>>>>>>>> File end."
	New-Item -Force $Path -Value $Content -WhatIf:$WhatIf
}

function Make-DefaultCpp([String]$Path, [String]$Name)
{
	$cpp = [CppFile]::New()
	$cpp.includes = if ($Path.Length -gt 0 -and $Path -ne "." -and $Path -ne "./") { @("$Path/$Name.h") } else { @("$Name.h")}
	$cpp
}

$PluginCompletion = {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

	$ConfigPath = $fakeBoundParameter.ConfigPath
	if ($ConfigPath.Length -eq 0) { $ConfigPath = "uesp.json" }

	$suggestions = @("root")
	$cfg = [UE4CfgFile]::New($ConfigPath)
	foreach ($plugin in (Get-ChildItem "$($cfg.location)/$($cfg.root)/Plugins")) { $suggestions += $plugin }
	$suggestions | ? { $_ -like "$wordToComplete*" } | Sort-Object | % { New-CompletionResult -CompletionText $_ }
}

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
function Set-Plugin(
	# Name of plugin to switch to. Root means switch to project root
	[Parameter(Mandatory = $true)]
	[String]$Plugin = "",
	# Path to the config. Should be relative to cwd or to cwd/Source/$(cwd name). Should be a JSON object with fields CppsRoot, HeadersRoot, PrivateHeadersRoot, ProjectRoot
	[Parameter()]
	[String]$ConfigPath = "uesp.json"
)
{
	$cfg = [UE4CfgFile]::New($ConfigPath)
	$pluginPath = PluginLocation $Plugin $cfg
	if ($pluginPath.Length -gt 0) { Set-Location $pluginPath }
}

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
function Add-Class
{
	[CmdletBinding()]
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
		[String]$Base = "",
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
		[Parameter()]
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
		[String]$BasePath = "",
		[Switch]$WhatIf
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		$headerPath = Get-HeaderPath -cfg $cfg -HeadersRoot $HeadersRoot -Private $Private
		$cppPath = Get-CppPath -cfg $cfg -CppsRoot $CppsRoot
		$root = Resolve-Path -Relative "$($cfg.location)/$($cfg.root)"
		Write-Verbose "Project root: $root"

		$header = [CppFile]::New()
		$decl = [CppTypeDeclaration]::New()

		$header.ueIncludes = @("CoreMinimal.h")
		$header.includes = @()
		$header.declarations = @($decl)

		if ($Base.Length -gt 0)
		{
			$decl.bases += $Base
			if ($BasePath.Length -eq 0) { $BasePath = Resolve-Header "$Base.h" $cfg $Plugin }
			if ($BasePath.Length -gt 0) { $header.includes += $BasePath }
			else { Write-Warning "Base not found: $Base" }
		}

		$decl.body = "public:`r`n`t`r`n`t"
		$decl.declarationType = "class"
		$decl.Name = $Name

		$cpp = Make-DefaultCpp -Path $Path -Name $Name
		Generate-File -Content $header.Generate($true) -Path $headerPath -WhatIf $WhatIf
		Generate-File -Content $cpp.Generate($false) -Path $cppPath -WhatIf $WhatIf
	}
}

<#
.SYNOPSIS
Generates a struct.

.DESCRIPTION
Supports usage of configuration files for saving some parameter values. It should be placed to source root with name uesp.json for full support. Cfg file format:
{
  "CppsRoot": "<path to implementations>",
  "HeadersRoot": "<path to public headers>",
  "PrivateHeadersRoot": "<path to private headers>",
  "ProjectRoot": "<path to the project root for header search and plugin system>"
}
#>
function Add-Struct
{
	[CmdletBinding()]
	Param(
		# Name of the struct generated
		[Parameter(Mandatory=$true)]
		[String]$Name,
		# Name of plugin to generate struct for. Root means project root
		[Parameter(ParameterSetName = "Plugin", Mandatory = $true)]
		[String]$Plugin = "",
		# Relative path to the struct header and implementation
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
		[Parameter()]
		[Switch]$Private,
		# Force the override of existing files
		[Parameter(ParameterSetName = "Common")]
		[Parameter(ParameterSetName = "Plugin")]
		[Switch]$Force,
		[Switch]$WhatIf
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		$headerPath = Get-HeaderPath -cfg $cfg -HeadersRoot $HeadersRoot -Private $Private
		$cppPath = Get-CppPath -cfg $cfg -CppsRoot $CppsRoot
		$root = Resolve-Path -Relative "$($cfg.location)/$($cfg.root)"
		Write-Verbose "Project root: $root"

		$header = [CppFile]::New()
		$decl = [CppTypeDeclaration]::New()

		$header.ueIncludes = @("CoreMinimal.h")
		$header.includes = @()
		$header.declarations = @($decl)

		$decl.body = "public:`r`n`t`r`n`t"
		$decl.declarationType = "struct"
		$decl.Name = $Name
		
		$cpp = Make-DefaultCpp -Path $Path -Name $Name
		Generate-File -Content $header.Generate($true) -Path $headerPath -WhatIf $WhatIf
		Generate-File -Content $cpp.Generate($false) -Path $cppPath -WhatIf $WhatIf
	}
}

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
function Add-UEnum
{
	[CmdletBinding()]
	Param(
		# Name of the enum generated
		[Parameter(Mandatory=$true)]
		[String]$Name,
		# Name of plugin to generate enum for. Root means project root
		[Parameter(ParameterSetName = "Plugin", Mandatory = $true)]
		[String]$Plugin = "",
		# Relative path to the enum header and implementation
		[Parameter()]
		[String]$Path = "",
		# Modifiers like BlueprintType
		[Parameter()]
		[String[]]$Mods = @(),
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
		[Parameter()]
		[Switch]$Private,
		# Force the override of existing files
		[Parameter(ParameterSetName = "Common")]
		[Parameter(ParameterSetName = "Plugin")]
		[Switch]$Force,
		[Switch]$WhatIf
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		$headerPath = Get-HeaderPath -cfg $cfg -HeadersRoot $HeadersRoot -Private $Private
		$cppPath = Get-CppPath -cfg $cfg -CppsRoot $CppsRoot
		$root = Resolve-Path -Relative "$($cfg.location)/$($cfg.root)"
		Write-Verbose "Project root: $root"

		$header = [CppFile]::New()
		$decl = [CppTypeDeclaration]::New()

		$header.ueIncludes = @("ObjectMacros.h")
		$header.includes = @()
		$header.generatedInclude = "$Name.generated.h"
		$header.declarations = @($decl)

		$decl.prefix = "UENUM($([String]::Join(", ", $Mods)))"
		$decl.declarationType = "enum class"
		$decl.Name = "E$Name"
		
		$cpp = Make-DefaultCpp -Path $Path -Name $Name
		Generate-File -Content $header.Generate($true) -Path $headerPath -WhatIf $WhatIf
		Generate-File -Content $cpp.Generate($false) -Path $cppPath -WhatIf $WhatIf
	}
}

<#
.SYNOPSIS
Generates a USTRUCT based struct.

.DESCRIPTION
Supports usage of configuration files for saving some parameter values. It should be placed to source root with name uesp.json for full support. Cfg file format:
{
  "CppsRoot": "<path to implementations>",
  "HeadersRoot": "<path to public headers>",
  "PrivateHeadersRoot": "<path to private headers>",
  "ProjectRoot": "<path to the project root for header search and plugin system>"
}
#>
function Add-UStruct
{
	[CmdletBinding()]
	Param(
		# Name of the struct generated
		[Parameter(Mandatory=$true)]
		[String]$Name,
		# Name of plugin to generate struct for. Root means project root
		[Parameter(ParameterSetName = "Plugin", Mandatory = $true)]
		[String]$Plugin = "",
		# Relative path to the struct header and implementation
		[Parameter()]
		[String]$Path = "",
		# Modifiers like BlueprintType
		[Parameter()]
		[ValidateSet("NoExport", "Atomic", "Immutable", "BlueprintType", "BlueprintInternalUseOnly")]
		[String[]]$Mods = @(),
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
		[Parameter()]
		[Switch]$Private,
		# Force the override of existing files
		[Parameter(ParameterSetName = "Common")]
		[Parameter(ParameterSetName = "Plugin")]
		[Switch]$Force,
		[Switch]$WhatIf
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		$headerPath = Get-HeaderPath -cfg $cfg -HeadersRoot $HeadersRoot -Private $Private
		$cppPath = Get-CppPath -cfg $cfg -CppsRoot $CppsRoot
		$root = Resolve-Path -Relative "$($cfg.location)/$($cfg.root)"
		Write-Verbose "Project root: $root"

		$header = [CppFile]::New()
		$decl = [CppTypeDeclaration]::New()

		$header.ueIncludes = @("CoreMinimal.h", "ObjectMacros.h")
		$header.includes = @()
		$header.generatedInclude = "$Name.generated.h"
		$header.declarations = @($decl)
		$header.usingNamespaces = @("US", "UP", "UM")

		$decl.prefix = "USTRUCT($([String]::Join(", ", $Mods)))"
		$decl.declarationType = "struct"
		$decl.Name = "F$Name"
		$decl.body = "    GENERATED_BODY()`r`n`r`n"

		$cpp = Make-DefaultCpp -Path $Path -Name $Name
		Generate-File -Content $header.Generate($true) -Path $headerPath -WhatIf $WhatIf
		Generate-File -Content $cpp.Generate($false) -Path $cppPath -WhatIf $WhatIf
	}
}

<#
.SYNOPSIS
Generates a UINTERFACE based class.

.DESCRIPTION
Supports usage of configuration files for saving some parameter values. It should be placed to source root with name uesp.json for full support. Cfg file format:
{
  "CppsRoot": "<path to implementations>",
  "HeadersRoot": "<path to public headers>",
  "PrivateHeadersRoot": "<path to private headers>",
  "ProjectRoot": "<path to the project root for header search and plugin system>"
}
#>
function Add-UInterface
{
	[CmdletBinding()]
	Param(
		# Name of the class generated
		[Parameter(Mandatory=$true)]
		[String]$Name,
		# Name of plugin to generate class for. Root means project root
		[Parameter(ParameterSetName = "Plugin", Mandatory = $true)]
		[String]$Plugin = "",
		# Relative path to the class header and implementation
		[Parameter()]
		[String]$Path = "",
		# Modifiers like BlueprintType
		[Parameter()]
		[ValidateSet("MinimalAPI", "Blueprintable", "NotBlueprintable", "ConversionRoot")]
		[String[]]$Mods = @(),
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
		[Parameter()]
		[Switch]$Private,
		# Force the override of existing files
		[Parameter(ParameterSetName = "Common")]
		[Parameter(ParameterSetName = "Plugin")]
		[Switch]$Force,
		[Switch]$WhatIf
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		$headerPath = Get-HeaderPath -cfg $cfg -HeadersRoot $HeadersRoot -Private $Private
		$cppPath = Get-CppPath -cfg $cfg -CppsRoot $CppsRoot
		$root = Resolve-Path -Relative "$($cfg.location)/$($cfg.root)"
		Write-Verbose "Project root: $root"

		$header = [CppFile]::New()
		$udecl = [CppTypeDeclaration]::New()
		$idecl = [CppTypeDeclaration]::New()

		$header.ueIncludes = @("CoreMinimal.h", "ObjectMacros.h")
		$header.includes = @()
		$header.generatedInclude = "$Name.generated.h"
		$header.declarations = @($udecl, $idecl)
		$header.usingNamespaces = @("UI", "UF", "UM")

		$udecl.prefix = "UINTERFACE($([String]::Join(", ", $Mods)))"
		$udecl.declarationType = "class"
		$udecl.Name = "U$Name"
		$udecl.bases = @("UInterface")
		$udecl.body = "    GENERATED_BODY()"

		$idecl.Name = "I$Name"
		$idecl.body = "    GENERATED_BODY()`r`n`r`npublic:`r`n`r`n"
		$idecl.declarationType = "class"

		$cpp = Make-DefaultCpp -Path $Path -Name $Name
		Generate-File -Content $header.Generate($true) -Path $headerPath -WhatIf $WhatIf
		Generate-File -Content $cpp.Generate($false) -Path $cppPath -WhatIf $WhatIf
	}
}


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
function Add-UClass
{
	[CmdletBinding()]
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
		# Modifiers like BlueprintType
		[Parameter()]
		[ValidateSet("classGroup", "Within", "BlueprintType", "NotBlueprintType", "Blueprintable", "NotBlueprintable", "MinimalAPI", "customConstructor", "Intrinsic",
			"noexport", "placeable", "notplaceable", "DefaultToInstanced", "Const", "Abstract", "deprecated", "Transient", "nonTransient", "config",  "perObjectConfig",
			"configdonotcheckdefaults", "defaultconfig", "editinlinenew", "noteditinlinenew", "hidedropdown", "showCategories", "hideCategories", "ComponentWrapperClass",
			"showFunctions", "hideFunctions", "autoExpandCategories", "autoCollapseCategories", "dontAutoCollapseCategories", "collapseCategories", "dontCollapseCategories",
			"AdvancedClassDisplay", "ConversionRoot", "Experimental", "EarlyAccessPreview")]
		[String[]]$Mods = @(),
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
		[Parameter()]
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
		[String]$BasePath = "",
		[Switch]$WhatIf
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		$headerPath = Get-HeaderPath -cfg $cfg -HeadersRoot $HeadersRoot -Private $Private
		$cppPath = Get-CppPath -cfg $cfg -CppsRoot $CppsRoot
		$root = Resolve-Path -Relative "$($cfg.location)/$($cfg.root)"
		Write-Verbose "Project root: $root"

		$header = [CppFile]::New()
		$decl = [CppTypeDeclaration]::New()

		$header.ueIncludes = @("CoreMinimal.h")
		$header.includes = @()
		$header.declarations = @($decl)
		$header.usingNamespaces = @("UC", "UP", "UF", "UM")
		$header.generatedInclude = "$Name.generated.h"

		$namePrefix = $Base[0]
		$decl.bases += $Base

		if ($BasePath.Length -eq 0)
		{
			switch ($Base)
			{
				"UObject" {}
				"AActor" { $header.ueIncludes += "GameplayFramework/Actor.h" }
				"UActorComponent" { $header.ueIncludes += "Components/ActorComponent.h" }
				default
				{
					$BasePath = Resolve-Header "$($Base.Substring(1)).h" $cfg $Plugin
					if ($BasePath.Length -eq 0) { Write-Warning "Base not found: $Base" }
					else { $header.includes += $BasePath }
				}
			}
		}
		else { $header.includes += $BasePath }
		
		$decl.prefix = "UCLASS($([String]::Join(", ", $Mods)))"
		$decl.body = "    GENERATED_BODY()`r`n`r`npublic:`r`n`r`n"
		$decl.declarationType = "class"
		$decl.Name = "$namePrefix$Name"

		$cpp = Make-DefaultCpp -Path $Path -Name $Name
		Generate-File -Content $header.Generate($true) -Path $headerPath -WhatIf $WhatIf
		Generate-File -Content $cpp.Generate($false) -Path $cppPath -WhatIf $WhatIf
	}
}

<#
.SYNOPSIS
Updates configuration file

.DESCRIPTION
Supports usage of configuration files for saving some parameter values. It should be placed to source root with name uesp.json for full support. Cfg file format:
{
  "CppsRoot": "<path to implementations>",
  "HeadersRoot": "<path to public headers>",
  "PrivateHeadersRoot": "<path to private headers>",
  "ProjectRoot": "<path to the project root for header search and plugin system>"
}
#>
function Update-Config
{
	[CmdletBinding()]
	Param(
		# Name of plugin to generate class for. Root means project root
		[Parameter(ParameterSetName = "Plugin", Mandatory = $true)]
		[String]$Plugin = "",
		# Path to the config. Should be relative to cwd or to cwd/Source/$(cwd name). Should be a JSON object with fields CppsRoot, HeadersRoot, PrivateHeadersRoot, ProjectRoot
		[Parameter()]
		[String]$ConfigPath = "uesp.json",
		[Parameter()]
		[String]$CppsRoot,
		[Parameter()]
		[String]$PublicHeaders,
		[Parameter()]
		[String]$PrivateHeaders,
		[Parameter()]
		[String]$Root
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$pluginPath = PluginLocation $Plugin $cfg
		if ($pluginPath.Length -gt 0)
		{
			$ConfigPath = "$pluginPath/$ConfigPath"
			$cfg = [UE4CfgFile]::New($ConfigPath)
		}

		if ($CppsRoot.Length -gt 0) { $cfg.cpps = $CppsRoot }
		if ($PublicHeaders.Length -gt 0) { $cfg.headers = $PublicHeaders }
		if ($PrivateHeaders.Length -gt 0) { $cfg.privateHeaders = $PrivateHeaders }
		if ($Root.Length -gt 0) { $cfg.root = $Root }

		$cfg.Save()
	}
}

<#
.SYNOPSIS
Updates project file if it doesn't have include paths to .generated.h files.

.DESCRIPTION
Supports usage of configuration files for saving some parameter values. It should be placed to source root with name uesp.json for full support. Cfg file format:
{
  "CppsRoot": "<path to implementations>",
  "HeadersRoot": "<path to public headers>",
  "PrivateHeadersRoot": "<path to private headers>",
  "ProjectRoot": "<path to the project root for header search and plugin system>"
}
#>
function Update-ProjectIncludes
{
	[CmdletBinding()]
	Param(
		# Path to the config. Should be relative to cwd or to cwd/Source/$(cwd name). Should be a JSON object with fields CppsRoot, HeadersRoot, PrivateHeadersRoot, ProjectRoot
		[Parameter()]
		[String]$ConfigPath = "uesp.json",
		# Name of the project file. Defaults to project root folder name.
		[Parameter()]
		[String]$ProjectName
	)
	begin
	{
		$cfg = [UE4CfgFile]::New($ConfigPath)
		$root = "$($cfg.location)/$($cfg.root)"
		$plugins = Get-ChildItem "$root/Plugins"

		if ($ProjectName.Length -eq 0) { $ProjectName = (Get-Item $root).BaseName }

		$ProjectFileName = Resolve-Path "$root/Intermediate/ProjectFiles/$ProjectName.vcxproj"
		[xml]$projectFile = Get-Content $ProjectFileName

		foreach ($propertyGroup in $projectFile.Project.PropertyGroup)
		{
			if ($propertyGroup.NMakeIncludeSearchPath.Length -eq 0) { continue }

			if (-not $propertyGroup.NMakeIncludeSearchPath.Contains("../Build/Win64/UE4/Inc/$ProjectName"))
			{
				$propertyGroup.NMakeIncludeSearchPath += ";../Build/Win64/UE4/Inc/$ProjectName"
			}

			foreach ($plugin in $plugins)
			{
				if (-not $propertyGroup.NMakeIncludeSearchPath.Contains("../../Plugins/$plugin/Build/Win64/UE4/Inc/$plugin"))
				{
					$propertyGroup.NMakeIncludeSearchPath += ";../../Plugins/$plugin/Build/Win64/UE4/Inc/$plugin"
				}
			}
		}

		$projectFile.Save($ProjectFileName)
	}
}

foreach ($export in @("Set-Plugin", "Add-Class", "Add-Struct", "Add-UEnum", "Add-UStruct", "Add-UInterface", "Add-UClass",  "Update-Config", "Update-ProjectIncludes"))
{
	Export-ModuleMember -Function $export
	Register-ArgumentCompleter -CommandName $export -ParameterName Plugin -ScriptBlock $PluginCompletion
}
