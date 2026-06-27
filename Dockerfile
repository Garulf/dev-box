FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ── Base system packages ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh tmux screen stow git curl wget unzip zip xz-utils \
    build-essential ca-certificates gnupg lsb-release \
    openssh-server mosh sudo locales tzdata procps \
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

# ── Playwright + headless Chromium ───────────────────────────────────────────
RUN npm install --prefix /usr/local -g playwright \
  && playwright install --with-deps chromium \
  && rm -rf /root/.cache/ms-playwright/chromium-*/chrome-linux/PepperFlash

# ── Claude Code + Bitwarden CLI ───────────────────────────────────────────────
RUN npm install --prefix /usr/local -g @anthropic-ai/claude-code @bitwarden/cli

# ── Per-user npm global prefix ────────────────────────────────────────────────
# ~/.npm-global/bin before system paths so `claude install` / user npm globals shadow system install
RUN printf 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"\nexport PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"\n' \
    > /etc/profile.d/npm-user-prefix.sh

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

# ── zoxide ────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | ZOXIDE_INSTALL_DIR=/usr/local/bin sh

# ── Docker CLI ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list \
  && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# ── starship ──────────────────────────────────────────────────────────────────
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

# ── bat ───────────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends bat \
  && ln -sf "$(command -v batcat 2>/dev/null || command -v bat)" /usr/local/bin/bat \
  && rm -rf /var/lib/apt/lists/*

# ── httpie ────────────────────────────────────────────────────────────────────
RUN pip3 install --break-system-packages httpie

# ── tldr ──────────────────────────────────────────────────────────────────────
RUN npm install --prefix /usr/local -g tldr

# ── eza ───────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) EZA_ARCH=x86_64 ;; arm64) EZA_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && curl -Lo /tmp/eza.tar.gz \
       "https://github.com/eza-community/eza/releases/download/${TAG}/eza_${EZA_ARCH}-unknown-linux-musl.tar.gz" \
  && tar -xzf /tmp/eza.tar.gz -C /usr/local/bin \
  && rm /tmp/eza.tar.gz

# ── lsd ───────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) LSD_ARCH=x86_64 ;; arm64) LSD_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/lsd-rs/lsd/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && curl -Lo /tmp/lsd.tar.gz \
       "https://github.com/lsd-rs/lsd/releases/download/${TAG}/lsd-${TAG}-${LSD_ARCH}-unknown-linux-gnu.tar.gz" \
  && tar -xzf /tmp/lsd.tar.gz --wildcards --strip-components=1 -C /usr/local/bin "*/lsd" \
  && rm /tmp/lsd.tar.gz

# ── delta ─────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) DELTA_ARCH=x86_64 ;; arm64) DELTA_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && VER="${TAG#v}" \
  && curl -Lo /tmp/delta.tar.gz \
       "https://github.com/dandavison/delta/releases/download/${TAG}/delta-${VER}-${DELTA_ARCH}-unknown-linux-musl.tar.gz" \
  && tar -xzf /tmp/delta.tar.gz --wildcards --strip-components=1 -C /usr/local/bin "*/delta" \
  && rm /tmp/delta.tar.gz

# ── yq ────────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && TAG=$(curl -fsSL https://api.github.com/repos/mikefarah/yq/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${TAG}/yq_linux_${ARCH}" \
       -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq

# ── duf ───────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) DUF_ARCH=x86_64 ;; arm64) DUF_ARCH=arm64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/muesli/duf/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && VER="${TAG#v}" \
  && curl -Lo /tmp/duf.tar.gz \
       "https://github.com/muesli/duf/releases/download/${TAG}/duf_${VER}_linux_${DUF_ARCH}.tar.gz" \
  && mkdir /tmp/duf-dir \
  && tar -xzf /tmp/duf.tar.gz -C /tmp/duf-dir \
  && install -m755 /tmp/duf-dir/duf /usr/local/bin/duf \
  && rm -rf /tmp/duf.tar.gz /tmp/duf-dir

# ── gron ──────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) GRON_ARCH=amd64 ;; arm64) GRON_ARCH=arm64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/tomnomnom/gron/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && VER="${TAG#v}" \
  && curl -Lo /tmp/gron.tgz \
       "https://github.com/tomnomnom/gron/releases/download/${TAG}/gron-linux-${GRON_ARCH}-${VER}.tgz" \
  && tar -xzf /tmp/gron.tgz -C /usr/local/bin \
  && rm /tmp/gron.tgz

# ── jless ─────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) JLESS_ARCH=x86_64 ;; arm64) JLESS_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/PaulJuliusMartinez/jless/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && curl -Lo /tmp/jless.zip \
       "https://github.com/PaulJuliusMartinez/jless/releases/download/${TAG}/jless-${TAG}-${JLESS_ARCH}-unknown-linux-gnu.zip" \
  && unzip /tmp/jless.zip jless -d /usr/local/bin \
  && chmod +x /usr/local/bin/jless \
  && rm /tmp/jless.zip

# ── xh ────────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) XH_ARCH=x86_64 ;; arm64) XH_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/ducaale/xh/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && curl -Lo /tmp/xh.tar.gz \
       "https://github.com/ducaale/xh/releases/download/${TAG}/xh-${TAG}-${XH_ARCH}-unknown-linux-musl.tar.gz" \
  && tar -xzf /tmp/xh.tar.gz --wildcards --strip-components=1 -C /usr/local/bin "*/xh" \
  && rm /tmp/xh.tar.gz

# ── navi ──────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) NAVI_ARCH=x86_64 ;; arm64) NAVI_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" && exit 1 ;; esac \
  && TAG=$(curl -fsSL https://api.github.com/repos/denisidoro/navi/releases/latest \
             | grep '"tag_name"' | head -1 | cut -d'"' -f4) \
  && curl -Lo /tmp/navi.tar.gz \
       "https://github.com/denisidoro/navi/releases/download/${TAG}/navi-${TAG}-${NAVI_ARCH}-unknown-linux-musl.tar.gz" \
  && tar -xzf /tmp/navi.tar.gz -C /usr/local/bin \
  && rm /tmp/navi.tar.gz

# ── rbw (amd64 deb from git.tozt.net; no arm64 build available) ──────────────
RUN ARCH=$(dpkg --print-architecture) \
  && if [ "$ARCH" = "amd64" ]; then \
       VER=$(curl -fsSL https://git.tozt.net/rbw/releases/deb/ \
               | grep -oE 'rbw_[0-9]+\.[0-9]+\.[0-9]+_amd64\.deb' \
               | sort -V | tail -1 | sed 's/rbw_//;s/_amd64\.deb//') \
       && curl -fsSLo /tmp/rbw.deb \
            "https://git.tozt.net/rbw/releases/deb/rbw_${VER}_amd64.deb" \
       && dpkg -i /tmp/rbw.deb \
       && rm /tmp/rbw.deb; \
     else \
       echo "rbw: no pre-built deb for $ARCH, skipping"; \
     fi

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
EXPOSE 60000-60010/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
