#!/bin/bash

set -euo pipefail
trap 'printf "\nScript interrupted by user. Please clean up any temporary files manually.\n"; exit 130' INT TERM

#H#
#H# vicinaext.sh — Vicinae extension installer
#H#
#H#  ██╗   ██╗██╗ ██████╗██╗███╗   ██╗ █████╗ ███████╗██╗  ██╗████████╗
#H#  ██║   ██║██║██╔════╝██║████╗  ██║██╔══██╗██╔════╝╚██╗██╔╝╚══██╔══╝
#H#  ██║   ██║██║██║     ██║██╔██╗ ██║███████║█████╗   ╚███╔╝    ██║
#H#  ╚██╗ ██╔╝██║██║     ██║██║╚██╗██║██╔══██║██╔══╝   ██╔██╗    ██║
#H#   ╚████╔╝ ██║╚██████╗██║██║ ╚████║██║  ██║███████╗██╔╝ ██╗   ██║
#H#    ╚═══╝  ╚═╝ ╚═════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝
#H#
#H#
#H# Examples:
#H#   vicinaext https://github.com/user/extension-repo.git
#H#   vicinaext https://github.com/user/extension-repo.git my-extension
#H#   vicinaext https://github.com/user/monorepo.git extensions/my-extension
#H#   vicinaext -o /custom/path https://github.com/user/extension.git
#H#   vicinaext -p bun https://github.com/user/extension.git
#H#   vicinaext -b develop https://github.com/user/extension.git
#H#   vicinaext -f https://github.com/user/extension.git
#H#
#H# Notice*:
#H#   Extensions are installed to ~/.local/share/vicinae/extensions/
#H#   The script clones to /tmp for sparse checkout when a folder is specified
#H#   Folder parameter supports paths (e.g., extensions/my-extension)
#H#   Build process uses specified package manager (npm/yarn/pnpm/bun) with fallback to vici build
#H#
#H# Options:
#H#   -h --help            Shows this message
#H#   -v --version         Shows the current script version and checks for updates
#H#   -o --output <dir>    Output directory for extensions (default: ~/.local/share/vicinae/extensions)
#H#   -p --package-manager <pm> Package manager to use (npm, yarn, pnpm, bun) (default: npm)
#H#   -b --branch <branch> Git branch to clone (default: main or master)
#H#   -f --force           Force reinstall by deleting existing extension directory
#H#   -s --update-script   Updates the script to the latest version
#H#

#
# Constants
#
VICINAE_EXTENSIONS_DIR="$HOME/.local/share/vicinae/extensions"
VICINAEXT_VERSION="1.0.3"
GITHUB_API_URL="https://api.github.com/repos/dagimg-dot/vicinaext/releases/latest"

# Color definitions
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' #

help() {
    sed -rn 's/^#H# ?//;T;p' "$0"
}

print_color() {
    color=$1
    text=$2
    printf "%b%s%b\n" "$color" "$text" "$NC"
}

print_error() {
    print_color "$RED" "Error: $1" >&2
}

print_warning() {
    print_color "$ORANGE" "Warning: $1" >&2
}

print_success() {
    print_color "$GREEN" "$1"
}

getLatestScriptVersion() {
    latest_version=$(wget -qO- "$GITHUB_API_URL" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//')
    if [ -n "$latest_version" ]; then
        echo "$latest_version"
        return 0
    else
        return 1
    fi
}

get_install_command() {
    local package_manager="$1"
    case "$package_manager" in
    npm) echo "npm install" ;;
    yarn) echo "yarn install" ;;
    pnpm) echo "pnpm install" ;;
    bun) echo "bun install" ;;
    *) echo "npm install" ;; # fallback
    esac
}

get_build_command() {
    local package_manager="$1"
    case "$package_manager" in
    npm) echo "npm run build" ;;
    yarn) echo "yarn run build" ;;
    pnpm) echo "pnpm run build" ;;
    bun) echo "bun run build" ;;
    *) echo "npm run build" ;; # fallback
    esac
}

get_exec_command() {
    local package_manager="$1"
    case "$package_manager" in
    npm) echo "npx" ;;
    yarn) echo "yarn run" ;;
    pnpm) echo "pnpm dlx" ;;
    bun) echo "bunx" ;;
    *) echo "npx" ;; # fallback
    esac
}

check_dependencies() {
    local base_deps=("git" "npm" "find" "cp")
    local optional_deps=("jq" "wget")

    # Check base dependencies (always required)
    for dep in "${base_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            print_error "$dep is not installed (required for extension installation)"
            exit 1
        fi
    done

    # Check optional dependencies (required for updates)
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            print_warning "$dep is not installed (required for script updates)"
        fi
    done
}

