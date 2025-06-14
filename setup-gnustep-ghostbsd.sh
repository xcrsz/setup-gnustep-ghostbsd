#!/bin/sh

# Script: setup-gnustep-ghostbsd.sh
# Purpose: Install GNUstep development environment on GhostBSD 25.01
# Version: 0.01
# Date: June 15, 2025
# Requirements: GhostBSD 25.01 (FreeBSD 14.0 base, BSD rc init), root privileges, internet access
# Notes: Configures for both Bash and Fish shells before GNUstep verification, uses GhostBSD ports, builds with Clang, non-interactive, checks and removes existing gnustep-make package, includes verification report

# Exit on error
set -e

# Log file
LOGFILE="/tmp/gnustep_install_$(date +%Y%m%d_%H%M%S).log"
echo "GNUstep Installation Log" > "$LOGFILE"
echo "Date: $(date)" >> "$LOGFILE"
echo "System: $(uname -sr)" >> "$LOGFILE"
echo "Init System: BSD rc" >> "$LOGFILE"
echo "------------------------" >> "$LOGFILE"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOGFILE"
}

# Function to show spinner during long-running commands
show_spinner() {
    msg="$1"
    pid=$2
    i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        case $i in
            0) char="|" ;;
            1) char="/" ;;
            2) char="-" ;;
            3) char="\\" ;;
        esac
        printf "\r%s %s" "$msg" "$char" >&2
        sleep 0.1
    done
    printf "\r%s Done\n" "$msg" >&2
}

# Function to run command with spinner and timeout
run_with_spinner() {
    cmd="$1"
    msg="$2"
    timeout="$3" # Timeout in seconds
    log "Starting: $msg"
    ( sh -c "$cmd" >> "$LOGFILE" 2>&1 ) &
    cmd_pid=$!
    show_spinner "$msg" "$cmd_pid" >&2
    # Wait with timeout
    ( sleep $timeout && if kill -0 "$cmd_pid" 2>/dev/null; then kill "$cmd_pid"; log "ERROR: $msg timed out after $timeout seconds"; fi ) &
    timeout_pid=$!
    wait "$cmd_pid" 2>/dev/null
    status=$?
    kill "$timeout_pid" 2>/dev/null
    wait "$timeout_pid" 2>/dev/null
    if [ $status -ne 0 ]; then
        return 1
    fi
    return 0
}

# Function to log error and exit
error_exit() {
    log "ERROR: $1"
    log "See $LOGFILE for details."
    log "Recovery options:"
    log "- Check network: ping freebsd.org"
    log "- Check disk space: df -h"
    log "- Reinstall package: sudo pkg install -f <package>"
    log "- Use GhostBSD ports: sudo git clone https://github.com/ghostbsd/ghostbsd-ports.git /usr/ports"
    log "- Manual config: Set GNUSTEP_SYSTEM_ROOT, PATH, etc., in ~/.config/fish/conf.d/gnustep.fish"
    generate_verification_report
    exit 1
}

# Function to check command success with detailed output
check_status() {
    cmd="$1"
    msg="$2"
    timeout="${3:-5}" # Default timeout 5 seconds
    err_file="/tmp/gnustep_err_$$.txt"
    if ! run_with_spinner "$cmd" "$msg" "$timeout"; then
        log "ERROR: $msg"
        log "Command: $cmd"
        log "Error output:"
        cat "$err_file" >> "$LOGFILE" 2>/dev/null
        rm -f "$err_file"
        error_exit "$msg"
    fi
    rm -f "$err_file"
}

# Function to check file existence
check_file() {
    file="$1"
    msg="$2"
    if [ ! -f "$file" ]; then
        error_exit "$msg: $file not found"
    fi
}

# Function to check command existence
check_command() {
    cmd="$1"
    msg="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_exit "$msg: $cmd not found"
    fi
}

# Function to check network connectivity
check_network() {
    log "Checking network connectivity..."
    if ! ping -c 1 freebsd.org >/dev/null 2>&1; then
        error_exit "No network connectivity. Please ensure internet access."
    fi
    log "Network connectivity confirmed."
}

