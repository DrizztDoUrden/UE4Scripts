Param(
	[Parameter(Mandatory=$true)][String]$Name,
	[Parameter()][String]$Path = "",
	[Parameter()][String]$CppsRoot = "./Implementations",
	[Parameter()][String]$HeadersRoot = ".",
	[Parameter()][Switch]$Force,
	[Parameter()][Switch]$Actor
)

$body =
"public:`r`n`t`r`n`t"

if ($Actor)
{
	$prefix = "A"
	$base = "AActor"
}
else
{
	$prefix = "U"
	$base = "UObject"
}

& $PSScriptRoot/Add-Cpp.ps1 `
	-Name $Name `
	-Path $Path `
	-CppsRoot $CppsRoot `
	-HeadersRoot $HeadersRoot `
	-DeclatationType class `
	-DeclarationPrefix "UCLASS()" `
	-DeclarationNamePrefix $prefix `
	-Base "public $base" `
	-UEHeaderIncludes "CoreMinimal.h" `
	-BodyContent $body `
	-IncludeGeneratedHeader `
	-UsingUC `
	-UsingUP `
	-UsingUF `
	-GeneratedBody `
	-Force: $Force
