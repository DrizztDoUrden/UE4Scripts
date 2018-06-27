# UE4Scripts
Example for UClass:
```
#From Source folder of project/plugin
PS> Add-UClass.ps1 -CppsRoot .\Private\Implementations\ -HeadersRoot .\Public\RPGCore\ -Path Abilities -base UAreaAbility -Name CircleAbility
```
How to refresh solution from console:
```
PS> <Path to UE4 root>/Engine/Binaries/DotNET/UnrealBuildTool.exe -projectfiles -project="<Path to project root>/SoD4X.uproject" -game -rocket -progress
```
