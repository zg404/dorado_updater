#!/bin/bash

# Set -e to exit immediately if a command exits with a non-zero status.
# Set -u to treat unset variables as an error.
# Add -o pipefail to ensure pipes fail if any command fails
set -euo pipefail

# Terminal color definitions - with fallback for terminals that don't support color
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'   
  BOLD='\033[1m'
  NC='\033[0m'
else
  # No color if not in a terminal
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''   
  BOLD=''
  NC=''
fi

# Print help message
function show_help {
  echo "Usage: $0 [--clean-install]"
  echo ""
  echo "Options:"
  echo "  --clean-install    Remove existing Dorado environment and create a new one"
  echo "  --verify-checksum  Verify SHA256 checksum before installation"
  echo "  --help             Show this help message"
}

# Process command line arguments
clean_install=0
verify_checksum=0
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

# --- Conda environment setup and checks ---

# Find the conda executable - check both conda and mamba
if command -v conda >/dev/null 2>&1; then
  conda_path=$(command -v conda)
  conda_cmd="conda"
elif command -v mamba >/dev/null 2>&1; then
  conda_path=$(command -v mamba)
  conda_cmd="mamba"  # mamba is a faster drop-in replacement for conda
else
  echo -e "${RED}Error: Neither conda nor mamba executable found. Please ensure Conda is installed and in your PATH.${NC}"
  exit 1
fi
echo -e "${CYAN}Using ${conda_cmd} at: ${conda_path}${NC}"

# Check for jq for JSON parsing
if command -v jq >/dev/null 2>&1; then
  USE_JQ=1
  echo -e "${CYAN}Using jq for reliable conda path detection${NC}"
else
  USE_JQ=0
  echo -e "${YELLOW}Warning: jq not found. Using fallback path detection.${NC}"
fi

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

