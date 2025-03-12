# Dorado Updater

A simple bash script to streamline the installation and updating of Oxford Nanopore's Dorado software on Linux systems.

## Overview

The goal of this tool is to make updating Dorado easier by overcoming some quirks in its binary packaging. The primary challenge is avoiding having to update the user's `$PATH` after each update. This script implements a workaround using a static `bin/` location already in the `$PATH` (via conda) along with an unchanging symlink that points to the nested `bin/` that contains the actual Dorado binaries.
Correct file structure will look like this:
```
~/miniconda3/envs/dorado/bin/
├── bin
│   └── dorado
├── lib
│   └── [bunch of files]
├── dorado -> ~/miniconda3/envs/dorado/bin/bin/dorado (symlink)
└── [bunch of files]
```
## Requirements

- Linux x64 system (WSL2 supported)
- Working conda installation (Miniconda, Miniforge, or Anaconda)
- Download the latest Dorado Linux-x64 package: [dorado-X.X.X-linux-x64.tar.gz](https://github.com/nanoporetech/dorado?tab=readme-ov-file#installation)

## Usage

1. Download a Dorado release package from the [official GitHub repository](https://github.com/nanoporetech/dorado?tab=readme-ov-file#installation)
   - Make sure to download the Linux-x64 version; do not extract the tar.gz
   
2. Clone this repository or download the update_dorado.sh script
```bash
wget https://raw.githubusercontent.com/zg404/dorado-updater/main/update_dorado.sh
```

3. Make the script executable:
   ```bash
   chmod +x update_dorado.sh
   ```

4. Run the script in the same directory as the Dorado tar.gz file. Optional: add "--clean-install" to remove the existing Dorado environment and create a new one:
   ```bash
   ./update_dorado.sh [--clean-install]
   ```

5. After successful installation, verify it works:
   ```bash
   conda activate dorado
   dorado --version
   conda deactivate
   ```



## Design Rationale

1. Uses conda's `bin/` directory that is already in `$PATH`. This provides a failsafe way to ensure wide portability across different Linux machines.

2. Handles Dorado's pre-compiled binaries which include their own `bin/` and `lib/` directories. This would normally require adding the nested `bin/` to `$PATH` (e.g., `~/miniconda/envs/dorado/bin/bin`).

3. Creates a symlink in the conda env `bin/` that points to the dorado binary in the nested `bin/`, allowing the command to be called directly after conda activation.

4. Covers edge cases such as multiple Dorado versions, missing conda, and incorrect file structures.



## Command Line Options

- `--clean-install`: Removes existing Dorado environment and creates a new one
- `--help`: Displays usage information

## Troubleshooting

If you encounter errors, it may be best to delete the old conda dorado environment and start fresh:

1. Either manually delete the env folder (located in `~/miniconda/env/dorado`)
2. Or run the script with the clean install option:
   ```bash
   ./update_dorado.sh --clean-install
   ```

Common issues:
- If you see permission errors, ensure you have write access to your conda installation
- If conda cannot be found, ensure it's properly installed and in your PATH
- If the dorado executable isn't found after installation, try the clean install option

## License

See the LICENSE file for details.