# AGENTS.md

This file contains guidelines for AI agents working on the dorado_updater repository.

## Overview

Dorado Updater is a simple bash script that streamlines installation and updating of Oxford Nanopore's Dorado software on Linux systems. The project consists of:
- `update_dorado.sh` - Main bash script for installation/updates
- `README.md` - User documentation
- `LICENSE` - MIT license

## Build/Lint/Test Commands

This is a bash-only project with no automated testing, linting, or build process.

**Run the script:**
```bash
./update_dorado.sh [--clean-install]
```

**Verify installation:**
```bash
conda run -n dorado dorado --version
```

**Manual testing:**
- Test with various Dorado tar.gz versions
- Test clean install: `./update_dorado.sh --clean-install`
- Test edge cases: missing conda, multiple tar.gz files, corrupted archives
- Test on different Linux distributions and WSL2

## Code Style Guidelines

### Bash Script Conventions

**Script Headers:**
```bash
#!/bin/bash
set -euo pipefail  # Strict mode - exit on error, unset vars, and pipe failures
```

**Functions:**
- Use `function name { ... }` format
- Use descriptive function names
- Keep functions focused on single purpose

**Variables:**
- Always quote variables: `"$var"` not `$var`
- Use lowercase or snake_case for variable names
- Use `$()` for command substitution: `$(command)` not backticks

**Error Handling:**
- Check command success with `|| { echo "Error: ..."; exit 1; }`
- Provide descriptive error messages with color coding
- Use appropriate exit codes (0 for success, 1 for errors)

**Terminal Output:**
- Use colors for user feedback with fallback for non-TTY:
```bash
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi
```
- Use `echo -e` for escape sequences
- Always reset color with `${NC}` at end of message

**File Operations:**
- Always verify directories/files exist before operations
- Use `mkdir -p` for nested directory creation
- Use `ln -sf` for symlinks (force creation)
- Use `rm -rf` with caution, verify paths first

**Comments:**
- Add comments explaining complex logic
- Section headers with `---` separators
- Keep comments concise and relevant

**Command Line Arguments:**
- Use case statements for argument parsing
- Provide `--help` option
- Validate unknown options and exit with error

### File Structure

**Expected file structure after installation:**
```
~/miniconda3/envs/dorado/
├── bin
│   ├── dorado
│   └── [dorado binaries and libraries]
├── lib
│   └── [dorado shared libraries]
└── [conda-managed files]
```

### Key Design Patterns

1. **Conda Environment:** Uses conda env `bin/` to avoid messing with user `$PATH`
2. **Standard Layout:** Uses standard conda env structure with binaries in `env/bin/` and libraries in `env/lib/`
3. **Version Detection:** Sorts tar.gz files by version number using `sort -V`
4. **Fallback Handling:** Multiple fallback mechanisms for finding conda/env paths
5. **Cleanup:** Always remove extracted folders after installation

## Testing Considerations

Since there's no automated test suite, manually verify:
- Script works with conda and mamba
- Handles missing conda gracefully
- Handles multiple Dorado versions (uses latest)
- Clean install properly removes old env
- Standard conda env structure is correctly created
- Error messages are clear and helpful
- Works on different Linux distributions
- WSL2 compatibility
- **Security:** Verify tar extraction uses temp directory and --strip-components
- **Checksum:** Test optional SHA256 verification with valid and invalid checksums

## Making Changes

1. Test changes manually before committing
2. Update README.md if user-facing behavior changes
3. Ensure CRLF line endings are maintained (script uses CRLF)
4. Verify error handling still works properly
5. Check that strict mode (`set -euo pipefail`) doesn't break new code

## Common Issues to Handle

- Missing conda/mamba installation
- Multiple Dorado tar.gz versions in directory
- Corrupted or incomplete tar.gz files
- Existing conda environment conflicts
- Permission issues with conda directories
- Incorrect directory structure in extracted package
