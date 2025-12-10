#!/bin/bash

# MacCleanup GitHub Push Script
# Run this to push to GitHub

echo "MacCleanup - GitHub Push Setup"
echo "================================"
echo ""

# The username
USERNAME="jhigh1594"
REPO="maccleanup"

echo "1. Add GitHub remote..."
cd ~ && git remote add origin https://github.com/${USERNAME}/${REPO}.git

echo "2. Rename branch to main..."
git branch -m master main

echo "3. Push to GitHub..."
git push -u origin main

echo ""
echo "✅ Done! Your repo is now at:"
echo "   https://github.com/${USERNAME}/${REPO}"
echo ""
