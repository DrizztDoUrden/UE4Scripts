Param(
	[Parameter(Mandatory=$true)][String]$Name,
	[Parameter()][String]$Path = "",
	[Parameter()][String]$CppsRoot = "./Implementations",
	[Parameter()][String]$HeadersRoot = ".",
	[Parameter()][String[]]$Mods = @(),
	[Parameter()][Switch]$Force
)

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
