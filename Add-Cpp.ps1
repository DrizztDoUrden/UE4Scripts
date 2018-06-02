Param(
	[Parameter(Mandatory=$true)][String]$Name,
	[Parameter(Mandatory=$true)][String][AllowEmptyString()]$Path,
	[Parameter(Mandatory=$true)][String]$CppsRoot,
	[Parameter(Mandatory=$true)][String]$HeadersRoot,
	[Parameter(Mandatory=$true)][String]$DeclatationType,
	[Parameter()][String]$DeclarationPrefix,
	[Parameter()][String]$DeclarationNamePrefix,
	[Parameter()][String]$Base,
	[Parameter()][String]$BodyContent,
	[Parameter()][String[]]$HeaderIncludes,
	[Parameter()][String[]]$UEHeaderIncludes,
	[Parameter()][String[]]$CPPHeaderIncludes,
	[Parameter()][Switch]$IncludeGeneratedHeader,
	[Parameter()][Switch]$UsingUC,
	[Parameter()][Switch]$UsingUS,
	[Parameter()][Switch]$UsingUI,
	[Parameter()][Switch]$UsingUF,
	[Parameter()][Switch]$UsingUP,
	[Parameter()][Switch]$GeneratedBody,
	[Parameter()][Switch]$Force
)

$HeaderPath = "$HeadersRoot/$Path/$Name.h"
$CppPath = "$CppsRoot/$Path/$Name.cpp"

if (-not $(Test-Path $HeaderPath))
{
	New-Item -Force $HeaderPath;
}
else
{
	if (-not $Force)
	{
		throw "Header with such name already exists ($($HeaderPath | Resolve-Path -Relative))"
	}
}

if (-not $(Test-Path $CppPath))
{
	New-Item -Force $CppPath;
}
else
{
	if (-not $Force)
	{
		throw "Cpp with such name already existsc ($($CppPath | Resolve-Path -Relative))"
	}
}

$HeaderPath = ($HeaderPath | Resolve-Path -Relative).Replace("\", "/").Substring(2)
$CppPath = ($CppPath | Resolve-Path -Relative).Replace("\", "/").Substring(2)

$HeaderIncludesStr = ""

foreach ($header in $HeaderIncludes)
{
	$HeaderIncludesStr += "`r`n#include <$header>";
}

if ($HeaderIncludesStr.Length -gt 0 -and $UEHeaderIncludes.Count -gt 0)
{
	$HeaderIncludesStr += "`r`n"
}

foreach ($header in $UEHeaderIncludes)
{
	$HeaderIncludesStr += "`r`n#include <$header>";
}

if ($HeaderIncludesStr.Length -gt 0 -and $CPPHeaderIncludes.Count -gt 0)
{
	$HeaderIncludesStr += "`r`n"
}

foreach ($header in $CPPHeaderIncludes)
{
	$HeaderIncludesStr += "`r`n#include <$header>";
}

if ($IncludeGeneratedHeader)
{
	if ($HeaderIncludesStr.Length -gt 0)
	{
		$HeaderIncludesStr += "`r`n"
	}

	$HeaderIncludesStr += "`r`n#include `"$Name.generated.h`""
}

function UsingNamespace([Bool]$Condition, [String]$Name)
{
	if ($Condition)
	{
		"`r`nusing namespace $Name;"
	}
	else
	{
		""
	}
}

if ($HeaderIncludesStr.Length -gt 0)
{
	$HeaderIncludesStr = "`r`n$HeaderIncludesStr"
}

$HeaderUsingNamespaces =
	$(UsingNamespace $UsingUC "UC") +
	$(UsingNamespace $UsingUS "US") +
	$(UsingNamespace $UsingUI "UI") +
	$(UsingNamespace $UsingUF "UF") +
	$(UsingNamespace $UsingUP "UP")
	
if ($HeaderUsingNamespaces.Length -gt 0)
{
	$HeaderUsingNamespaces = "`r`n$HeaderUsingNamespaces"
}

if ($DeclarationPrefix.Length -gt 0)
{
	$DeclarationPrefix = "$DeclarationPrefix`r`n"
}

if ($GeneratedBody)
{
	if ($BodyContent.Length -gt 0)
	{
		$BodyContent = "`r`n$BodyContent"
	}

	$BodyContent = "GENERATED_BODY()`r`n$BodyContent"
}

if ($Base.Length -gt 0)
{
	$Base = " : $Base"
}

$HeaderContent =
"#pragma once$HeaderIncludesStr$HeaderUsingNamespaces

$DeclarationPrefix$DeclatationType $DeclarationNamePrefix$Name$Base
{
	$BodyContent
};"

$CppContent =
"#include <$HeaderPath>
"

Set-Content $HeaderPath $HeaderContent;
Set-Content $CppPath $CppContent;
