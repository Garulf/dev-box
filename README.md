# dev-box

A personal Docker-based development environment with SSH access, pre-loaded with a modern CLI toolset.

## What's included

- **Shell**: zsh
- **Editor**: Neovim with [LazyVim](https://www.lazyvim.org/)
- **Git**: git, lazygit, GitHub CLI (`gh`)
- **Search**: ripgrep, fd, fzf
- **Multiplexer**: tmux
- **Languages**: Python (via `uv`), Node.js 22
- **AI**: Claude Code
- **Extras**: jq — add more in `custom-packages.txt`

## Setup

1. **Copy and fill in the env file**

   ```sh
   cp .env.example .env
   # or let the script detect your current user automatically:
   ./setup-env.sh
   ```

2. **Add your SSH public key**

   ```sh
   cp ~/.ssh/id_ed25519.pub authorized_keys
   ```

3. **Build and start**

   ```sh
   ./run.sh up -d --build
   ```

4. **SSH in**

   ```sh
   ssh -p 2222 <your-user>@localhost
   ```

## Usage

```sh
./run.sh up -d       # start in background
./run.sh down        # stop
./run.sh build       # rebuild image
./run.sh logs -f     # follow logs
```

## Adding packages

Edit `custom-packages.txt` (one package per line) and rebuild. Only that layer re-runs — the rest of the image stays cached.