# Function to check disk space
check_disk() {
    log "Checking disk space..."
    avail=$(df -k / | tail -1 | awk '{print $4}')
    if [ "$avail" -lt 524288 ]; then # 512 MB in KB
        error_exit "Insufficient disk space on /. Need at least 512 MB."
    fi
    log "Disk space sufficient."
}

# Function to clear /usr/ports directory
clear_ports_dir() {
    log "Clearing /usr/ports directory..."
    if [ -d /usr/ports ]; then
        # Check for mounts
        if mount | grep -q /usr/ports; then
            log "WARNING: /usr/ports is a mount point. Attempting to unmount..."
            umount /usr/ports 2>> "$LOGFILE" || error_exit "Failed to unmount /usr/ports"
        fi
        # Check for processes
        if lsof /usr/ports >/dev/null 2>&1; then
            log "WARNING: Processes using /usr/ports detected. Terminating..."
            lsof /usr/ports | awk 'NR>1 {print $2}' | xargs kill 2>> "$LOGFILE" || log "WARNING: Failed to terminate all processes"
            sleep 2
        fi
        # Remove directory
        rm -rf /usr/ports 2>> "$LOGFILE" || error_exit "Failed to remove /usr/ports: Device busy. Try rebooting or manually unmounting."
    fi
    mkdir -p /usr/ports || error_exit "Failed to create /usr/ports"
}

# Function to check port dependencies
check_port_deps() {
    pkg="$1"
    log "Checking dependencies for $pkg..."
    if ! pkg_info=$(pkg info -e 'libobjc2|GhostBSD.*-dev|llvm19' 2>> "$LOGFILE"); then
        log "WARNING: Required dependencies (libobjc2, GhostBSD*-dev, llvm19) not fully installed."
        check_status "pkg install -y -g 'GhostBSD*-dev' libobjc2 llvm19" "Installing required dependencies..." 300
    fi
    log "Dependencies satisfied."
}

# Function to remove existing GNUstep packages
remove_existing_gnustep() {
    log "Checking for existing GNUstep packages..."
    if pkg_info=$(pkg info -e 'gnustep.*' 2>> "$LOGFILE"); then
        log "Removing existing GNUstep packages to avoid conflicts..."
        check_status "pkg delete -f -y gnustep gnustep-make gnustep-base gnustep-gui gnustep-back" "Removing existing GNUstep packages..." 60
    fi
    log "No conflicting GNUstep packages found or successfully removed."
}

# Function to generate verification report
generate_verification_report() {
    log "------------------------"
    log "GNUstep Installation Verification Report"
    log "------------------------"
    
    # Check GNUstep packages
    log "1. GNUstep Packages Status:"
    for pkg in gnustep-make gnustep-base gnustep-gui gnustep-back gnustep; do
        if pkg info -e "$pkg" >/dev/null 2>&1; then
            version=$(pkg info "$pkg" | grep Version | awk '{print $3}')
            log "   - $pkg: Installed (Version $version) [PASS]"
        else
            log "   - $pkg: Not installed [FAIL]"
        fi
    done

    # Check gnustep-config
    log "2. GNUstep Configuration Status:"
    if gnustep_config_output=$(gnustep-config --objc-flags 2>/dev/null); then
        if echo "$gnustep_config_output" | grep -q "-I"; then
            log "   - gnustep-config --objc-flags: Valid output ($gnustep_config_output) [PASS]"
        else
            log "   - gnustep-config --objc-flags: Empty or invalid output [FAIL]"
        fi
    else
        log "   - gnustep-config --objc-flags: Command failed [FAIL]"
    fi

    # Check GNUSTEP_SYSTEM_ROOT
    log "3. Environment Variable Status:"
    if [ -n "$GNUSTEP_SYSTEM_ROOT" ]; then
        log "   - GNUSTEP_SYSTEM_ROOT: Set to $GNUSTEP_SYSTEM_ROOT [PASS]"
    else
        log "   - GNUSTEP_SYSTEM_ROOT: Not set [FAIL]"
    fi

    # Check test programs
    log "4. Test Programs Status:"
    if [ -f "/tmp/hello" ]; then
        if /tmp/hello 2>/dev/null | grep -q "Hello, GhostBSD!"; then
            log "   - Command-line test (hello.m): Compiled and ran successfully [PASS]"
        else
            log "   - Command-line test (hello.m): Compiled but failed to run [FAIL]"
        fi
    else
        log "   - Command-line test (hello.m): Not compiled [FAIL]"
    fi
    if [ -f "/tmp/gui" ]; then
        log "   - GUI test (gui.m): Compiled successfully [PASS]"
        log "     Note: Run '/tmp/gui' manually to verify GUI (requires X11)."
    else
        log "   - GUI test (gui.m): Not compiled [FAIL]"
    fi

    # Check optional tools
    log "5. Optional Tools Status:"
    for tool in gorm projectcenter; do
        if command -v "$tool" >/dev/null 2>&1; then
            log "   - $tool: Installed [PASS]"
        else
            log "   - $tool: Not installed [FAIL]"
        fi
    done

    log "------------------------"
    log "Verification report saved to $LOGFILE"
    log "Please review the report for any [FAIL] statuses and check recovery options if needed."
}

