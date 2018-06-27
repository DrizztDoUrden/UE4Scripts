# UE4Scripts
Example for UClass:
```
PS> Add-UClass.ps1 -CppsRoot .\Private\Implementations\ -HeadersRoot .\Public\RPGCore\ -Path Abilities -base UAreaAbility -Name CircleAbility
```
How to refresh solution from console:
```
<Path to UE4 root>/Engine/Binaries/DotNET/UnrealBuildTool.exe -projectfiles -project="<Path to project root>/SoD4X.uproject" -game -rocket -progress
```
