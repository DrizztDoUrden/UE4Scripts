Param(
	[Parameter(Mandatory=$true)][String]$Name,
	[Parameter()][String]$Path = "",
	[Parameter()][String]$CppsRoot = "./Implementations",
	[Parameter()][String]$HeadersRoot = ".",
	[Parameter()][Switch]$Force
)

& $PSScriptRoot/Add-Cpp.ps1 `
	-Name $Name `
	-Path $Path `
	-CppsRoot $CppsRoot `
	-HeadersRoot $HeadersRoot `
	-DeclatationType struct `
	-DeclarationPrefix "USTRUCT()" `
	-DeclarationNamePrefix F `
	-UEHeaderIncludes "CoreMinimal.h" `
	-IncludeGeneratedHeader `
	-UsingUS `
	-UsingUP `
	-GeneratedBody `
	-Force: $Force