# Function to install from GhostBSD ports with detailed error handling
install_from_ports() {
    pkg="$1"
    port_path="$2"
    build_log="/tmp/gnustep_build_${pkg}.log"
    log "Attempting to install $pkg from GhostBSD ports ($port_path)..."
    check_command git "Git not installed for ports"
    check_port_deps "$pkg"
    # Check for existing package and remove it
    if pkg info -e "$pkg" >/dev/null 2>&1; then
        log "Existing $pkg package found. Removing to avoid conflicts..."
        check_status "pkg delete -f -y $pkg" "Removing existing $pkg package..." 60
    fi
    clear_ports_dir
    check_status "git clone https://github.com/ghostbsd/ghostbsd-ports.git /usr/ports" "Cloning GhostBSD ports tree..." 60
    if [ ! -d "/usr/ports/$port_path" ]; then
        error_exit "Ports path /usr/ports/$port_path not found"
    fi
    log "Building $pkg non-interactively. Detailed log at $build_log..."
    if ! run_with_spinner "cd /usr/ports/$port_path && make -DBATCH install clean > $build_log 2>&1" "Building $pkg from ports..." 7200; then
        log "ERROR: Failed to build $pkg. Checking log for details..."
        tail -n 20 "$build_log" >> "$LOGFILE"
        error_exit "Failed to build $pkg. See $build_log for details."
    fi
    log "$pkg build completed successfully."
}

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    error_exit "This script must be run with sudo (e.g., sudo sh $0)"
fi

# Check for GhostBSD
if ! uname -sr | grep -q "GhostBSD"; then
    log "WARNING: This script is designed for GhostBSD. Proceed at your own risk."
    printf "Continue? [y/N]: "
    read response
    case "$response" in
        [yY]*) ;;
        *) log "Aborting."; exit 1 ;;
    esac
fi

# Check X11 for GUI support
log "Checking X11 for GUI support..."
if ! ps aux | grep -q "[X]org"; then
    log "WARNING: X11 not running. GUI applications may fail."
fi

# Check network and disk
check_network
check_disk

# Step 1: Update system
log "Updating package repositories..."
check_status "pkg update" "Updating package repositories..." 60
log "Upgrading packages..."
check_status "pkg upgrade -y" "Upgrading packages..." 300

# Step 2: Install text editor (Pluma is default, install Vim as option)
log "Checking for Pluma..."
if ! command -v pluma >/dev/null 2>&1; then
    log "Installing Pluma..."
    check_status "pkg install -y pluma" "Installing Pluma..." 60
else
    log "Pluma already installed."
fi
log "Installing Vim (optional)..."
check_status "pkg install -y vim" "Installing Vim..." 60
check_command pluma "Pluma installation failed"
check_command vim "Vim installation failed"

