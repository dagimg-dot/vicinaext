# vicinaext.sh — Vicinae Extension Installer 🚀

A simple, single-file Bash utility for installing Vicinae extensions from git repositories. Supports both full repository cloning and sparse checkout for specific folders within monorepos.

<div align="center">
  <img src="./assets/vicinae.png" width="200" height="200">
</div>

## ✨ Features

- **Smart Cloning**: Full repository or sparse checkout for specific folders
- **Flexible Building**: Tries `npm run build` first, falls back to `npx vici build`
- **Organized Installation**: Extensions installed to `~/.local/share/vicinae/extensions/`
- **Clean Process**: Uses `/tmp` for cloning, automatic cleanup

## 🚀 Installation

### Install with [eget](https://github.com/zyedidia/eget) (Recommended)
```bash
eget dagimg-dot/vicinaext --to $HOME/.local/bin
```

### Direct Download

```bash
# Download and install to local bin
curl -L -o $HOME/.local/bin/vicinaext https://github.com/dagimg-dot/vicinaext/raw/main/vicinaext.sh
chmod +x $HOME/.local/bin/vicinaext

# Ensure ~/.local/bin is in your PATH
```

### Use as Local Script

```bash
curl -L -o vicinaext.sh https://github.com/dagimg-dot/vicinaext/raw/main/vicinaext.sh
chmod +x vicinaext.sh

./vicinaext.sh --help
```

## 📖 Usage

```
vicinaext.sh — Vicinae extension installer

 ██╗   ██╗██╗ ██████╗██╗███╗   ██╗ █████╗ ███████╗██╗  ██╗████████╗
 ██║   ██║██║██╔════╝██║████╗  ██║██╔══██╗██╔════╝╚██╗██╔╝╚══██╔══╝
 ██║   ██║██║██║     ██║██╔██╗ ██║███████║█████╗   ╚███╔╝    ██║
 ╚██╗ ██╔╝██║██║     ██║██║╚██╗██║██╔══██║██╔══╝   ██╔██╗    ██║
  ╚████╔╝ ██║╚██████╗██║██║ ╚████║██║  ██║███████╗██╔╝ ██╗   ██║
   ╚═══╝  ╚═╝ ╚═════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝


Examples:
  vicinaext https://github.com/user/extension-repo.git
  vicinaext https://github.com/user/extension-repo.git my-extension
  vicinaext https://github.com/user/monorepo.git extensions/my-extension

Notice*:
  - Extensions are installed to ~/.local/share/vicinae/extensions/
  - The script clones to /tmp for sparse checkout when a folder is specified
  - Folder parameter supports paths (e.g., extensions/my-extension)
  - Build process uses specified package manager (npm/yarn/pnpm/bun) with fallback to vici build

Options:
  -h --help            Shows this message
  -v --version         Shows the current script version
```

## 🎯 Quick Start

```bash
# Install an extension from a full repository
vicinaext https://github.com/user/my-vicinae-extension.git

# Install a specific extension from a monorepo
vicinaext https://github.com/user/extension-monorepo.git theme-dark-mode

# Install from nested paths in monorepos
vicinaext https://github.com/user/monorepo.git extensions/theme-dark-mode

# Install to a custom directory
vicinaext -o /path/to/custom/extensions https://github.com/user/extension.git

# Use a specific package manager
vicinaext -p yarn https://github.com/user/extension.git

# Use bun
vicinaext -p bun https://github.com/user/extension.git

# Use a specific branch
vicinaext -b develop https://github.com/user/extension.git

# Combine options
vicinaext -p pnpm -o /custom/extensions -b feature-branch https://github.com/user/repo.git extensions/theme

# Check version information and available updates
vicinaext --version

# Update the script to the latest version
vicinaext --update-script

# Get help
vicinaext --help
```

## 🔧 How It Works

### Full Repository Installation
```bash
vicinaext https://github.com/user/extension-repo.git
```
1. Clones the entire repository to a temporary directory
2. Runs `npm install` to install dependencies
3. Attempts to build with `npm run build -o <output-dir>`
4. If that fails, tries `npx vici build -o <output-dir>`
5. Extension is built directly to the target extensions directory

### Monorepo Folder Installation
```bash
vicinaext https://github.com/user/extension-monorepo.git my-extension
vicinaext https://github.com/user/monorepo.git extensions/my-extension
```
1. Uses git sparse checkout to clone only the specified folder or path
2. Supports both simple folder names and nested paths (e.g., `extensions/my-extension`)
3. Continues with the same build and install process as above
4. Uses the last part of the path as the extension name

## 🛠️ Requirements

- `git` - For cloning repositories
- **Package Manager** (choose one):
  - `npm` - Node Package Manager (default)
  - `yarn` - Alternative package manager
  - `pnpm` - Performant package manager
  - `bun` - Fast JavaScript runtime
- `find` - For locating built files
- `jq` and `wget` - For script updates (optional)

## 📦 Package Manager Support

vicinaext supports multiple JavaScript package managers:

| Package Manager   | Install Command | Build Command   | Notes                                                  |
| ----------------- | --------------- | --------------- | ------------------------------------------------------ |
| **npm** (default) | `npm install`   | `npm run build` | Most common, fallback to `npx vici build`              |
| **yarn**          | `yarn install`  | `yarn build`    | Alternative to npm, faster for some workflows          |
| **pnpm**          | `pnpm install`  | `pnpm build`    | Space-efficient, faster installs                       |
| **bun**           | `bun install`   | `bun run build` | Fast JavaScript runtime, fallback to `bunx vici build` |

Use the `-p` option to specify your preferred package manager:
```bash
# Use yarn
vicinaext -p yarn https://github.com/user/extension.git

# Use pnpm
vicinaext -p pnpm https://github.com/user/extension.git

# Use bun
vicinaext -p bun https://github.com/user/extension.git
```

## 🐛 Troubleshooting

### Common Issues

**Build fails with both `npm run build` and `npx vici build`?**
- Check if the repository has a valid `package.json`
- Ensure the extension follows Vicinae's build conventions
- Some extensions might need custom build steps

**Sparse checkout not working?**
- Verify the folder path exists in the repository
- Make sure the repository uses `main` or `master` as default branch
- Check git version (sparse checkout requires git 2.25+)

**Permission issues?**
- The script installs to user directories, no sudo required
- Ensure `~/.local/share/vicinae/extensions/` is writable

## 📄 License

This project is licensed under the MIT License.


<div align="center">

**Made with ❤️ for Vicinae extension users**

[⭐ Star us on GitHub](https://github.com/dagimg-dot/vicinaext) • [🐛 Report Issues](https://github.com/dagimg-dot/vicinaext/issues)

</div>
