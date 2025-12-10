# How to Push MacCleanup to GitHub

## Step 1: Create a GitHub Repository

1. Go to https://github.com/new
2. Repository name: `maccleanup`
3. Description: `Safe, simple macOS cleanup utility that frees disk space`
4. Choose: Public or Private
5. **Do NOT** initialize with README (we already have one)
6. Click **"Create repository"**

## Step 2: Connect Local Repo to GitHub

Copy and run these commands:

```bash
cd ~

# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/maccleanup.git

# Rename branch to main (GitHub's default)
git branch -m master main

# Push to GitHub
git push -u origin main
```

**Replace `YOUR_USERNAME` with your actual GitHub username**

## Step 3: Verify

Visit: `https://github.com/YOUR_USERNAME/maccleanup`

You should see:
- All your files
- The README displayed
- The MIT License

## Step 4: Add GitHub Topics (Optional)

On your repo page:
1. Click the gear icon (Settings)
2. Scroll to "Topics"
3. Add: `macos`, `cleanup`, `utility`, `cache-cleaner`

## What's in the Repo

```
maccleanup/
├── mac-cleanup.sh                    # Core script (20 KB)
├── Applications/MacCleanup.app/      # Full app bundle
│   └── Contents/
│       ├── MacOS/MacCleanup          # GUI wrapper
│       ├── Resources/
│       │   ├── mac-cleanup.sh        # Embedded script
│       │   └── AppIcon.icns          # App icon
│       └── Info.plist
├── README.md                         # Full documentation
├── LICENSE                           # MIT License
└── .gitignore                        # Ignore OS files
```

## Command Cheat Sheet

```bash
# Check git status
cd ~ && git status

# View commit history
git log --oneline

# Push future updates
git add .
git commit -m "Description of changes"
git push origin main

# Clone the repo locally elsewhere
git clone https://github.com/YOUR_USERNAME/maccleanup.git
```

## Next Steps

1. Share the repo URL: `https://github.com/YOUR_USERNAME/maccleanup`
2. Users can now:
   - Star the project
   - Fork it
   - Report issues
   - Suggest improvements

Done! You now have your project on GitHub.
