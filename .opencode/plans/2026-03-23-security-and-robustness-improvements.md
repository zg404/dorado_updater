# Dorado Updater Security and Robustness Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor dorado_updater script and documentation to eliminate unnecessary complexity, add security hardening, and improve robustness.

**Architecture:** Simplify conda environment structure to standard layout, add secure tar extraction with checksums, improve path detection reliability, and fix documentation inconsistencies.

**Tech Stack:** Bash script, GNU tar, conda/mamba CLI, shasum, JSON parsing (jq)

---

## Overview of Changes

1. **Simplify structure**: Remove nested `bin/bin/` and `bin/lib/`, use standard conda env layout
2. **Secure tar extraction**: Extract to temp directory with path validation
3. **Add checksum verification**: Allow optional SHA256 verification
4. **Fix path detection**: Use `conda info --envs --json` for reliable parsing
5. **Improve cleanup**: Fix `find` command syntax
6. **Update README**: Remove sudo from manual install, fix path inconsistencies

---

### Task 1: Simplify environment directory structure

**Files:**
- Modify: `update_dorado.sh:195-196, 200, 220-228, 237-246`

**Step 1: Define standard conda paths (modify lines 195-196)**

Replace:
```bash
env_bin="$dorado_env/bin/bin"
env_lib="$dorado_env/bin/lib"
```

With:
```bash
env_bin="$dorado_env/bin"
env_lib="$dorado_env/lib"
```

**Step 2: Create standard directory structure (modify line 200)**

Replace:
```bash
mkdir -p "$dorado_env/bin/bin" "$dorado_env/bin/lib"
```

With:
```bash
mkdir -p "$dorado_env/bin" "$dorado_env/lib"
```

**Step 3: Copy to standard locations (modify lines 221-228)**

Replace:
```bash
cp -r "$dorado_folder/bin/"* "$dorado_env/bin/bin/" || {
  echo -e "${RED}Error: Failed to copy bin directory.${NC}"
  exit 1
}
cp -r "$dorado_folder/lib/"* "$dorado_env/bin/lib/" || {
  echo -e "${RED}Error: Failed to copy lib directory.${NC}"
  exit 1
}
```

With:
```bash
cp -r "$dorado_folder/bin/"* "$dorado_env/bin/" || {
  echo -e "${RED}Error: Failed to copy bin directory.${NC}"
  exit 1
}
cp -r "$dorado_folder/lib/"* "$dorado_env/lib/" || {
  echo -e "${RED}Error: Failed to copy lib directory.${NC}"
  exit 1
}
```

**Step 4: Remove unnecessary symlink (modify lines 237-246)**

Replace:
```bash
# Ensure the symlink exists and is correct.
symlink_path="$dorado_env/bin/dorado"
target_path="$env_bin/dorado"

if [ ! -L "$symlink_path" ] || [ "$(readlink "$symlink_path")" != "$target_path" ]; then
  echo -e "${CYAN}Creating/Updating symlink...${NC}"
  ln -sf "$target_path" "$symlink_path" || {
    echo -e "${RED}Error: Failed to create symlink.${NC}"
    exit 1
  }
fi
```

With:
```bash
# Verify the dorado executable is accessible (now directly in env/bin)
if [ ! -f "$env_bin/dorado" ]; then
  echo -e "${RED}Error: Dorado executable not found after installation.${NC}"
  exit 1
fi
echo -e "${GREEN}Dorado binary installed to: $env_bin/dorado${NC}"
```

**Step 5: Update cleanup section (modify line 204-210)**

Replace:
```bash
# Clean up existing files if they exist
echo -e "${CYAN}Cleaning up existing Dorado binaries...${NC}"
if [ -d "$env_bin" ]; then
  find "$env_bin" -mindepth 1 -maxdepth 1 ! -lname '*' -delete 2>/dev/null || true
fi

if [ -d "$env_lib" ]; then
  find "$env_lib" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
fi
```

