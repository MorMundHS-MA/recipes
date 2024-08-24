$targetDir = "./target/"

Write-Debug "Deleting $targetDir if it exists"
Remove-Item -Recurse -Path $targetDir

New-Item -ItemType Directory $targetDir

$target = Convert-Path -LiteralPath $targetDir
$template = Get-Content "./template.html"

$siteName = "Recipes"


function Generate-Content-Tree {
  param (
    [string]$root,
    [string]$treePath
  )
  
  $contentTree = Join-Path -Path $root -ChildPath $treePath
  $targetTree = Join-Path -Path $target -ChildPath $treePath
  Write-Debug "Generating content from $contentTree"
  
  $null = New-Item -Path $targetTree -ItemType Directory -Force

  $files = Get-ChildItem -Path $contentTree -File
  $directories = Get-ChildItem -Path $contentTree -Directory

  if (($files.Length -gt 0) -and ($directories.Length -gt 0)) {
    throw "$contentTree contains both files *and* directories!"
  }

  $contentListing = @()

  $files | ForEach-Object {
    $contentPath = $_.FullName
    $outPath = Join-Path -Path $targetTree -ChildPath "$($_.BaseName).html"

    Write-Debug "Reading input markdown $contentPath"
    $markdown = Get-Content $_
    $titleMatches = $markdown | Select-String -Pattern '^\s*#\s*([\w\- ]+)\s*$'
    if ($titleMatches.Matches.Success) {
      $title = $titleMatches.Matches.Groups[1].Value
      $markdown = $markdown.Replace($titleMatches.Matches.Groups[0].Value, "$($titleMatches.Matches.Groups[0].Value)`n`n[Zurück](./index.html)")
    }
    else {
      throw "No title found in $contentPath"
    }
    
    Write-Debug "Converting markdown to html"
    $markdownHtml = ($markdown | markdown) -join "`n    "

    $html = $template.replace('$title$', $title).replace('$template$', $markdownHtml) -join "`n"

    $html | Out-File -FilePath $outPath -Encoding utf8

    $contentListing += @{
      "title" = $title
      "path"  = $_.BaseName
      "type"  = "file"
    }
    Write-Host "Generated $outPath from $contentPath"
  }

  $directories | ForEach-Object {
    $nextTree = Join-Path -Path $treePath -ChildPath $_.BaseName
    
    $contentListing += @{
      "title" = $_.BaseName
      "path"  = $nextTree
      "type"  = "directory"
    }
    Generate-Content-Tree -root $root -treePath $nextTree
  }


  if ($treePath -eq ".") {
    $indexTitle = $siteName
  }
  else {
    $indexTitle = "$siteName - $(Split-Path $targetTree -Leaf)"
  }

  $indexMarkdown = "# $indexTitle`n"

  if ($treePath -ne ".") {
    Write-Host $treePath
    $indexMarkdown += "[Zurück](..)`n"
  }

  $contentListing | ForEach-Object {
    if ($_.type -eq "directory") {
      $linkUrl = "$($_.path)/index.html"
    }
    else {
      $linkUrl = "$($_.path).html"
    }
  
    $indexMarkdown += "## [$($_.title)]($linkUrl)`n"
  }

  $indexMarkdownHtml = ($indexMarkdown | markdown) -join "`n    "

  $indexHtml = $template.replace('$title$', $indexTitle).replace('$template$', $indexMarkdownHtml) -join "`n"

  $indexPath = Join-Path -Path $targetTree -ChildPath "index.html"
  $indexHtml | Out-File -FilePath $indexPath -Encoding utf8

  Write-Host "Generated index $indexPath from $treePath"
}

Generate-Content-Tree -root "./content" -treePath "."
