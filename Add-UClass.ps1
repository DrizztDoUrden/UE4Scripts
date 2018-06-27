Param(
	[Parameter(Mandatory=$true)][String]$Name,
	[Parameter()][String]$Path = "",
	[Parameter()][String]$CppsRoot = "./Implementations",
	[Parameter()][String]$HeadersRoot = ".",
	[Parameter(ParameterSetName = "Base", Mandatory = $true)][String]$Base = "",
	[Parameter(ParameterSetName = "Base")][String]$BasePath = "",
	[Parameter()][String[]]$Mods = @(),
	[Parameter(ParameterSetName = "Common")][Switch]$Force
)

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
			"UActorComponent" { $ueIncludes += "Components/ActorComponent.h" }
			"AActor" { $ueIncludes += "GameFramework/Actor.h" }
			default
			{
				$fileName = $Base.Substring(1)
				$files = Get-ChildItem -Recurse -File -Filter "$fileName.h" | Resolve-Path -Relative

				if (($files | Measure-Object).Count -eq 1)
				{
					$includes += $files.Substring(2).Replace("\", "/")
				}
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

if ($finalBase -eq $null -or $finalBase.StartsWith("U"))
{
	$prefix = "U"

	if ($finalBase.Length -eq 0)
	{
		$finalBase = "UObject"
	}
}
else
{
	$prefix = "A"
}

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