With:
```bash
# Clean up existing files if they exist (preserve conda-managed files)
echo -e "${CYAN}Cleaning up existing Dorado binaries...${NC}"
# Remove dorado and its dependencies from env/bin
for f in dorado*; do
  [ -f "$env_bin/$f" ] && rm -f "$env_bin/$f"
done
# Remove libraries from env/lib
if [ -d "$env_lib" ]; then
  find "$env_lib" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
  find "$env_lib" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
fi
```

**Step 6: Update verify binary location (modify lines 231-234)**

Replace:
```bash
# Verify the dorado executable exists after copying
if [ ! -f "$env_bin/dorado" ]; then
  echo -e "${RED}Error: Dorado executable not found after installation.${NC}"
  exit 1
fi
```

With:
```bash
# Verify the dorado executable is accessible
if [ ! -f "$env_bin/dorado" ]; then
  echo -e "${RED}Error: Dorado executable not found at $env_bin/dorado${NC}"
  exit 1
fi
```

**Step 7: Test the changes**

Run: `bash -n update_dorado.sh`
Expected: No syntax errors

**Step 8: Commit**

```bash
git add update_dorado.sh
git commit -m "refactor: simplify to standard conda env structure

- Remove nested bin/bin and bin/lib structure
- Use standard conda env/bin and env/lib layout
- Remove unnecessary symlink as dorado is now directly accessible
- Simplify cleanup with targeted file removal
- Improve error messages with full paths"
```

---

### Task 2: Secure tar extraction with temporary directory

**Files:**
- Modify: `update_dorado.sh:176-183, 248-250`
- Modify: `README.md:86-90, 107-111` (update manual install instructions)

**Step 1: Add temp directory creation after conda setup (add after line 74)**

Add:
```bash
# Create temporary directory for secure extraction
temp_dir=$(mktemp -d) || {
  echo -e "${RED}Error: Failed to create temporary directory.${NC}"
  exit 1
}
echo -e "${CYAN}Using temp directory: $temp_dir${NC}"

# Cleanup function to remove temp dir on exit
cleanup_temp() {
  if [ -d "$temp_dir" ]; then
    echo -e "${CYAN}Cleaning up temporary directory...${NC}"
    rm -rf "$temp_dir"
  fi
}
trap cleanup_temp EXIT
```

**Step 2: Secure tar extraction (modify lines 177-183)**

Replace:
```bash
# Extract the tar.gz file.  Use a subshell to avoid changing the CWD of the main script.
(
  echo -e "${CYAN}Extracting Dorado package: ${BOLD}$dorado_targz${NC}"
  if ! tar -xf "$dorado_targz"; then
    echo -e "${RED}Error: Failed to extract tar.gz file.${NC}"
    exit 1
  }
)
```

With:
```bash
# Extract the tar.gz file securely to temp directory
echo -e "${CYAN}Extracting Dorado package: ${BOLD}$dorado_targz${NC}"

# Use --strip-components=1 to remove top-level directory and prevent path traversal
# Extract to temp_dir to avoid cluttering working directory
if ! tar -xf "$dorado_targz" --strip-components=1 -C "$temp_dir"; then
  echo -e "${RED}Error: Failed to extract tar.gz file.${NC}"
  exit 1
fi
```

**Step 3: Update folder path to use temp_dir (modify line 186)**

Replace:
```bash
dorado_folder=$(basename "$dorado_targz" .tar.gz)
```

With:
```bash
# Point dorado_folder to temp extraction directory
dorado_folder="$temp_dir"
```

**Step 4: Remove old extracted folder cleanup (modify line 102-106)**

Replace:
```bash
# Check if the folder already exists (from previous extraction)
if [ -d "$dorado_folder" ]; then
  echo -e "${YELLOW}Found existing extracted folder: ${BOLD}$dorado_folder${NC}"
  echo -e "${CYAN}Removing old extracted folder to ensure clean contents...${NC}"
  rm -rf "$dorado_folder"
fi
```

With:
```bash
# Note: Using temp directory, no need to check for existing extracted folder
```

**Step 5: Update cleanup section (modify line 249)**

Remove:
```bash
rm -rf "$dorado_folder" # remove extracted folder
```

