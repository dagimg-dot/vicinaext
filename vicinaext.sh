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
#H#
#H# Notice*:
#H#   Extensions are installed to ~/.local/share/vicinae/extensions/
#H#   The script clones to /tmp for sparse checkout when a folder is specified
#H#   Folder parameter supports paths (e.g., extensions/my-extension)
#H#   Build process uses specified package manager (npm/yarn/pnpm/bun) with fallback to vici build
#H#
#H# Options:
#H#   -h --help            Shows this message
#H#   -v --version         Shows the current script version
#H#   -o --output <dir>    Output directory for extensions (default: ~/.local/share/vicinae/extensions)
#H#   -p --package-manager <pm> Package manager to use (npm, yarn, pnpm, bun) (default: npm)
#H#

#
# Constants
#
VICINAE_EXTENSIONS_DIR="$HOME/.local/share/vicinae/extensions"
SCRIPT_VERSION="1.0.0"

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

check_dependencies() {
    local deps=("git" "npm" "find" "cp")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            print_error "$dep is not installed (required for extension installation)"
            exit 1
        fi
    done
}

# Clone repository with optional sparse checkout
clone_repo() {
    local repo_url="$1"
    local folder="${2:-}"

    if [ -n "$folder" ]; then
        local temp_dir
        temp_dir=$(mktemp -d)

        echo "Cloning repository with sparse checkout for folder '$folder'..." >&2

        cd "$temp_dir"
        git init >/dev/null
        git remote add origin "$repo_url" >/dev/null
        git config core.sparseCheckout true
        echo "$folder/*" >>.git/info/sparse-checkout

        # Try to pull from main first, then master
        if ! git pull origin main >/dev/null 2>&1; then
            if ! git pull origin master >/dev/null 2>&1; then
                print_error "Failed to pull from repository. Check if the repository exists and is accessible"
                rm -rf "$temp_dir"
                exit 1
            fi
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
        if ! git clone "$repo_url" "$temp_dir" >/dev/null 2>&1; then
            print_error "Failed to clone repository. Check if the URL is correct and accessible"
            rm -rf "$temp_dir"
            exit 1
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

    echo "Installing dependencies with $package_manager..."
    case "$package_manager" in
    npm)
        if ! npm install; then
            print_error "Failed to install dependencies with npm"
            return 1
        fi
        ;;
    yarn)
        if ! yarn install; then
            print_error "Failed to install dependencies with yarn"
            return 1
        fi
        ;;
    pnpm)
        if ! pnpm install; then
            print_error "Failed to install dependencies with pnpm"
            return 1
        fi
        ;;
    bun)
        if ! bun install; then
            print_error "Failed to install dependencies with bun"
            return 1
        fi
        ;;
    esac

    # Create the output directory if it doesn't exist
    mkdir -p "$output_dir"

    echo "Building extension with $package_manager..."

    # Try package manager specific build commands
    case "$package_manager" in
    npm)
        if npm run build -- -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'npm run build'"
        elif npx vici build -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'npx vici build'"
        else
            print_error "Failed to build extension. Neither 'npm run build' nor 'npx vici build' worked"
            print_warning "Check the extension's build scripts in package.json"
            return 1
        fi
        ;;
    yarn)
        if yarn run build -- -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'yarn build'"
        elif yarn run vici build -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'yarn run vici build'"
        else
            print_error "Failed to build extension. Neither 'yarn build' nor 'yarn run vici build' worked"
            print_warning "Check the extension's build scripts in package.json"
            return 1
        fi
        ;;
    pnpm)
        if pnpm run build -- -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'pnpm build'"
        elif pnpm dlx vici build -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'pnpm exec vici build'"
        else
            print_error "Failed to build extension. Neither 'pnpm build' nor 'pnpm exec vici build' worked"
            print_warning "Check the extension's build scripts in package.json"
            return 1
        fi
        ;;
    bun)
        if bun run build -- -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'bun run build'"
        elif bunx vici build -o "$output_dir" 2>/dev/null; then
            print_success "Built successfully with 'bunx vici build'"
        else
            print_error "Failed to build extension. Neither 'bun run build' nor 'bunx vici build' worked"
            print_warning "Check the extension's build scripts in package.json"
            return 1
        fi
        ;;
    esac
}

# Main installation function
install_extension() {
    local repo_url="$1"
    local folder="${2:-}"
    local output_dir="${3:-$VICINAE_EXTENSIONS_DIR}"
    local package_manager="${4:-npm}"

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
    if ! temp_dir=$(clone_repo "$repo_url" "$folder"); then
        print_error "Failed to clone repository"
        exit 1
    fi

    # Build and install
    local target_dir="$output_dir/$extension_name"
    echo "Installing extension to $target_dir..."

    if ! build_extension "$temp_dir" "$target_dir" "$package_manager"; then
        print_error "Failed to build extension"
        rm -rf "$temp_dir"
        exit 1
    fi

    rm -rf "$temp_dir"

    print_success "Extension '$extension_name' installed successfully!"
    echo "Location: $target_dir"
}

show_version() {
    echo "vicinaext.sh version $SCRIPT_VERSION"
    echo "Vicinae extension installer"
}

#
# Main execution
#

check_dependencies

# Parse arguments
output_dir="$VICINAE_EXTENSIONS_DIR"
package_manager="npm"
repo_url=""
folder=""

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

install_extension "$repo_url" "$folder" "$output_dir" "$package_manager"