# Find all dorado tar.gz files and sort by version number
# Use nullglob to avoid errors if no files match
shopt -s nullglob
dorado_files=(./dorado-[0-9]*.[0-9]*.[0-9]*-linux-x64.tar.gz)
shopt -u nullglob
dorado_count=${#dorado_files[@]}

# Check if any tar.gz files were found
if [ $dorado_count -eq 0 ]; then
  echo -e "${RED}Error: Dorado tar.gz file not found.${NC}"
  echo -e "Please download the appropriate ${YELLOW}Linux-x64${NC} release from:"
  echo -e "${CYAN}https://github.com/nanoporetech/dorado?tab=readme-ov-file#installation${NC}"
  echo -e "Place the downloaded .tar.gz file in the same directory as this script and run the script again."
  exit 1
fi

# Get the latest version by sorting the array
IFS=$'\n' sorted_files=($(sort -V <<<"${dorado_files[*]}"))
unset IFS
dorado_targz="${sorted_files[-1]}"

# Note: Using temp directory, no need to check for existing extracted folder

# Warn if multiple versions were found
if [ "$dorado_count" -gt 1 ]; then
  echo -e "${YELLOW}WARNING: Multiple Dorado package versions detected. Using the latest version: ${BOLD}$(basename "$dorado_targz")${NC}"
  echo -e "Consider removing older versions to avoid confusion:"
  for ((i=0; i<$dorado_count-1; i++)); do
    echo -e "    ${sorted_files[$i]}"
  done
  echo ""
fi

# Verify checksum if requested
if [ "$verify_checksum" -eq 1 ]; then
  verify_checksum "$dorado_targz" || {
    echo -e "${RED}Error: Checksum verification failed. Installation aborted.${NC}"
    exit 1
  }
fi

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

# Handle clean install if requested
if [ "$clean_install" -eq 1 ] && [ "$env_exists" -eq 1 ]; then
  echo -e "${CYAN}Removing existing Dorado environment...${NC}"
  $conda_cmd remove -n dorado --all -y || {
    echo -e "${YELLOW}Warning: Failed to remove environment with conda command. Attempting manual removal...${NC}"
    # Fallback: manually remove the directory if conda command fails
    if [ -n "$dorado_env" ] && [ -d "$dorado_env" ]; then
      rm -rf "$dorado_env"
    fi
  }
  env_exists=0
fi

# Create environment if it doesn't exist or was removed
if [ "$env_exists" -eq 0 ]; then
  echo -e "${CYAN}Creating new Dorado environment...${NC}"
  $conda_cmd create -y -n dorado pip -c bioconda samtools
  
  # Verify environment was created
  if ! $conda_cmd env list | grep -q "dorado"; then
    echo -e "${RED}ERROR: Conda Env 'dorado' creation failed.${NC}"
    exit 1
  fi
  
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

# Verify we have a valid environment path
if [ -z "$dorado_env" ] || [ ! -d "$dorado_env" ]; then
  echo -e "${RED}ERROR: Could not determine Dorado environment path.${NC}"
  exit 1
fi

# Extract the tar.gz file securely to temp directory
echo -e "${CYAN}Extracting Dorado package: ${BOLD}$dorado_targz${NC}"

# Use --strip-components=1 to remove top-level directory and prevent path traversal
# Extract to temp_dir to avoid cluttering working directory
if ! tar -xf "$dorado_targz" --strip-components=1 -C "$temp_dir"; then
  echo -e "${RED}Error: Failed to extract tar.gz file.${NC}"
  exit 1
fi

# Point dorado_folder to temp extraction directory
dorado_folder="$temp_dir"

# --- Binary update process ---

# Define paths to the bin and lib directories in the environment.
env_bin="$dorado_env/bin"
env_lib="$dorado_env/lib"

# Create necessary directory structure
echo -e "${CYAN}Setting up directory structure...${NC}"
mkdir -p "$dorado_env/bin" "$dorado_env/lib"

# Clean up existing files if they exist (preserve conda-managed files)
echo -e "${CYAN}Cleaning up existing Dorado binaries...${NC}"
shopt -s nullglob
# Remove dorado and its dependencies from env/bin
for f in "$env_bin"/dorado*; do
  rm -f "$f"
done
# Remove dorado-related libraries from env/lib
if [ -d "$env_lib" ]; then
  for f in "$env_lib"/libdorado*; do
    rm -f "$f"
  done
fi
shopt -u nullglob
 
# Verify source directories exist before copying
if [ ! -d "$dorado_folder/bin" ] || [ ! -d "$dorado_folder/lib" ]; then
  echo -e "${RED}Error: Required directories not found in extracted package.${NC}"
  echo -e "${RED}Expected: $dorado_folder/bin and $dorado_folder/lib${NC}"
  exit 1
fi

# Copy the new binaries and libraries
echo -e "${CYAN}Copying new Dorado binaries...${NC}"
cp -rf "$dorado_folder/bin/"* "$dorado_env/bin/" || {
  echo -e "${RED}Error: Failed to copy bin directory.${NC}"
  exit 1
}
cp -rf "$dorado_folder/lib/"* "$dorado_env/lib/" || {
  echo -e "${RED}Error: Failed to copy lib directory.${NC}"
  exit 1
}

# Verify the dorado executable is accessible (now directly in env/bin)
if [ ! -x "$env_bin/dorado" ]; then
  echo -e "${RED}Error: Dorado executable not found at $env_bin/dorado${NC}"
  exit 1
fi
echo -e "${GREEN}Dorado binary installed to: $env_bin/dorado${NC}"

# --- Cleanup ---
# Note: trap cleanup_temp EXIT handles temp dir cleanup automatically

# --- Verification ---
echo -e "${GREEN}Dorado update completed successfully!${NC}"
echo ""
echo -e "${BOLD}To verify the installation, please run the following command:${NC}"
echo -e "  ${CYAN}conda run -n dorado dorado --version${NC}"
echo ""
echo -e "If the 'dorado --version' command shows the expected version number, the update was successful."

exit 0