The trap will handle temp dir cleanup automatically.

**Step 6: Test extraction**

Run: `./update_dorado.sh --help` (to verify script loads without errors)
Expected: Help message displays

**Step 7: Commit**

```bash
git add update_dorado.sh
git commit -m "security: use secure tar extraction with temp directory

- Extract to temp directory with mktemp -d
- Use --strip-components=1 to prevent path traversal attacks
- Add cleanup trap to remove temp dir on exit
- Remove old extracted folder check (no longer needed)"
```

---

### Task 3: Add optional SHA256 checksum verification

**Files:**
- Modify: `update_dorado.sh:27-33, 36-53, 77-91`
- Modify: `README.md:25-31, 51-54`

**Step 1: Update help message (modify line 32)**

Replace:
```bash
echo "  --help             Show this help message"
```

With:
```bash
echo "  --verify-checksum  Verify SHA256 checksum before installation"
echo "  --help             Show this help message"
```

**Step 2: Add verify_checksum argument handling (modify line 36)**

Replace:
```bash
clean_install=0
```

With:
```bash
clean_install=0
verify_checksum=0
```

**Step 3: Add --verify-checksum case (modify lines 38-52)**

Replace:
```bash
for arg in "$@"; do
  case "$arg" in
    --clean-install)
      clean_install=1
      echo -e "${YELLOW}Clean install requested. Will remove existing Dorado environment if it exists.${NC}"
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}"
      show_help
      exit 1
      ;;
  esac
done
```

With:
```bash
for arg in "$@"; do
  case "$arg" in
    --clean-install)
      clean_install=1
      echo -e "${YELLOW}Clean install requested. Will remove existing Dorado environment if it exists.${NC}"
      ;;
    --verify-checksum)
      verify_checksum=1
      echo -e "${YELLOW}Checksum verification requested.${NC}"
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}"
      show_help
      exit 1
      ;;
  esac
done
```

**Step 4: Add checksum verification function (add after line 54, before conda setup)**

Add:
```bash
# Verify SHA256 checksum of tar.gz file
function verify_checksum {
  local file="$1"
  local checksum_file="${file}.sha256"

  if [ ! -f "$checksum_file" ]; then
    echo -e "${YELLOW}Warning: Checksum file not found: $checksum_file${NC}"
    echo -e "${CYAN}Expected format: <checksum>  $(basename "$file")${NC}"
    echo -e "${CYAN}Skipping verification.${NC}"
    return 0
  fi

  echo -e "${CYAN}Verifying checksum...${NC}"

  # Extract expected checksum and filename from checksum file
  local expected_checksum=$(awk '{print $1}' "$checksum_file")
  local expected_filename=$(awk '{print $2}' "$checksum_file")

  if [ -z "$expected_checksum" ]; then
    echo -e "${RED}Error: Could not read checksum from file.${NC}"
    return 1
  fi

  # Verify filename matches
  if [ "$expected_filename" != "$(basename "$file")" ]; then
    echo -e "${YELLOW}Warning: Filename in checksum file doesn't match tar.gz file${NC}"
    echo -e "${CYAN}Expected: $expected_filename${NC}"
    echo -e "${CYAN}Found: $(basename "$file")${NC}"
  fi

  # Calculate actual checksum
  local actual_checksum=$(shasum -a 256 "$file" | awk '{print $1}')

  if [ "$expected_checksum" == "$actual_checksum" ]; then
    echo -e "${GREEN}Checksum verified successfully!${NC}"
    return 0
  else
    echo -e "${RED}Error: Checksum mismatch!${NC}"
    echo -e "${RED}Expected: $expected_checksum${NC}"
    echo -e "${RED}Actual:   $actual_checksum${NC}"
    return 1
  fi
}
```

**Step 5: Call verification after selecting tar.gz (modify after line 96)**

Add:
```bash
# Verify checksum if requested
if [ "$verify_checksum" -eq 1 ]; then
  verify_checksum "$dorado_targz" || {
    echo -e "${RED}Error: Checksum verification failed. Installation aborted.${NC}"
    exit 1
  }
fi
```

