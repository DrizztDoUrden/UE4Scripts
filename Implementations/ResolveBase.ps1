. "$PSScriptRoot/Implementations/ResolveHeader.ps1"

if ($Base.Length -ne 0)
{
	$finalBase = $Base

	if ($BasePath.Length -eq 0)
	{
		switch ($Base)
		{
			"UObject"
			{
				Write-Verbose "Using UObject as base"
			}
			"UActorComponent"
			{
				Write-Verbose "Using UActorComponent as base"
				$ueIncludes += "Components/ActorComponent.h"
			}
			"AActor"
			{
				Write-Verbose "Using AActor as base"
				$ueIncludes += "GameFramework/Actor.h"
			}
			default
			{
				$fileName = $Base.Substring(1)
				Resolve-Header "$fileName.h"
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
