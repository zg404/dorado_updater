# Dorado Updater

A bash script to streamline the installation and updating of Oxford Nanopore's Dorado software on Linux systems.

> [!NOTE]
> This script is intended for users who may be unfamiliar with Linux or prefer a straightforward install and update for Dorado. However, the manual process is not difficult and can be done in a few steps. I highly encourage users to learn the process and be more comfortable with the command line: [Manual Installation](#manual-installation). You might find you don't need this script!

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
wget https://raw.githubusercontent.com/zg404/dorado_updater/refs/heads/main/update_dorado.sh
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
   conda run -n dorado dorado --version
   ```
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

## Design Rationale

1. Uses a conda env `bin/` to avoid messing with the user `$PATH`. This provides a failsafe way to ensure wide portability across different Linux machines. Containing the Dorado binaries in a conda env also mitigates the risk of conflicts with other system files.

2. Handles Dorado's pre-compiled binaries structure, which includes`bin/` and `lib/` directories. This would normally require adding the nested `bin/` to `$PATH` (e.g., `~/miniconda/envs/dorado/bin/bin`).

3. Creates a symlink in the root of the conda env `bin/` that points to the dorado binary in the nested `bin/`, allowing the command to be called directly after conda activation.

4. Covers edge cases such as multiple Dorado versions, missing conda, and incorrect file structures.

5. Conda env includes samtools, which is commonly needed for the `.bam` output from Dorado.

## Manual Installation
### Traditional Method
If you prefer to forgo Conda, it will allow you to run Dorado without activating an environment. Follow these steps:
1. Download and extract the Dorado tar.gz file in a location of your choice, then navigate to the extracted folder.
```bash
tar -xvf dorado-X.X.X-linux-x64.tar.gz
cd dorado-X.X.X-linux-x64/
```
2. Copy the extracted `bin/` and `lib/` directories to a location in your `$PATH`. In most Linux distros, this should be: `~/.local/bin`
```bash
cp -r ./bin/ ./lib/ $HOME/.local/bin
```
3. Create a symlink in the same location that points to the dorado binary in the nested `bin/` directory. 
 ```bash
 ln -s $HOME/.local/bin/bin/dorado $HOME/.local/bin/dorado
 ```
4. Run `dorado --version` to verify the installation
5. To update Dorado, delete the old `~/.local/bin/bin/` and `~/.local/lib/` directories and repeat the process with the new version.
```bash
rm -rf $HOME/.local/bin/bin/ $HOME/.local/bin/lib/
```

### Conda Method
Installing Dorado in a new or existing conda environment can be useful if you need other tools, like pod5 or samtools. Follow these steps:
1. Extract the Dorado tar.gz file in a location of your choice, then navigate to the extracted folder.
   ```bash
      tar -xvf dorado-X.X.X-linux-x64.tar.gz
      cd dorado-X.X.X-linux-x64/
   ```
2. Create a new conda environment, with samtools and pod5 toolkit:
   ```bash
   conda create -n dorado pip -c bioconda samtools
   # optionally install pod5 toolkit
   conda run -n dorado pip install pod5
   ```

2. Copy the extracted `bin/` and `lib/` directories to the new or existing Conda env, found in: `~/miniconda3/envs/`
```bash
sudo cp -r ./bin/ ./lib/ ~/miniconda3/envs/dorado/
```
3. Create a symlink in the same location that points to the dorado binary in the nested `bin/` directory. 
 ```bash
 ln -s ~/miniconda3/envs/dorado/bin/bin/dorado ~/miniconda3/envs/dorado/bin/dorado
 ```
4. Verify the installation
```bash
conda run -n dorado dorado --version
```
5. To update Dorado, delete the old `~/miniconda3/envs/dorado/bin/bin/` and `~/miniconda3/envs/dorado/lib/` directories and repeat the process with the new version.
```bash
rm -rf ~/miniconda3/envs/dorado/bin/bin/ ~/miniconda3/envs/dorado/lib/
```


## License

See the LICENSE file for details.