**Step 6: Update README with checksum instructions (modify line 25-31)**

Replace:
```bash
## Requirements
- Linux x64 system (WSL2 supported)
- Working conda installation (Miniconda, Miniforge, or Anaconda)
- Download the latest Dorado Linux-x64 package: [dorado-X.X.X-linux-x64.tar.gz](https://github.com/nanoporetech/dorado?tab=readme-ov-file#installation)
```

With:
```bash
## Requirements
- Linux x64 system (WSL2 supported)
- Working conda installation (Miniconda, Miniforge, or Anaconda)
- Download the latest Dorado Linux-x64 package: [dorado-X.X.X-linux-x64.tar.gz](https://github.com/nanoporetech/dorado?tab=readme-ov-file#installation)
- Optional: Download the corresponding SHA256 checksum file for verification

> [!TIP]
> Download the SHA256 checksum from the [GitHub releases page](https://github.com/nanoporetech/dorado/releases) alongside the tar.gz file. Place it in the same directory with the same base name (e.g., `dorado-0.8.0-linux-x64.tar.gz.sha256`).
```

**Step 7: Update README usage section (modify line 42-45)**

Replace:
```bash
4. Run the script in the same directory as the Dorado tar.gz file. Optional: add "--clean-install" to remove the existing Dorado environment and create a new one:
    ```bash
    ./update_dorado.sh [--clean-install]
    ```
```

With:
```bash
4. Run the script in the same directory as the Dorado tar.gz file. Optional flags:
    ```bash
    ./update_dorado.sh [--clean-install] [--verify-checksum]
    ```
   - `--clean-install`: Remove existing Dorado environment and create a new one
   - `--verify-checksum`: Verify SHA256 checksum before installation
```

**Step 8: Test checksum verification**

Test by creating a dummy checksum file:
```bash
echo "test  dorado-test.tar.gz" > test.sha256
```

Run: `bash -n update_dorado.sh`
Expected: No syntax errors

**Step 9: Commit**

```bash
git add update_dorado.sh README.md
git commit -m "feat: add optional SHA256 checksum verification

- Add --verify-checksum flag
- Verify tar.gz against .sha256 file if provided
- Validate checksum format and filename match
- Fail installation if checksum mismatch detected
- Update README with checksum usage instructions"
```

---

### Task 4: Improve conda path detection using JSON

**Files:**
- Modify: `update_dorado.sh:70-75, 120-135, 161-168`

**Step 1: Check for jq dependency (add after line 68)**

Add:
```bash
# Check for jq for JSON parsing
if command -v jq >/dev/null 2>&1; then
  USE_JQ=1
  echo -e "${CYAN}Using jq for reliable conda path detection${NC}"
else
  USE_JQ=0
  echo -e "${YELLOW}Warning: jq not found. Using fallback path detection.${NC}"
fi
```

**Step 2: Extract conda base directory using JSON (modify lines 70-75)**

Replace:
```bash
# Extract the conda base directory robustly.
conda_base=$(dirname "$(dirname "$conda_path")")
if [ ! -d "$conda_base" ]; then
    echo -e "${RED}Error: Could not determine Conda base directory. Expected directory structure not found.${NC}"
    exit 1
fi
```

With:
```bash
# Extract the conda base directory - prefer JSON for accuracy
if [ "$USE_JQ" -eq 1 ]; then
  conda_base=$($conda_cmd info --base 2>/dev/null || dirname "$(dirname "$conda_path")")
else
  conda_base=$(dirname "$(dirname "$conda_path")")
fi

if [ ! -d "$conda_base" ]; then
    echo -e "${RED}Error: Could not determine Conda base directory. Expected directory structure not found.${NC}"
    exit 1
fi
```

**Step 3: Update environment detection using JSON (modify lines 120-135)**

