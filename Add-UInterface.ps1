Param(
	[Parameter(Mandatory=$true)][String]$Name,
	[Parameter()][String]$Path = "",
	[Parameter()][String]$CppsRoot = "./Implementations",
	[Parameter()][String]$HeadersRoot = ".",
	[Parameter()][Switch]$Force
)

throw New-Object -TypeName "System.NotImplementedException"

$body =
"public:`r`n`t`r`n`t"

& $PSScriptRoot/Add-Cpp.ps1 `
	-Name $Name `
	-Path $Path `
	-CppsRoot $CppsRoot `
	-HeadersRoot $HeadersRoot `
	-DeclatationType class `
	-DeclarationPrefix "UCLASS()" `
	-DeclarationNamePrefix U `
	-Base "public UObject"`
	-UEHeaderIncludes "CoreMinimal.h" `
	-BodyContent $body `
	-IncludeGeneratedHeader `
	-UsingUC `
	-UsingUP `
	-UsingUF `
	-GeneratedBody `
	-Force: $Force
