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
  echo "  --help             Show this help message"
}

# Process command line arguments
clean_install=0
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

# Extract the conda base directory robustly.
conda_base=$(dirname "$(dirname "$conda_path")")
if [ ! -d "$conda_base" ]; then
    echo -e "${RED}Error: Could not determine Conda base directory. Expected directory structure not found.${NC}"
    exit 1
fi

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

# Get the expected folder name from the tar file name
dorado_folder=$(basename "$dorado_targz" .tar.gz)

# Check if the folder already exists (from previous extraction)
if [ -d "$dorado_folder" ]; then
  echo -e "${YELLOW}Found existing extracted folder: ${BOLD}$dorado_folder${NC}"
  echo -e "${CYAN}Removing old extracted folder to ensure clean contents...${NC}"
  rm -rf "$dorado_folder"
fi

# Warn if multiple versions were found
if [ "$dorado_count" -gt 1 ]; then
  echo -e "${YELLOW}WARNING: Multiple Dorado package versions detected. Using the latest version: ${BOLD}$(basename "$dorado_targz")${NC}"
  echo -e "Consider removing older versions to avoid confusion:"
  for ((i=0; i<$dorado_count-1; i++)); do
    echo -e "    ${sorted_files[$i]}"
  done
  echo ""
fi

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
  dorado_env=$($conda_cmd env list | grep "dorado" | awk '{print $NF}')
  if [ -z "$dorado_env" ]; then
    dorado_env=$(find "$conda_base/envs/" -type d -iname "dorado" -print -quit)
  fi
else
  echo -e "${CYAN}Dorado environment found at: ${BOLD}$dorado_env${NC}"
fi

# Verify we have a valid environment path
if [ -z "$dorado_env" ] || [ ! -d "$dorado_env" ]; then
  echo -e "${RED}ERROR: Could not determine Dorado environment path.${NC}"
  exit 1
fi

# Extract the tar.gz file.  Use a subshell to avoid changing the CWD of the main script.
(
  echo -e "${CYAN}Extracting Dorado package: ${BOLD}$dorado_targz${NC}"
  if ! tar -xf "$dorado_targz"; then
    echo -e "${RED}Error: Failed to extract tar.gz file.${NC}"
    exit 1 
  fi
) 

# Get extracted folder name - verify it exists
dorado_folder=$(basename "$dorado_targz" .tar.gz)
if [ ! -d "$dorado_folder" ]; then
  echo -e "${RED}Error: Expected folder $dorado_folder not found after extraction.${NC}"
  exit 1
fi

# --- Binary update process ---

# Define paths to the nested bin and lib directories in the environment.
env_bin="$dorado_env/bin/bin"
env_lib="$dorado_env/bin/lib"

# Create necessary directory structure
echo -e "${CYAN}Setting up directory structure...${NC}"
mkdir -p "$dorado_env/bin/bin" "$dorado_env/bin/lib"

# Clean up existing files if they exist
echo -e "${CYAN}Cleaning up existing Dorado binaries...${NC}"
if [ -d "$env_bin" ]; then
  find "$env_bin" -mindepth 1 -maxdepth 1 ! -lname '*' -delete 2>/dev/null || true
fi

if [ -d "$env_lib" ]; then
  find "$env_lib" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
fi
 
# Verify source directories exist before copying
if [ ! -d "$dorado_folder/bin" ] || [ ! -d "$dorado_folder/lib" ]; then
  echo -e "${RED}Error: Required directories not found in extracted package.${NC}"
  echo -e "${RED}Expected: $dorado_folder/bin and $dorado_folder/lib${NC}"
  exit 1
fi

# Copy the new binaries and libraries
echo -e "${CYAN}Copying new Dorado binaries...${NC}"
cp -r "$dorado_folder/bin/"* "$dorado_env/bin/bin/" || { 
  echo -e "${RED}Error: Failed to copy bin directory.${NC}" 
  exit 1
}
cp -r "$dorado_folder/lib/"* "$dorado_env/bin/lib/" || { 
  echo -e "${RED}Error: Failed to copy lib directory.${NC}" 
  exit 1
}

# Verify the dorado executable exists after copying
if [ ! -f "$env_bin/dorado" ]; then
  echo -e "${RED}Error: Dorado executable not found after installation.${NC}"
  exit 1
fi

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

# --- Cleanup ---
rm -rf "$dorado_folder" # remove extracted folder

# --- Verification ---
echo -e "${GREEN}Dorado update completed successfully!${NC}"
echo ""
echo -e "${BOLD}To verify the installation, please run the following command:${NC}"
echo -e "  ${CYAN}conda run -n dorado dorado --version${NC}"
echo ""
echo -e "If the 'dorado --version' command shows the expected version number, the update was successful."

exit 0