Replace:
```bash
# Define the dorado environment path and check if it exists
# First check if conda env exists using conda command
env_exists=0
if $conda_cmd env list | grep -q "dorado"; then
  env_exists=1
  # Get the actual path from conda
  dorado_env=$($conda_cmd env list | grep "dorado" | awk '{print $NF}')
  # If path not found from conda, try to locate it
  if [ -z "$dorado_env" ]; then
    dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
  fi
else
  # If not found in conda list, try to find it directly
  dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
  if [ -n "$dorado_env" ]; then
    env_exists=1
  fi
fi
```

With:
```bash
# Define the dorado environment path and check if it exists
env_exists=0
dorado_env=""

if [ "$USE_JQ" -eq 1 ]; then
  # Use JSON for reliable parsing
  env_json=$($conda_cmd env list --json 2>/dev/null || echo '{"envs":[]}')
  dorado_env=$(echo "$env_json" | jq -r '.envs[] | select(endswith("/dorado"))' 2>/dev/null | head -n 1)
  [ -n "$dorado_env" ] && env_exists=1
else
  # Fallback to grep/awk parsing
  if $conda_cmd env list | grep -q "dorado"; then
    env_exists=1
    # Get the actual path from conda
    dorado_env=$($conda_cmd env list | grep "dorado" | awk '{print $NF}')
    # If path not found from conda, try to locate it
    if [ -z "$dorado_env" ]; then
      dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
    fi
  else
    # If not found in conda list, try to find it directly
    dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
    if [ -n "$dorado_env" ]; then
      env_exists=1
    fi
  fi
fi
```

**Step 4: Update environment creation path detection (modify lines 161-168)**

Replace:
```bash
  # Get the path of the newly created environment
  dorado_env=$($conda_cmd env list | grep "dorado" | awk '{print $NF}')
  if [ -z "$dorado_env" ]; then
    dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
  fi
else
  echo -e "${CYAN}Dorado environment found at: ${BOLD}$dorado_env${NC}"
fi
```

With:
```bash
  # Get the path of the newly created environment
  if [ "$USE_JQ" -eq 1 ]; then
    env_json=$($conda_cmd env list --json 2>/dev/null || echo '{"envs":[]}')
    dorado_env=$(echo "$env_json" | jq -r '.envs[] | select(endswith("/dorado"))' 2>/dev/null | head -n 1)
  else
    dorado_env=$($conda_cmd env list | grep "dorado" | awk '{print $NF}')
    if [ -z "$dorado_env" ]; then
      dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
    fi
  fi
else
  echo -e "${CYAN}Dorado environment found at: ${BOLD}$dorado_env${NC}"
fi
```

**Step 5: Test path detection**

Run: `bash -n update_dorado.sh`
Expected: No syntax errors

**Step 6: Commit**

```bash
git add update_dorado.sh
git commit -m "improve: reliable conda path detection with JSON parsing

- Use conda info --base for accurate base directory
- Prefer JSON parsing via jq for environment detection
- Keep grep/awk fallback for systems without jq
- Eliminate fragile awk parsing of env list
- Add jq detection with warning if not available"
```

---

### Task 5: Fix README documentation inconsistencies

**Files:**
- Modify: `README.md:86-134`

**Step 1: Fix manual Traditional Method paths (modify line 91-93)**

Replace:
```bash
2. Copy the extracted `bin/` and `lib/` directories to a location in your `$PATH`. In most Linux distros, this should be: `~/.local/bin`
```bash
cp -r ./bin/ ./lib/ $HOME/.local/bin
```
```