# Clone repository with optional sparse checkout
clone_repo() {
    local repo_url="$1"
    local folder="${2:-}"
    local branch="${3:-}"

    if [ -n "$folder" ]; then
        local temp_dir
        temp_dir=$(mktemp -d)

        echo "Cloning repository with sparse checkout for folder '$folder'..." >&2

        cd "$temp_dir"
        git init >/dev/null
        git remote add origin "$repo_url" >/dev/null
        git config core.sparseCheckout true
        echo "$folder/*" >>.git/info/sparse-checkout

        # Try to pull from specified branch, or main, or master
        local pull_success=false
        if [ -n "$branch" ]; then
            if git pull origin "$branch" >/dev/null 2>&1; then
                pull_success=true
            fi
        fi

        if [ "$pull_success" = false ]; then
            if git pull origin main >/dev/null 2>&1; then
                pull_success=true
            elif git pull origin master >/dev/null 2>&1; then
                pull_success=true
            fi
        fi

        if [ "$pull_success" = false ]; then
            print_error "Failed to pull from repository. Check if the repository exists and is accessible"
            rm -rf "$temp_dir"
            exit 1
        fi

        if [ -d "$folder" ]; then
            if [ "$(find "$folder" -maxdepth 1 -type f | wc -l)" -eq 0 ]; then
                print_error "Folder '$folder' exists but contains no files"
                rm -rf "$temp_dir"
                exit 1
            fi

            mv "$folder"/* .

            rmdir -p "$folder" 2>/dev/null || true
        else
            print_error "Folder '$folder' not found in repository after sparse checkout"
            print_warning "Make sure the path '$folder' exists in the repository"
            rm -rf "$temp_dir"
            exit 1
        fi

        echo "$temp_dir"
    else
        local temp_dir
        temp_dir=$(mktemp -d)

        echo "Cloning repository..." >&2
        if [ -n "$branch" ]; then
            if ! git clone -b "$branch" "$repo_url" "$temp_dir" >/dev/null 2>&1; then
                print_error "Failed to clone branch '$branch'. Check if the branch exists"
                rm -rf "$temp_dir"
                exit 1
            fi
        else
            if ! git clone "$repo_url" "$temp_dir" >/dev/null 2>&1; then
                print_error "Failed to clone repository. Check if the URL is correct and accessible"
                rm -rf "$temp_dir"
                exit 1
            fi
        fi

        echo "$temp_dir"
    fi
}

build_extension() {
    local source_dir="$1"
    local output_dir="$2"
    local package_manager="$3"

    cd "$source_dir"

    # Check for appropriate package file based on package manager
    case "$package_manager" in
    npm | yarn | pnpm | bun)
        package_file="package.json"
        ;;
    esac

    if [ ! -f "$package_file" ]; then
        print_error "No $package_file found in the extension directory"
        return 1
    fi

    install_cmd=$(get_install_command "$package_manager")
    echo "Installing dependencies with $package_manager..."
    if ! $install_cmd; then
        print_error "Failed to install dependencies with $package_manager"
        return 1
    fi

    # Create the output directory if it doesn't exist
    mkdir -p "$output_dir"

    echo "Building extension with $package_manager..."

    build_cmd=$(get_build_command "$package_manager")
    exec_cmd=$(get_exec_command "$package_manager")

    # Try package manager specific build command with output flag
    if $build_cmd -- -o "$output_dir" 2>/dev/null; then
        print_success "Built successfully with '$build_cmd'"
    elif $exec_cmd vici build -o "$output_dir" 2>/dev/null; then
        print_success "Built successfully with '$exec_cmd vici build'"
    else
        print_error "Failed to build extension. Neither '$build_cmd' nor '$exec_cmd vici build' worked"
        print_warning "Check the extension's build scripts in package.json"
        return 1
    fi
}

# Main installation function
install_extension() {
    local repo_url="$1"
    local folder="${2:-}"
    local output_dir="${3:-$VICINAE_EXTENSIONS_DIR}"
    local package_manager="${4:-npm}"
    local branch="${5:-}"
    local force="${6:-false}"

    # Validate repo URL
    if [[ ! "$repo_url" =~ ^https?:// ]]; then
        print_error "Invalid repository URL. Must be a valid HTTP/HTTPS URL"
        exit 1
    fi

    # Validate package manager
    case "$package_manager" in
    npm | yarn | pnpm | bun) ;;
    *)
        print_error "Unsupported package manager: $package_manager. Supported: npm, yarn, pnpm, bun"
        exit 1
        ;;
    esac

    # Create extensions directory if it doesn't exist
    mkdir -p "$output_dir"

    local temp_dir=""
    local extension_name=""

    # Extract extension name from repo URL or folder path for display
    extension_name=$(basename "$repo_url" .git)
    if [ -n "$folder" ]; then
        # Use the last part of the path as the extension name
        extension_name=$(basename "$folder")
    fi

    echo "Installing Vicinae extension: $extension_name"

    # Clone
    if ! temp_dir=$(clone_repo "$repo_url" "$folder" "$branch"); then
        print_error "Failed to clone repository"
        exit 1
    fi

    # Build and install
    local target_dir="$output_dir/$extension_name"
    echo "Installing extension to $target_dir..."

    # If force flag is set and directory exists, remove it
    if [ "$force" = true ] && [ -d "$target_dir" ]; then
        echo "Force flag enabled. Removing existing extension directory..."
        rm -rf "$target_dir"
    fi

    # Create target directory and copy essential files
    mkdir -p "$target_dir"
    cd "$temp_dir"
    [ -f "package.json" ] && cp "package.json" "$target_dir/"
    [ -d "assets" ] && cp -r "assets" "$target_dir/" 2>/dev/null || true

    if ! build_extension "$temp_dir" "$target_dir" "$package_manager"; then
        print_error "Failed to build extension"
        rm -rf "$temp_dir"
        exit 1
    fi

    rm -rf "$temp_dir"

    print_success "Extension '$extension_name' installed successfully!"
    echo "Location: $target_dir"
}

updateScript() {
    version=$(getLatestScriptVersion)

    if [ -z "$version" ]; then
        echo "Error: Failed to determine version to download" >&2
        return 1
    fi

    # Get the download URL from the release assets
    download_url=$(
        wget -qO- "$GITHUB_API_URL" |
            jq -r '.assets[] | select(.name == "vicinaext.sh") | .browser_download_url'
    )

    if [ -z "$download_url" ]; then
        echo "Error: Failed to find download URL for vicinaext.sh" >&2
        return 1
    fi

    echo "Downloading vicinaext.sh version ${version}..."

    # Download to a temporary file in the same directory
    script_dir=$(dirname "$0")
    temp_file="${script_dir}/vicinaext.sh.new"

    if wget -qO "$temp_file" "$download_url"; then
        chmod +x "$temp_file"
        mv "$temp_file" "$0"
        echo "Successfully updated to version ${version}"
        echo "Please run the script again to use the new version"
        return 0
    else
        rm -f "$temp_file"
        echo "Error: Failed to download version ${version}" >&2
        return 1
    fi
}

show_version() {
    echo "Vicinae Extension Installer (vicinaext.sh):"
    echo "  - Current version: $VICINAEXT_VERSION"
    if latest_version=$(getLatestScriptVersion); then
        if [ "$latest_version" != "$VICINAEXT_VERSION" ]; then
            echo "  - Latest version: $latest_version"
            print_color "$ORANGE" "There is a newer vicinaext.sh version available for download!"
            print_color "$ORANGE" "You can update the script with: $0 --update-script"
        else
            print_color "$GREEN" "You are running the latest vicinaext.sh version!"
        fi
    else
        echo "Failed to check for latest vicinaext.sh version"
    fi
}

#
# Main execution
#

check_dependencies

# Parse arguments
output_dir="$VICINAE_EXTENSIONS_DIR"
package_manager="npm"
branch=""
repo_url=""
folder=""
force=false

while [ $# -gt 0 ]; do
    case "$1" in
    --help | -h)
        help
        exit 0
        ;;
    --version | -v)
        show_version
        exit 0
        ;;
    --output | -o)
        if [ $# -gt 1 ] && [[ "$2" != -* ]]; then
            output_dir="$2"
            shift 2
        else
            print_error "Option $1 requires an argument"
            exit 1
        fi
        ;;
    --package-manager | -p)
        if [ $# -gt 1 ] && [[ "$2" != -* ]]; then
            package_manager="$2"
            shift 2
        else
            print_error "Option $1 requires an argument"
            exit 1
        fi
        ;;
    --branch | -b)
        if [ $# -gt 1 ] && [[ "$2" != -* ]]; then
            branch="$2"
            shift 2
        else
            print_error "Option $1 requires an argument"
            exit 1
        fi
        ;;
    --force | -f)
        force=true
        shift
        ;;
    --update-script | -s)
        updateScript
        exit $?
        ;;
    -*)
        print_error "Unknown option: $1"
        help
        exit 1
        ;;
    *)
        if [ -z "$repo_url" ]; then
            repo_url="$1"
        elif [ -z "$folder" ]; then
            folder="$1"
        else
            print_error "Too many arguments"
            help
            exit 1
        fi
        shift
        ;;
    esac
done

if [ -z "$repo_url" ]; then
    help
    exit 1
fi

install_extension "$repo_url" "$folder" "$output_dir" "$package_manager" "$branch" "$force"
