# UE4Scripts

Requires TabExpansionPlusPlus, but it should get installed automatically, i guess. In case it won't you may do that:

`PS> Install-Module TabExpansionPlusPlus`

## Example for UClass:

To import module:

`PS> Import-Module <path to module>`

To get all available commands:

`Get-Command -Module UE4Tools`

To get help about specific command:

`Get-Help Add-UClass -Detailed`

Should be executed from the source folder of project/plugin

`PS> Add-UClass -Path Abilities -base UAreaAbility -Name CircleAbility`

## How to refresh solution from console:

`PS> <UE4 root>/Engine/Binaries/DotNET/UnrealBuildTool.exe -projectfiles -project="<project root>/SoD4X.uproject" -game -rocket -progress`

or

`PS> Update-Project -EnginePath <UE4 root>`

## Example of config file for plugin.

For project ProjectRoot will likely be `../..`

```
{
  "CppsRoot": "./Private/Implementations",
  "HeadersRoot": "./Public/RPGCore",
  "PrivateHeadersRoot": "./Private",
  "ProjectRoot": "../../../.."
}
```