With:
```bash
2. Copy the extracted `bin/` directory contents to `~/.local/bin`, and `lib/` to `~/.local/lib`:
```bash
cp -r ./bin/* ~/.local/bin/
cp -r ./lib/* ~/.local/lib/
```
```

**Step 2: Fix Traditional Method symlink (modify line 96-98)**

Remove this entire section as symlink is no longer needed:
```bash
3. Create a symlink in the same location that points to the dorado binary in the nested `bin/` directory.
  ```bash
  ln -s $HOME/.local/bin/bin/dorado $HOME/.local/bin/dorado
  ```
```

With:
```bash
3. Run `dorado --version` to verify the installation
```

**Step 4: Fix Traditional Method update section (modify line 100-103)**

Replace:
```bash
5. To update Dorado, delete the old `~/.local/bin/bin/` and `~/.local/bin/lib/` directories and repeat the process with the new version.
```bash
rm -rf $HOME/.local/bin/bin/ $HOME/.local/bin/lib/
```
```

With:
```bash
4. To update Dorado, delete the old binaries and libraries and repeat the process with the new version:
```bash
rm -rf ~/.local/bin/dorado* ~/.local/lib/*dorado*
```
```

**Step 5: Fix Manual Conda Method - remove sudo (modify line 119-122)**

Replace:
```bash
2. Copy the extracted `bin/` and `lib/` directories to the new or existing Conda env, found in: `~/miniconda3/envs/`
```bash
sudo cp -r ./bin/ ./lib/ ~/miniconda3/envs/dorado/
```
```

With:
```bash
2. Copy the extracted `bin/` and `lib/` directories to the conda environment. The path is typically `~/miniconda3/envs/` or `~/miniforge3/envs/`:
```bash
# First, find your conda envs path:
conda info --envs

# Then copy (replace <path> with actual path from above):
cp -r ./bin/* <path>/dorado/bin/
cp -r ./lib/* <path>/dorado/lib/
```
```

**Step 6: Remove Conda symlink section (modify line 123-126)**

Remove this entire section as symlink is no longer needed:
```bash
3. Create a symlink in the same location that points to the dorado binary in the nested `bin/` directory.
  ```bash
  ln -s ~/miniconda3/envs/dorado/bin/bin/dorado ~/miniconda3/envs/dorado/bin/dorado
  ```
```

With:
```bash
3. Verify the installation
```

**Step 7: Fix Conda update section (modify line 131-134)**

Replace:
```bash
5. To update Dorado, delete the old `~/miniconda3/envs/dorado/bin/bin/` and `~/miniconda3/envs/dorado/lib/` directories and repeat the process with the new version.
```bash
rm -rf ~/miniconda3/envs/dorado/bin/bin/ ~/miniconda3/envs/dorado/lib/
```
```

With:
```bash
4. To update Dorado, delete the old binaries and libraries and repeat the process:
```bash
# Find your conda envs path with: conda info --envs
# Then (replace <path> with actual path):
rm -rf <path>/dorado/bin/dorado* <path>/dorado/lib/*dorado*
```
```

**Step 8: Update file structure diagram (modify line 9-17)**

Replace:
```bash
~/miniconda3/envs/dorado/bin/
├── bin
│   └── dorado
├── lib
│   └── [bunch of files]
├── dorado -> ~/miniconda3/envs/dorado/bin/bin/dorado (symlink)
└── [bunch of files]
```

With:
```bash
~/miniconda3/envs/dorado/
├── bin
│   ├── dorado
│   └── [dorado binaries]
├── lib
│   └── [dorado libraries]
└── [conda files]
```

**Step 9: Update Design Rationale section (modify line 71-81)**

Replace:
```bash
2. Handles Dorado's pre-compiled binaries structure, which includes`bin/` and `lib/` directories. This would normally require adding the nested `bin/` to `$PATH` (e.g., `~/miniconda/envs/dorado/bin/bin`).

3. Creates a symlink in the root of the conda env `bin/` that points to the dorado binary in the nested `bin/`, allowing the command to be called directly after conda activation.
```

With:
```bash
2. Handles Dorado's pre-compiled binaries structure by placing them directly in the standard conda environment layout (`env/bin/` for binaries and `env/lib/` for libraries). This ensures dorado is immediately accessible after activating the environment.

3. Avoids modifying the user's system-wide `$PATH`, keeping dorado contained within the conda environment and preventing conflicts with other tools.
```

**Step 10: Test README rendering**

Check: Review README in GitHub markdown viewer or use a markdown linter
Expected: All code blocks render correctly, paths are consistent

**Step 11: Commit**

```bash
git add README.md
git commit -m "docs: fix README inconsistencies and outdated instructions

- Remove sudo from manual Conda install instructions
- Remove symlink steps (no longer needed with simplified structure)
- Update file structure diagram to match standard conda layout
- Use generic paths (miniconda3/miniforge3) with examples
- Add conda info --envs command to help users find correct paths
- Fix cleanup commands in update instructions
- Update design rationale to reflect simplified approach"
```

---

### Task 6: Update AGENTS.md with new structure

**Files:**
- Modify: `AGENTS.md:15-26, 68-70`

**Step 1: Update expected file structure (modify line 15-26)**

Replace:
```bash
**Expected file structure after installation:**
```
~/miniconda3/envs/dorado/bin/
├── bin
│   └── dorado
├── lib
│   └── [bunch of files]
├── dorado -> ~/miniconda3/envs/dorado/bin/bin/dorado (symlink)
└── [bunch of files]
```
```

With:
```bash
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
```

**Step 2: Update key design patterns (modify line 68-70)**

Replace:
```bash
2. **Symlink Strategy:** Creates symlink in env root pointing to nested `bin/dorado`
```

With:
```bash
2. **Standard Layout:** Uses standard conda env structure with binaries in `env/bin/` and libraries in `env/lib/`
```

**Step 3: Update testing considerations (modify after line 70)**

Add:
```bash
6. **Security:** Verify tar extraction uses temp directory and --strip-components
7. **Checksum:** Test optional SHA256 verification with valid and invalid checksums
```

**Step 4: Test AGENTS.md consistency**

Check: Verify file paths match actual implementation
Expected: All paths and structures consistent

**Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md for simplified structure

- Update expected file structure to standard conda layout
- Remove symlink strategy from design patterns
- Add security and checksum verification to testing
- Ensure consistency with updated implementation"
```

---

### Task 7: Final validation and testing

**Files:**
- All files (comprehensive validation)

**Step 1: Verify script syntax**

Run: `bash -n update_dorado.sh`
Expected: No syntax errors

**Step 2: Check for shellcheck issues (if available)**

Run: `shellcheck update_dorado.sh`
Expected: No critical issues (warnings acceptable if documented)

**Step 3: Verify all help flags work**

Run: `./update_dorado.sh --help`
Expected: Help message displays with all options

**Step 4: Test checksum function with mock data**

Create test files:
```bash
echo "test content" > test.tar.gz
echo "invalid_checksum  test.tar.gz" > test.tar.gz.sha256
```

Run: `bash -c 'source ./update_dorado.sh; verify_checksum test.tar.gz'`
Expected: Function exists and validates correctly

**Step 5: Review all commits**

Run: `git log --oneline -10`
Expected: All 6 tasks committed with descriptive messages

**Step 6: Final README review**

Check: Ensure all manual install paths are correct and no sudo references remain
Expected: No sudo commands, consistent paths throughout

**Step 7: Commit final validation**

```bash
git add -A
git commit -m "test: validate all improvements

- Verify script syntax passes bash -n
- Confirm all command-line options work
- Test checksum verification function
- Review documentation consistency
- All security and robustness improvements complete"
```

---

## Post-Implementation Testing Checklist

After implementation, manually test:

1. **Basic installation** with a real dorado tar.gz
2. **Clean install** flag removes and recreates environment
3. **Checksum verification** with valid and invalid .sha256 files
4. **Multiple tar.gz versions** - script selects latest
5. **Missing conda** - script errors gracefully
6. **Corrupted tar.gz** - script errors appropriately
7. **Temp directory cleanup** - no stray files after completion
8. **Standard conda layout** - dorado directly accessible in env/bin/
9. **Manual install instructions** - README steps work as documented

---

## Summary of Improvements

✅ **Security**: Tar extraction to temp directory with path validation
✅ **Simplicity**: Removed unnecessary nested structure and symlinks
✅ **Robustness**: Reliable conda path detection using JSON
✅ **Verification**: Optional SHA256 checksum support
✅ **Documentation**: Fixed all inconsistencies and removed sudo
✅ **Best Practices**: Standard conda env layout, proper cleanup, error handling
