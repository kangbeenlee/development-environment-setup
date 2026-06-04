# Development Environment Setup Project

This project collects configuration bundles for development tools under the current directory so that you can install and apply only the tools you want.

## Structure

```text
development-environment-setup/
├── README.md
├── setup.sh
├── lib/
│   └── common.sh
├── packages/
│   ├── tool.env
│   └── tool.sh
└── tmux/
    ├── files/
    │   └── .tmux.conf
    ├── tool.env
    └── tool.sh
```

## How It Works

`setup.sh` scans child directories and automatically discovers the list of supported tools. Each tool directory provides the following files:

- `tool.env`: tool ID, name, and description
- `tool.sh`: install check, installation, existing configuration detection, and apply logic

The flow is:

1. Collect the list of supported tools.
2. Let the user choose which tools to apply.
3. Check whether each selected tool is already installed.
4. Install missing tools first.
5. If existing configuration is found, ask whether to overwrite it or skip it.
6. Print a completion message after setup finishes.

## Usage

Interactive mode:

```bash
./setup.sh
```

List supported tools only:

```bash
./setup.sh --list
```

Run a specific tool only:

```bash
./setup.sh --tools tmux
```

Run install-only packages only:

```bash
./setup.sh --tools packages
```

Run without prompts:

```bash
./setup.sh --tools tmux --yes-overwrite --non-interactive
```

## tmux Example

The `tmux` example currently manages:

- `~/.tmux.conf`
- `~/.tmux/plugins/tpm`

Instead of hard-copying the full plugin set into this repository, the setup installs or updates `TPM` and then synchronizes plugins during application. This keeps the repository smaller and makes plugin updates simpler.

## Install-Only Packages

The `packages` tool is for CLI tools that only need installation and do not require template files or extra apply steps.

It currently installs:

- `jq`
- `ripgrep`
- `glow`

Use `packages/tool.sh` to maintain:

- `APT_PACKAGES` for packages installed by the system package manager
- `SNAP_PACKAGES` for packages installed by `snap`
- `REQUIRED_COMMANDS` for the binaries used to verify installation

## Adding a New Tool

For example, to add a `git` tool, create a top-level `git/` directory and add:

- `git/tool.env`
- `git/tool.sh`
- `git/files/...` if template files are needed

`setup.sh` will detect the new tool directory automatically.
