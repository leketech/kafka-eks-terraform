#!/bin/bash

# Script to fix line endings and other issues in GitHub Actions workflow files

# Convert line endings to LF
sed -i 's/\r$//' .github/workflows/*.yml

# Remove trailing spaces
sed -i 's/[[:space:]]*$//' .github/workflows/*.yml

# Add newline at end of file if missing
for file in .github/workflows/*.yml; do
  if [ -f "$file" ]; then
    lastchar=$(tail -c 1 "$file")
    if [ "$lastchar" != "" ] && [ "$lastchar" != $'\n' ]; then
      echo >> "$file"
    fi
  fi
done

echo "Workflow files have been fixed!"