# Step 3: Verify Clang
log "Verifying Clang..."
check_command clang "Clang not found. Ensure llvm or base system Clang is installed"
log "Clang installed: $(clang --version | head -n 1)"

# Step 4: Install libobjc2
log "Installing libobjc2..."
if ! run_with_spinner "pkg install -y libobjc2" "Installing libobjc2..." 60; then
    log "WARNING: libobjc2 installation failed. Retrying..."
    check_status "pkg clean && pkg update && pkg install -y libobjc2" "Retrying libobjc2 installation..." 120
fi
log "Verifying libobjc2..."
check_status "pkg info libobjc2" "Verifying libobjc2..." 10
if [ ! -f /usr/local/lib/libobjc.so ]; then
    error_exit "libobjc2 library not found in /usr/local/lib"
fi

# Step 5: Install development tools for ports
log "Installing development tools for ports..."
check_status "pkg install -y -g 'GhostBSD*-dev' llvm19" "Installing GhostBSD development tools..." 120

# Step 6: Install GNUstep and configure shell environment
log "Installing GNUstep components..."
remove_existing_gnustep
if ! run_with_spinner "pkg install -y gnustep gnustep-make gnustep-base gnustep-gui gnustep-back" "Installing GNUstep components..." 120; then
    log "WARNING: GNUstep installation failed. Forcing GhostBSD ports rebuild..."
    install_from_ports "gnustep-make" "devel/gnustep-make"
    install_from_ports "gnustep-base" "lang/gnustep-base"
    install_from_ports "gnustep-gui" "x11-toolkits/gnustep-gui"
    install_from_ports "gnustep-back" "x11-toolkits/gnustep-back"
    install_from_ports "gnustep" "lang/gnustep"
fi

# Configure Bash environment
log "Configuring GNUstep environment for Bash..."
if [ ! -f "/usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh" ]; then
    log "WARNING: GNUstep.sh missing. Forcing GhostBSD ports rebuild..."
    install_from_ports "gnustep-make" "devel/gnustep-make"
    install_from_ports "gnustep-base" "lang/gnustep-base"
    install_from_ports "gnustep-gui" "x11-toolkits/gnustep-gui"
    install_from_ports "gnustep-back" "x11-toolkits/gnustep-back"
    install_from_ports "gnustep" "lang/gnustep"
fi
check_file /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh "GNUstep.sh missing after rebuild"
if ! grep -q "GNUSTEP_SYSTEM_ROOT" /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh; then
    log "WARNING: GNUstep.sh does not set GNUSTEP_SYSTEM_ROOT. Setting manually..."
    echo "export GNUSTEP_SYSTEM_ROOT=/usr/local/GNUstep/System" >> /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
fi
if ! grep -q "GNUstep.sh" /etc/profile; then
    echo "source /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh" >> /etc/profile
    check_status "echo 'source /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh' >> /etc/profile" "Configuring /etc/profile..." 10
    log "Added GNUstep.sh to /etc/profile"
else
    log "GNUstep.sh already in /etc/profile"
fi
if ! . /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh; then
    log "WARNING: Failed to source GNUstep.sh. Forcing GhostBSD ports rebuild..."
    install_from_ports "gnustep-make" "devel/gnustep-make"
    install_from_ports "gnustep-base" "lang/gnustep-base"
    install_from_ports "gnustep-gui" "x11-toolkits/gnustep-gui"
    install_from_ports "gnustep-back" "x11-toolkits/gnustep-back"
    install_from_ports "gnustep" "lang/gnustep"
    . /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
