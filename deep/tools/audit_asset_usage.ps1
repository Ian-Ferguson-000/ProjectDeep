param(
	[string]$OutputPath = "docs/AssetUsage.md"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $repoRoot "assets"
$resolvedOutput = Join-Path $repoRoot $OutputPath

function Get-RepoPath([string]$Path) {
	return [System.IO.Path]::GetRelativePath($repoRoot, $Path).Replace("\", "/")
}

function Get-TextFiles([string[]]$Roots) {
	$extensions = @(".cfg", ".gd", ".gdshader", ".godot", ".json", ".ps1", ".tres", ".tscn")
	$results = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
	foreach ($root in $Roots) {
		$fullPath = Join-Path $repoRoot $root
		if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
			$results.Add((Get-Item -LiteralPath $fullPath))
		} elseif (Test-Path -LiteralPath $fullPath -PathType Container) {
			Get-ChildItem -LiteralPath $fullPath -File -Recurse |
				Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
				ForEach-Object { $results.Add($_) }
		}
	}
	return $results
}

function Get-AssetReferences([System.IO.FileInfo[]]$Files) {
	$references = [System.Collections.Generic.List[object]]::new()
	$expression = [regex]'["''](?<path>(?:res://)?assets/[^"'']+)["'']'
	foreach ($file in $Files) {
		try { $content = Get-Content -LiteralPath $file.FullName -Raw }
		catch { continue }
		foreach ($match in $expression.Matches($content)) {
			$path = $match.Groups["path"].Value.Replace("\", "/")
			if (-not $path.StartsWith("res://")) { $path = "res://$path" }
			$references.Add([pscustomobject]@{
				Path = $path
				Source = Get-RepoPath $file.FullName
			})
		}
	}
	return $references
}

function Convert-ToAssetPattern([string]$ResourcePath) {
	$relative = $ResourcePath.Substring("res://".Length)
	$escaped = [regex]::Escape($relative)
	# GDScript printf placeholders. Keep each replacement inside one path segment.
	$escaped = $escaped -replace "%[-+0-9.]*[sd]", "[^/]+"
	return "^$escaped`$"
}

function Add-Evidence([hashtable]$Evidence, [string]$AssetPath, [string]$Source) {
	if (-not $Evidence.ContainsKey($AssetPath)) {
		$Evidence[$AssetPath] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	[void]$Evidence[$AssetPath].Add($Source)
}

$assetFiles = Get-ChildItem -LiteralPath $assetRoot -File -Recurse | Where-Object {
	$_.Name -ne ".DS_Store" -and $_.Extension.ToLowerInvariant() -notin @(".import", ".gdignore")
}
$assets = @{}
foreach ($file in $assetFiles) {
	$path = Get-RepoPath $file.FullName
	$assets[$path] = [pscustomobject]@{
		Path = $path
		FullName = $file.FullName
		Bytes = $file.Length
		Status = "Unreferenced"
		Evidence = ""
	}
}

$runtimeFiles = Get-TextFiles @("scripts", "scenes", "data", "project.godot", "export_presets.cfg")
$supportFiles = Get-TextFiles @("tests", "tools")
$runtimeRefs = Get-AssetReferences $runtimeFiles
$supportRefs = Get-AssetReferences $supportFiles
$runtimeEvidence = @{}
$dependencyEvidence = @{}
$patternEvidence = @{}
$directoryEvidence = @{}
$supportEvidence = @{}
$staleRuntimeRefs = [System.Collections.Generic.List[object]]::new()

# Literal runtime paths are roots for dependency traversal.
$dependencyQueue = [System.Collections.Generic.Queue[string]]::new()
foreach ($ref in $runtimeRefs) {
	$assetPath = $ref.Path.Substring("res://".Length)
	if ($ref.Path -match "%[-+0-9.]*[sd]") {
		$pattern = Convert-ToAssetPattern $ref.Path
		foreach ($candidate in $assets.Keys) {
			if ($candidate -match $pattern) { Add-Evidence $patternEvidence $candidate $ref.Source }
		}
	} elseif ($ref.Path.EndsWith("/") -or (Test-Path -LiteralPath (Join-Path $repoRoot $assetPath) -PathType Container)) {
		$assetPrefix = $assetPath.TrimEnd("/") + "/"
		foreach ($candidate in $assets.Keys) {
			if ($candidate.StartsWith($assetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
				Add-Evidence $directoryEvidence $candidate $ref.Source
			}
		}
	} elseif ($assets.ContainsKey($assetPath)) {
		Add-Evidence $runtimeEvidence $assetPath $ref.Source
		$dependencyQueue.Enqueue($assetPath)
	} else {
		$staleRuntimeRefs.Add($ref)
	}
}

# Follow references inside runtime-used text resources (for example SpriteFrames .tres files).
$visitedDependencies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
while ($dependencyQueue.Count -gt 0) {
	$current = $dependencyQueue.Dequeue()
	if (-not $visitedDependencies.Add($current)) { continue }
	$file = $assets[$current]
	if ($file.FullName -notmatch '\.(tres|tscn)$') { continue }
	$nestedRefs = Get-AssetReferences @((Get-Item -LiteralPath $file.FullName))
	foreach ($ref in $nestedRefs) {
		$nestedPath = $ref.Path.Substring("res://".Length)
		if ($assets.ContainsKey($nestedPath)) {
			Add-Evidence $dependencyEvidence $nestedPath $current
			$dependencyQueue.Enqueue($nestedPath)
		}
	}
}

foreach ($ref in $supportRefs) {
	$assetPath = $ref.Path.Substring("res://".Length)
	if ($ref.Path -match "%[-+0-9.]*[sd]") {
		$pattern = Convert-ToAssetPattern $ref.Path
		foreach ($candidate in $assets.Keys) {
			if ($candidate -match $pattern) { Add-Evidence $supportEvidence $candidate $ref.Source }
		}
	} elseif ($ref.Path.EndsWith("/") -or (Test-Path -LiteralPath (Join-Path $repoRoot $assetPath) -PathType Container)) {
		$assetPrefix = $assetPath.TrimEnd("/") + "/"
		foreach ($candidate in $assets.Keys) {
			if ($candidate.StartsWith($assetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
				Add-Evidence $supportEvidence $candidate $ref.Source
			}
		}
	} elseif ($assets.ContainsKey($assetPath)) {
		Add-Evidence $supportEvidence $assetPath $ref.Source
	}
}

foreach ($asset in $assets.Values) {
	if ($runtimeEvidence.ContainsKey($asset.Path)) {
		$asset.Status = "Runtime: direct"
		$asset.Evidence = ($runtimeEvidence[$asset.Path] | Sort-Object) -join "<br>"
	} elseif ($dependencyEvidence.ContainsKey($asset.Path)) {
		$asset.Status = "Runtime: dependency"
		$asset.Evidence = ($dependencyEvidence[$asset.Path] | Sort-Object) -join "<br>"
	} elseif ($patternEvidence.ContainsKey($asset.Path)) {
		$asset.Status = "Runtime: pattern"
		$asset.Evidence = ($patternEvidence[$asset.Path] | Sort-Object) -join "<br>"
	} elseif ($directoryEvidence.ContainsKey($asset.Path)) {
		$asset.Status = "Review: runtime directory"
		$asset.Evidence = ($directoryEvidence[$asset.Path] | Sort-Object) -join "<br>"
	} elseif ($supportEvidence.ContainsKey($asset.Path)) {
		$asset.Status = "Support: test/tool only"
		$asset.Evidence = ($supportEvidence[$asset.Path] | Sort-Object) -join "<br>"
	}
}

$statusOrder = @(
	"Runtime: direct",
	"Runtime: dependency",
	"Runtime: pattern",
	"Review: runtime directory",
	"Support: test/tool only",
	"Unreferenced"
)
$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm zzz"
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Asset Usage Audit")
$lines.Add("")
$lines.Add("> Generated by ``tools/audit_asset_usage.ps1`` on $generatedAt. Do not edit the inventory tables by hand.")
$lines.Add("")
$lines.Add("This audit tracks source files under ``assets/``. Godot ``.import`` sidecars and housekeeping files are excluded because they follow their source asset. Re-run from the repository root with ``./tools/audit_asset_usage.ps1`` after adding, removing, or changing asset references.")
$lines.Add("")
$lines.Add("## How to read this")
$lines.Add("")
$lines.Add("- **Runtime: direct** — named literally by game code, a scene, configuration, or game data.")
$lines.Add("- **Runtime: dependency** — referenced by another runtime-used asset resource.")
$lines.Add("- **Runtime: pattern** — matched by a formatted runtime path such as ``enemies/%s/generated_source.png``.")
$lines.Add("- **Review: runtime directory** — sits below a directory loaded dynamically. It may or may not be selected at runtime, so inspect the loader before deleting it.")
$lines.Add("- **Support: test/tool only** — used for tests or asset-generation tooling, but not directly by the shipped game.")
$lines.Add("- **Unreferenced** — no reference was found. This is the cleanup shortlist, not proof that deletion is safe; editor-only source art and paths assembled from multiple strings can evade static analysis.")
$lines.Add("")
$lines.Add("## Summary")
$lines.Add("")
$lines.Add("| Status | Files | Size |")
$lines.Add("| --- | ---: | ---: |")
foreach ($status in $statusOrder) {
	$members = @($assets.Values | Where-Object Status -eq $status)
	$size = ($members | Measure-Object Bytes -Sum).Sum
	if ($null -eq $size) { $size = 0 }
	$lines.Add("| $status | $($members.Count) | $([math]::Round($size / 1MB, 2)) MiB |")
}
$lines.Add("")
$lines.Add("### By top-level folder")
$lines.Add("")
$lines.Add("| Folder | Total | Runtime | Review | Support only | Unreferenced |")
$lines.Add("| --- | ---: | ---: | ---: | ---: | ---: |")
$folderGroups = $assets.Values | Group-Object { ($_.Path -split "/")[1] } | Sort-Object Name
foreach ($group in $folderGroups) {
	$runtime = @($group.Group | Where-Object { $_.Status.StartsWith("Runtime:") }).Count
	$review = @($group.Group | Where-Object Status -eq "Review: runtime directory").Count
	$support = @($group.Group | Where-Object Status -eq "Support: test/tool only").Count
	$unused = @($group.Group | Where-Object Status -eq "Unreferenced").Count
	$lines.Add("| ``$($group.Name)`` | $($group.Count) | $runtime | $review | $support | $unused |")
}

foreach ($status in $statusOrder) {
	$members = @($assets.Values | Where-Object Status -eq $status | Sort-Object Path)
	$lines.Add("")
	$lines.Add("## $status ($($members.Count))")
	$lines.Add("")
	if ($members.Count -eq 0) {
		$lines.Add("_None._")
		continue
	}
	$lines.Add("| Asset | Reference or loader |")
	$lines.Add("| --- | --- |")
	foreach ($asset in $members) {
		$evidence = if ($asset.Evidence) { $asset.Evidence } else { "—" }
		$lines.Add("| ``$($asset.Path)`` | $evidence |")
	}
}

$uniqueStale = @($staleRuntimeRefs | Sort-Object Path, Source -Unique)
$lines.Add("")
$lines.Add("## Missing runtime references ($($uniqueStale.Count))")
$lines.Add("")
$lines.Add("These literal runtime paths do not currently resolve to an inventoried source asset.")
$lines.Add("")
if ($uniqueStale.Count -eq 0) {
	$lines.Add("_None._")
} else {
	$lines.Add("| Referenced path | Referenced by |")
	$lines.Add("| --- | --- |")
	foreach ($ref in $uniqueStale) {
		$lines.Add("| ``$($ref.Path)`` | $($ref.Source) |")
	}
}
$lines.Add("")
$lines.Add("## Cleanup workflow")
$lines.Add("")
$lines.Add("1. Start with **Unreferenced**, and verify licensing/source obligations before deleting vendor-pack files.")
$lines.Add("2. Inspect **Review: runtime directory** against the named loader; broad directory roots intentionally do not prove per-file use.")
$lines.Add("3. Keep **Support: test/tool only** when reproducible asset generation or tests still matter.")
$lines.Add("4. Delete an asset and its adjacent ``.import`` sidecar together, let Godot rescan, then run the relevant tests/scenes.")
$lines.Add("5. Re-run this audit and confirm the removed path is not listed under **Missing runtime references**.")

$parent = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent) }
[System.IO.File]::WriteAllLines($resolvedOutput, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote $(Get-RepoPath $resolvedOutput) with $($assets.Count) assets."
