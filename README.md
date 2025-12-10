# Cachéd Out

A simple, safe macOS cleanup utility that frees up disk space by removing application caches, browser data, and temporary files.

## Features

- **Safe by default**: All files moved to Trash, nothing permanently deleted
- **Fast**: Cleans ~800-900 MB per run
- **Simple UI**: Click once, see results
- **Comprehensive**: Cleans app caches, browser caches, temp files
- **Non-intrusive**: User-level cleanup, no system modifications
- **Transparent**: Shows exactly what was cleaned and space freed

## What Gets Cleaned

- Application caches (`~/Library/Caches/*`)
- Browser caches (Safari, Chrome, Firefox)
- Temporary files (`/var/tmp`, `/private/var/folders`)
- Old Metal shader caches
- Obsolete update packages

## What's Safe

- System files (`/System/*`, `/Library/LaunchDaemons`)
- Application preferences and settings
- User data and documents
- Everything is moved to Trash, so nothing is permanently deleted

## Installation

### Option 1: Use the App Bundle (Easiest)

```bash
# Already in ~/Applications/CachedOut.app
# Just double-click in Finder to run
```

### Option 2: Command Line

```bash
# Run from terminal
open ~/Applications/CachedOut.app

# Or run the script directly
~/mac-cleanup.sh --backup --yes
```

### Option 3: Copy to System Applications

```bash
cp -r ~/Applications/CachedOut.app /Applications/
```

## Usage

### GUI App (One-Click)

1. **Double-click** `CachedOut.app` in Finder
2. Choose **"Preview First"** to see what will be cleaned
3. Click **"Run Cleanup"**
4. See results: files cleaned + space freed
5. All cleaned files are in Trash for recovery

### Command Line

```bash
# Preview what will be cleaned (no changes)
~/mac-cleanup.sh --dry-run --yes

# Actually clean up
~/mac-cleanup.sh --backup --yes

# Clean without backup (permanent deletion - be careful!)
~/mac-cleanup.sh --no-backup --yes

# Verbose output
~/mac-cleanup.sh --backup --verbose --yes
```

## Results

Typical run:
- **Files cleaned**: 1,500-2,000
- **Space freed**: 800-900 MB
- **Time taken**: 30-60 seconds

## Recovery

All cleaned files are moved to `~/.Trash` and can be restored:

```bash
# List items in Trash
ls ~/.Trash

# Restore a file
mv ~/.Trash/filename ~/desired/location/
```

## How It Works

1. **Whitelist-only approach**: Only targets known-safe locations
2. **Version detection**: Handles macOS 14+ specific behaviors
3. **Graceful errors**: Skips in-use files instead of crashing
4. **Comprehensive logging**: Full audit trail in `~/Library/Logs/mac-cleanup.log`
5. **Dry-run mode**: Preview changes before applying

## Requirements

- macOS 14+ (Sonoma and later)
- ~5 minutes of disk I/O time for first run

## Safety Features

- ✅ Lock file prevents concurrent runs
- ✅ Dry-run mode for testing
- ✅ Complete logging for all operations
- ✅ Backup to Trash by default
- ✅ In-use file detection
- ✅ System file protection

## Troubleshooting

### App won't launch
```bash
chmod +x ~/Applications/CachedOut.app/Contents/MacOS/CachedOut
chmod +x ~/Applications/CachedOut.app/Contents/Resources/mac-cleanup.sh
```

### Permission errors
Some cached files may be locked by running applications. Close apps and try again.

### Check logs
```bash
tail -50 ~/Library/Logs/mac-cleanup.log
```

## Project Structure

```
CachedOut/
├── Applications/CachedOut.app/       # macOS app bundle
│   └── Contents/
│       ├── MacOS/CachedOut           # GUI wrapper script
│       ├── Resources/
│       │   ├── mac-cleanup.sh        # Core cleanup logic
│       │   └── AppIcon.icns          # App icon
│       └── Info.plist                # App metadata
├── mac-cleanup.sh                    # Standalone script
└── README.md                         # This file
```

## License

MIT License - See LICENSE file for details

## Contributing

Feel free to submit issues and enhancement requests!

## Changelog

### v1.0 (2025-12-07)
- Initial release as "Cachéd Out"
- CLI and GUI support
- Comprehensive cache cleaning
- Safe Trash-based recovery