fi
log "Verifying GNUSTEP_SYSTEM_ROOT for Bash..."
if [ -z "$GNUSTEP_SYSTEM_ROOT" ]; then
    log "WARNING: GNUSTEP_SYSTEM_ROOT not set. Setting manually and forcing ports rebuild..."
    export GNUSTEP_SYSTEM_ROOT=/usr/local/GNUstep/System
    export PATH=$GNUSTEP_SYSTEM_ROOT/Tools:$PATH
    export LD_LIBRARY_PATH=$GNUSTEP_SYSTEM_ROOT/Libraries:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$GNUSTEP_SYSTEM_ROOT/Libraries:$LIBRARY_PATH
    export CPATH=$GNUSTEP_SYSTEM_ROOT/Headers:$CPATH
    export MANPATH=$GNUSTEP_SYSTEM_ROOT/Documentation/man:$MANPATH
    export GNUSTEP_MAKEFILES=$GNUSTEP_SYSTEM_ROOT/Library/Makefiles
    install_from_ports "gnustep-make" "devel/gnustep-make"
    install_from_ports "gnustep-base" "lang/gnustep-base"
    install_from_ports "gnustep-gui" "x11-toolkits/gnustep-gui"
    install_from_ports "gnustep-back" "x11-toolkits/gnustep-back"
    install_from_ports "gnustep" "lang/gnustep"
    . /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
    if [ -z "$GNUSTEP_SYSTEM_ROOT" ]; then
        error_exit "GNUSTEP_SYSTEM_ROOT not set for Bash after rebuild"
    fi
fi
log "GNUSTEP_SYSTEM_ROOT: $GNUSTEP_SYSTEM_ROOT"

# Configure Fish environment
log "Configuring GNUstep environment for Fish..."
FISH_CONFIG="/root/.config/fish/conf.d/gnustep.fish"
mkdir -p /root/.config/fish/conf.d || error_exit "Failed to create Fish config directory"
cat << EOF > "$FISH_CONFIG"
set -gx GNUSTEP_SYSTEM_ROOT /usr/local/GNUstep/System
set -gx PATH \$GNUSTEP_SYSTEM_ROOT/Tools \$PATH
set -gx LD_LIBRARY_PATH \$GNUSTEP_SYSTEM_ROOT/Libraries \$LD_LIBRARY_PATH
set -gx LIBRARY_PATH \$GNUSTEP_SYSTEM_ROOT/Libraries \$LIBRARY_PATH
set -gx CPATH \$GNUSTEP_SYSTEM_ROOT/Headers \$CPATH
set -gx MANPATH \$GNUSTEP_SYSTEM_ROOT/Documentation/man \$MANPATH
set -gx GNUSTEP_MAKEFILES \$GNUSTEP_SYSTEM_ROOT/Library/Makefiles
EOF
check_file "$FISH_CONFIG" "Failed to create Fish configuration"
log "Fish configuration created at $FISH_CONFIG"
log "Note: For non-root users, copy $FISH_CONFIG to ~/.config/fish/conf.d/ and source it."

# Set PATH and GNUSTEP_MAKEFILES for verification
PATH="$PATH:/usr/local/GNUstep/System/Tools"
GNUSTEP_MAKEFILES="/usr/local/GNUstep/System/Library/Makefiles"
export PATH GNUSTEP_MAKEFILES
check_command gnustep-config "GNUstep installation failed"
log "Verifying GNUstep configuration..."
check_file /usr/local/GNUstep/System/Library/Headers/Foundation/NSString.h "GNUstep Foundation headers missing"
# Check gnustep-config output
gnustep_config_output="/tmp/gnustep_config_output.txt"
if ! run_with_spinner "gnustep-config --objc-flags > $gnustep_config_output 2>> $LOGFILE" "Checking gnustep-config output..." 10; then
    log "WARNING: gnustep-config --objc-flags failed. Forcing GhostBSD ports rebuild..."
    install_from_ports "gnustep-make" "devel/gnustep-make"
    install_from_ports "gnustep-base" "lang/gnustep-base"
    install_from_ports "gnustep-gui" "x11-toolkits/gnustep-gui"
    install_from_ports "gnustep-back" "x11-toolkits/gnustep-back"
    install_from_ports "gnustep" "lang/gnustep"
    gnustep-config --objc-flags > "$gnustep_config_output" 2>> "$LOGFILE"
