FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ── Base system packages ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh tmux screen stow git curl wget unzip zip xz-utils \
    build-essential ca-certificates gnupg lsb-release \
    openssh-server sudo locales tzdata procps \
    python3 python3-pip python3-venv \
    ripgrep fd-find \
  && locale-gen en_US.UTF-8 \
  && ln -sf "$(which fdfind)" /usr/local/bin/fd \
  && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# ── uv ────────────────────────────────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# ── Node.js 22 (required by Claude Code) ─────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# ── Claude Code ───────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Neovim (latest stable) ────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in \
       amd64) NVIM_ARCH=x86_64 ;; \
       arm64) NVIM_ARCH=arm64  ;; \
       *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
     esac \
  && curl -Lo /tmp/nvim.tar.gz \
       "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" \
  && tar -xzf /tmp/nvim.tar.gz -C /opt \
  && ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim \
  && rm /tmp/nvim.tar.gz

# ── lazygit ───────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) LG_ARCH=x86_64 ;; arm64) LG_ARCH=arm64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && VER="${TAG#v}" \
  && curl -Lo /tmp/lazygit.tar.gz \
       "https://github.com/jesseduffield/lazygit/releases/download/${TAG}/lazygit_${VER}_Linux_${LG_ARCH}.tar.gz" \
  && tar -xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit \
  && rm /tmp/lazygit.tar.gz

# ── fzf ───────────────────────────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf \
  && /opt/fzf/install --bin \
  && ln -sf /opt/fzf/bin/fzf /usr/local/bin/fzf

# ── starship ──────────────────────────────────────────────────────────────────
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

# ── SSH daemon baseline config ────────────────────────────────────────────────
RUN mkdir -p /var/run/sshd /etc/ssh/authorized_keys \
  && ssh-keygen -A \
  && sed -i 's/^#*\s*PubkeyAuthentication.*/PubkeyAuthentication yes/'   /etc/ssh/sshd_config \
  && sed -i 's/^#*\s*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
  && sed -i 's/^#*\s*UsePAM.*/UsePAM no/'                                /etc/ssh/sshd_config \
  && sed -i 's/^#*\s*PermitRootLogin.*/PermitRootLogin no/'               /etc/ssh/sshd_config \
  && printf '\nAllowTcpForwarding yes\nX11Forwarding yes\nAuthorizedKeysFile /etc/ssh/authorized_keys/%%u\n' >> /etc/ssh/sshd_config

# ── Custom packages ─────────────────────────────────────────────────────────
# Edit custom-packages.txt and rebuild — only this layer re-runs.
# All layers above stay cached.
COPY custom-packages.txt /tmp/custom-packages.txt
RUN apt-get update \
  && grep -v '^\s*#\|^\s*$' /tmp/custom-packages.txt | xargs -r apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
