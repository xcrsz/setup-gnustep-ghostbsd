# setup-gnustep-ghostbsd

A shell script to automate the installation and configuration of the GNUstep development environment on GhostBSD 25.01.

## Overview

The `setup-gnustep-ghostbsd.sh` script installs and configures GNUstep on GhostBSD 25.01 (based on FreeBSD 14.2-RELEASE-p3), addressing issues with the misconfigured `gnustep-make-2.9.2` package in the GhostBSD `GhostBSD_Unstable` repository. It supports both Bash and Fish shells, uses Clang 19.1.7 for compilation, and builds from the GhostBSD ports tree to ensure a functional setup.

## Key features:
- Installs GNUstep components (`gnustep-make`, `gnustep-base`, `gnustep-gui`, `gnustep-back`, `gnustep`).
- Configures environment variables (e.g., `GNUSTEP_SYSTEM_ROOT`).
- Resolves package conflicts by removing existing GNUstep packages before building.
- Uses non-interactive builds (`-DBATCH`) to avoid configuration dialogs.
- Generates a verification report summarizing installation results.
- Includes test programs to validate command-line and GUI functionality.
- Supports optional tools (`gorm`, `projectcenter`).

## Requirements

- **Operating System**: GhostBSD 25.01 (FreeBSD 14.2-RELEASE-p3 base, BSD rc init).
- **Privileges**: Root access (run with `sudo`).
- **Internet**: Required for package installation and ports cloning.
- **Disk Space**: At least 512 MB free on `/`.
- **Shells**: Bash or Fish (script configures both).
- **Compiler**: Clang 19.1.7 (provided by `llvm19` package or base system).
- **Dependencies**:
  - `libobjc2`
  - GhostBSD development tools (`GhostBSD*-dev`)
  - `llvm19`
  - `git`, `pkgconf`

## Installation

1. **Download the Script**:
   - Save `setup-gnustep-ghostbsd.sh` to your system (e.g., via `curl` or copy-paste into a text editor like `pluma`).

2. **Make Executable**:
   ```sh
   chmod +x setup-gnustep-ghostbsd.sh
   ```

    Run the Script:
    ```sh
    sudo sh ./setup-gnustep-ghostbsd.sh
    ``` 
        The script updates packages, installs dependencies, builds GNUstep from ports if needed, configures shells, runs tests, and generates a verification report.
    Verify Installation:
        For Fish shell:
        ```sh
        sudo cp /root/.config/fish/conf.d/gnustep.fish ~/.config/fish/conf.d/
        source ~/.config/fish/conf.d/gnustep.fish
        echo $GNUSTEP_SYSTEM_ROOT
        gnustep-config --objc-flags
        ```

            Expected gnustep-config output:

            -I/usr/local/GNUstep/System/Library/Headers -L/usr/local/GNUstep/System/Library/Libraries

        For Bash shell:
        ```sh
        bash
        echo $GNUSTEP_SYSTEM_ROOT
        gnustep-config --objc-flags
        ```

    Review Verification Report:
        Check the log file for the report:
        ```sh
        cat /tmp/gnustep_install_20250615_*.log | grep -A 30 "Verification Report"
        ```

        Look for [PASS]/[FAIL] statuses for packages, configuration, environment variables, tests, and optional tools.

    Test GUI Application:
    ```sh
    bash
    /tmp/gui
   ```

        Requires X11 (run startx if not active).

## Features

    Package Conflict Handling: Checks for and removes existing GNUstep packages (e.g., gnustep-make) before building from ports.
    Non-Interactive Builds: Uses -DBATCH to avoid configuration dialogs (e.g., gmake-4.4.1).
    Clang Compilation: Builds with Clang 19.1.7, eliminating GCC dependency.
    Shell Configuration: Sets up Bash (/etc/profile) and Fish (~/.config/fish/conf.d/gnustep.fish) environments.
    Verification Report: Summarizes:
        Package installation status.
        gnustep-config --objc-flags output.
        GNUSTEP_SYSTEM_ROOT environment variable.
        Test program results (hello.m, gui.m).
        Optional tools (gorm, projectcenter).
    Error Handling: Logs detailed errors to /tmp/gnustep_build_*.log and /tmp/gnustep_install_*.log.
    Ports Management: Clones GhostBSD ports tree (https://github.com/ghostbsd/ghostbsd-ports.git) and handles /usr/ports conflicts.

## Troubleshooting
If the script fails or the verification report shows [FAIL] statuses:

    Check Logs:
        Build log:
        ```sh
        cat /tmp/gnustep_build_gnustep-make.log
        ```

        Main log:
        ```sh
        cat /tmp/gnustep_install_20250615_*.log
        ```

    Verify Dependencies:
    ```sh
    pkg info | grep -E 'libobjc2|GhostBSD.*-dev|llvm'
    ```

        Ensure libobjc2, GhostBSD*-dev, and llvm19 are installed.
    Check Disk Space:
    ```sh
    df -h /
    ```

        Ensure at least 512 MB free.
    Inspect Configuration Errors:
    ```sh
    cat /usr/ports/devel/gnustep-make/work/gnustep-make-*/config.log | grep -i error
    ```

   ## Common Issues:
        Package Conflicts: The script removes conflicting packages, but manual removal may be needed:
        ```sh
        sudo pkg delete -f gnustep-make
        ```

        Empty gnustep-config Output: Indicates a misconfigured gnustep-make. The script builds from ports to resolve this.
        X11 Not Running: For GUI tests, ensure X11 is active:
        ```sh
        startx
        ps aux | grep Xorg
        ```

    ## Recovery Options (logged on error):
        Check network: ping freebsd.org
        Reinstall package: sudo pkg install -f <package>
        Reclone ports: sudo git clone https://github.com/ghostbsd/ghostbsd-ports.git /usr/ports
        Manual configuration: Set GNUSTEP_SYSTEM_ROOT in ~/.config/fish/conf.d/gnustep.fish

## Why Build from Ports?
The GhostBSD GhostBSD_Unstable repository’s gnustep-make-2.9.2 package is misconfigured, causing:

    Empty gnustep-config --objc-flags output.
    Unset GNUSTEP_SYSTEM_ROOT.
    Environment setup failures.

Building from the GhostBSD ports tree ensures a correctly configured GNUstep setup, tailored for Clang 19.1.7 and libobjc2.

## Contributing
Contributions are welcome! To contribute:

    Fork the repository.
    Create a feature branch (git checkout -b feature/new-feature).
    Commit changes (git commit -m "Add new feature").
    Push to the branch (git push origin feature/new-feature).
    Open a pull request.

Please test changes on GhostBSD 25.01 and include updates to this README if needed.

## License
This script is released under the MIT License (LICENSE). See the LICENSE file for details.

## Contact
For issues or questions, open an issue on the GitHub repository or contact the maintainer at [your-email@example.com (mailto:your-email@example.com)] (replace with actual contact if applicable).


