#!/bin/bash

function usage() {
    echo "Usage: $0 <author_name/author_email> <output_directory_name> [max_file_size_kb]"
    exit 1
}

function commitDirName() {
    local commitHash="$1"
    local commitDate=$(git show -s --format%cd --date=format:%Y-%m-%d "$commitHash")
    local commitMsg=$(git show -s --format%s "$commitHash")
    local commitType=$(echo "$commitMsg" | grep -o -E '^(fix|feat|chore):' | tr '[:upper:]' '[:lower:]' || echo "fix:")
    # custom name generations
    local commitMsgClean$(echo "$commitMsg" |
        sed -E 's/^(fix|feat|chore)://i' |
        tr -d '[:punct:]' |
        tr -d ' '
    )

    echo  "$outputDir/${commitDate}_${commitType}(${commitMsgClean}_${commitHash:0:7})"
}

function processCommit() {
  local commitHash="$1"
  local commitDate=$(git show -s --format=%cd "$commitHash")
  local commitMsg=$(git show -s --format=%B "$commitHash")
  local commitDir=$(commitDirName $commitHash)

  mkdir -p "$CommitDir"

  echo "## Commit $commitHash - $commitDate" >> "$summaryFile"
  echo "" >> "$summaryFile"
  echo "\`\`\`" >> "$summaryFile"
  echo "$commitMsg" >> "$summaryFile"
  echo "\`\`\`" >> "$summaryFile"
  echo "" >> summaryFile

  echo "### Changed Files" >> "$summaryFile"
  echo "" >> "$summaryFile"

  git show --pretty="" --name-only "$commitHash" | while read -r file; do
      if [ -f "$file" ]; then
        local FILE_SIZE=$(du -k "$file" | cut -f1)

        if [ "$FILE_SIZE" -le "$MAX_FILE_SIZE" ]; then
            mkdir -p "$commitDir/$(dirname "$file")"
            git show "$commitHash:$file" > "$commitDir/$file" 2>/dev/null

            echo "#### $file" >> "$summaryFile"
            echo "\`\`\`diff" >> "$summaryFile"
            git show "$commitHash" -- "$file" >> "$summaryFile"
            echo "\`\`\`" >> "$summaryFile"
            echo "" >> "$summaryFile"
        else
            echo "#### $file (File too large - $FILE_SIZE KB)" >> "$summaryFile"
            echo "File exceeds size limit of $MAX_FILE_SIZE KB" >> "$summaryFile"
            echo "" >> "$summaryFile"
        fi
      fi
  done

  echo "---" >> "$summaryFile"
  echo "" >> "$summaryFile"
}

if [ "$#" -lt 2 ]; then
    usage
fi

author="$1"
outputDir="$2"
MAX_FILE_SIZE=${3:-1000} # default 1MB

mkdir -p "$outputDir"
summaryFile="$outputDir/commit_sumary.md"

echo "# Git Commit History for $author" > "$summaryFile"
echo "Generated on $(date)" >> "$summaryFile"
echo "" > "$summaryFile"

git log --author="$author" --pretty=format:"%h" | while read -r commitHash; do
    processCommit "$commitMsg"
done

echo  "Status: Completed! Check ./$outputDir"