fi
if ! grep -q "-I" "$gnustep_config_output"; then
    log "WARNING: gnustep-config --objc-flags returned empty output. Forcing GhostBSD ports rebuild..."
    install_from_ports "gnustep-make" "devel/gnustep-make"
    install_from_ports "gnustep-base" "lang/gnustep-base"
    install_from_ports "gnustep-gui" "x11-toolkits/gnustep-gui"
    install_from_ports "gnustep-back" "x11-toolkits/gnustep-back"
    install_from_ports "gnustep" "lang/gnustep"
    gnustep-config --objc-flags > "$gnustep_config_output" 2>> "$LOGFILE"
    if ! grep -q "-I" "$gnustep_config_output"; then
        log "ERROR: gnustep-config still returns empty output after ports rebuild."
        error_exit "gnustep-config configuration failed"
    fi
fi
rm -f "$gnustep_config_output"

# Step 7: Install Bash
log "Installing Bash (for compatibility)..."
if ! run_with_spinner "pkg install -y bash" "Installing Bash..." 60; then
    log "WARNING: Bash installation failed. Retrying..."
    check_status "pkg clean && pkg update && pkg install -y bash" "Retrying Bash installation..." 120
fi
check_command bash "Bash installation failed"

# Step 8: Test environment
log "Creating test Objective-C program..."
cat << EOF > /tmp/hello.m
#import <Foundation/Foundation.h>
int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"Hello, GhostBSD!");
    [pool drain];
    return 0;
}
EOF
check_file /tmp/hello.m "Failed to create test program"
log "Compiling test program..."
check_status "clang \`gnustep-config --objc-flags\` -o /tmp/hello /tmp/hello.m -lgnustep-base" "Compiling test program..." 10
check_file /tmp/hello "Test program binary not created"
log "Running test program..."
check_status "/tmp/hello" "Running test program..." 10
log "Test program output:"
if ! grep -q "Hello, GhostBSD!" "$LOGFILE"; then
    log "WARNING: Test program did not produce expected output"
fi

# Step 9: Test GUI program
log "Creating GUI test program..."
cat << EOF > /tmp/gui.m
#import <AppKit/AppKit.h>
int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    NSRunAlertPanel(@"Test", @"Hello from GNUstep GUI!", @"OK", nil, nil);
    [pool drain];
    return 0;
}
EOF
check_file /tmp/gui.m "Failed to create GUI test program"
log "Compiling GUI test program..."
check_status "clang \`gnustep-config --objc-flags\` -o /tmp/gui /tmp/gui.m -lgnustep-base -lgnustep-gui" "Compiling GUI test program..." 10
check_file /tmp/gui "GUI test program binary not created"
log "GUI test program compiled. Run '/tmp/gui' manually to verify GUI (requires X11)."

# Step 10: Install optional tools
log "Installing optional GNUstep tools (Gorm, ProjectCenter)..."
if ! run_with_spinner "pkg install -y gorm projectcenter" "Installing Gorm and ProjectCenter..." 60; then
    log "WARNING: Failed to install Gorm or ProjectCenter. Continuing..."
else
    check_command gorm "Gorm installation failed"
    check_command projectcenter "ProjectCenter installation failed"
fi

# Step 11: Generate verification report
generate_verification_report

# Step 12: Notify user
log "Installation complete. Log file: $LOGFILE"
log "For Bash: Start a session with 'bash' and verify with 'echo \$GNUSTEP_SYSTEM_ROOT'."
log "For Fish: Source '$FISH_CONFIG' or copy to ~/.config/fish/conf.d/ and source it, then verify with 'echo \$GNUSTEP_SYSTEM_ROOT'."
log "To set Bash as default shell, run: chsh -s /usr/local/bin/bash"
log "To set Fish as default shell, run: chsh -s /usr/local/bin/fish"

# Cleanup
log "Cleaning up..."
rm -f /tmp/hello /tmp/hello.m /tmp/gui /tmp/gui.m /tmp/gnustep_err_*.txt /tmp/gnustep_config_output.txt
exit 0
