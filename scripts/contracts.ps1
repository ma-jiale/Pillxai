param([switch]$Check)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$version = '7.26.0'
$expectedHash = '1760050094997B9CC790CC1350BE095F15DA8C08A996B184D3EADC4CCDA5E35E'
$jar = Join-Path $projectRoot ".tools/openapi-generator/openapi-generator-cli-$version.jar"
if (-not (Test-Path $jar)) {
    New-Item -ItemType Directory -Force (Split-Path $jar -Parent) | Out-Null
    Invoke-WebRequest "https://repo.maven.apache.org/maven2/org/openapitools/openapi-generator-cli/$version/openapi-generator-cli-$version.jar" -OutFile $jar
}
if ((Get-FileHash $jar -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Generator checksum mismatch.' }
$java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/java.exe' } else { 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe' }
$schemaPath = Join-Path $projectRoot 'contracts/http/openapi.json'
$previousSchemaHash = if (Test-Path $schemaPath) { (Get-FileHash $schemaPath).Hash } else { '' }
& (Join-Path $PSScriptRoot 'backend.ps1') export
if ($LASTEXITCODE -ne 0) { throw 'OpenAPI export failed.' }
if ($Check -and $previousSchemaHash -ne (Get-FileHash $schemaPath).Hash) { throw 'OpenAPI artifact drift: regenerate and review the contract.' }
$target = Join-Path $projectRoot ('.tools/contract-check/' + [Guid]::NewGuid().ToString('N'))
& $java -jar $jar generate -g dart -i (Join-Path $projectRoot 'contracts/http/openapi.json') -c (Join-Path $projectRoot 'contracts/http/generator.json') -t (Join-Path $projectRoot 'contracts/http/templates') -o $target --global-property 'apiTests=false,modelTests=false,apiDocs=false,modelDocs=false'
if ($LASTEXITCODE -ne 0) { throw 'Dart API generation failed.' }
# Generator 7.26 emits a nonexistent DateTime.listFromJson for date arrays.
# Normalize that expression in the generation pipeline, including drift checks.
foreach ($model in Get-ChildItem (Join-Path $target 'lib/model') -Filter '*.dart') {
    $source = [IO.File]::ReadAllText($model.FullName)
    $fixed = [regex]::Replace($source, 'DateTime\.listFromJson\((json\[r''[^'']+''\])\)', {
        param($match)
        '(' + $match.Groups[1].Value + ' as List).map((value) => DateTime.parse(value as String)).toList()'
    })
    # The plan's OpenAPI date array also needs a JSON-serializable date-only list.
    if ($source.Contains('final List<DateTime> dates;')) {
        $fixed = $fixed.Replace("json[r'dates'] = this.dates;", "json[r'dates'] = this.dates.map((value) => value.toIso8601String().substring(0, 10)).toList();")
    }
    if ($fixed -ne $source) { [IO.File]::WriteAllText($model.FullName, $fixed, [Text.UTF8Encoding]::new($false)) }
}
# Generator 7.26 loses the nullable response cast for ParameterView. A new
# prescription legitimately returns JSON null until its parameters are saved.
# Keep this correction in generation so --Check also detects regressions.
$executionApiPath = Join-Path $target 'lib/api/execution_api.dart'
$executionApiSource = [IO.File]::ReadAllText($executionApiPath)
$parameterCast = "deserializeAsync(await _decodeBodyBytes(response), 'ParameterView',) as ParameterView;"
if (-not $executionApiSource.Contains($parameterCast)) { throw 'Review nullable ParameterView normalization after generator changes.' }
$executionApiSource = $executionApiSource.Replace($parameterCast, "deserializeAsync(await _decodeBodyBytes(response), 'ParameterView',) as ParameterView?;")
[IO.File]::WriteAllText($executionApiPath, $executionApiSource, [Text.UTF8Encoding]::new($false))

# This generator emits legacy publishing helpers; they are not part of our SDK.
foreach ($artifact in @('git_push.sh', '.travis.yml')) {
    $artifactPath = Join-Path $target $artifact
    if (Test-Path $artifactPath) { Remove-Item -LiteralPath $artifactPath }
}
$committed = Join-Path $projectRoot 'packages/api_client'
if (-not $Check) {
    # Generate to a fresh directory so removed schemas cannot survive as stale files.
    $generatedLib = [IO.Path]::GetFullPath((Join-Path $committed 'lib'))
    $expectedLib = [IO.Path]::GetFullPath((Join-Path $projectRoot 'packages/api_client/lib'))
    if ($generatedLib -ne $expectedLib -or -not $generatedLib.StartsWith([IO.Path]::GetFullPath($projectRoot) + [IO.Path]::DirectorySeparatorChar)) {
        throw 'Refusing to replace a generated directory outside this project.'
    }
    if (Test-Path $generatedLib) { Remove-Item -LiteralPath $generatedLib -Recurse -Force }
    Copy-Item -LiteralPath (Join-Path $target 'lib') -Destination $generatedLib -Recurse
    foreach ($artifact in @('pubspec.yaml', 'README.md', '.openapi-generator')) {
        $sourceArtifact = Join-Path $target $artifact
        if (Test-Path $sourceArtifact -PathType Leaf) {
            $destinationArtifact = Join-Path $committed $artifact
            if (-not (Test-Path $destinationArtifact) -or (Get-FileHash $sourceArtifact).Hash -ne (Get-FileHash $destinationArtifact).Hash) {
                Copy-Item -LiteralPath $sourceArtifact -Destination $destinationArtifact -Force
            }
        } else {
            Copy-Item -LiteralPath $sourceArtifact -Destination $committed -Recurse -Force
        }
    }
} else {
    $expectedFiles = @(Get-ChildItem (Join-Path $target 'lib') -Recurse -File)
    $actualFiles = @(Get-ChildItem (Join-Path $committed 'lib') -Recurse -File)
    if ($actualFiles.Count -ne $expectedFiles.Count) { throw 'Generated file inventory differs.' }
    foreach ($file in $expectedFiles) {
        $relative = [IO.Path]::GetRelativePath($target, $file.FullName)
        $other = Join-Path $committed $relative
        if (-not (Test-Path $other) -or (Get-FileHash $file.FullName).Hash -ne (Get-FileHash $other).Hash) {
            throw "Generated contract drift: $relative"
        }
    }
    if ((Get-FileHash (Join-Path $target 'pubspec.yaml')).Hash -ne (Get-FileHash (Join-Path $committed 'pubspec.yaml')).Hash) { throw 'Generated pubspec drift.' }
    Write-Output 'Generated Dart contract matches the API schema.'
}
