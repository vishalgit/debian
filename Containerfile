# syntax=docker/dockerfile:1
FROM debian:trixie
USER root
WORKDIR /root

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TZ=Asia/Kolkata
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Switch to HTTP for corp cert installation
RUN sed -i 's|https://|http://|g' /etc/apt/sources.list.d/debian.sources

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
--mount=type=cache,target=/var/lib/apt,sharing=locked \
apt-get update && apt-get install -y --no-install-recommends \
nala \
ca-certificates \
locales

COPY cert.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
locale-gen en_US.UTF-8

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
--mount=type=cache,target=/var/lib/apt,sharing=locked \
nala update && \
nala install -y --no-install-recommends \
git \
gh \
wget \
gnupg2 \
apt-transport-https \
curl \
zsh \
build-essential \
sudo \
fd-find \
locate \
which \
ripgrep \
tmux \
aria2

# Setup non root user
ARG user=vishal
ARG group=vishal
ARG uid=1000
ARG gid=1000
ARG name="Vishal Saxena"
ARG email=vishal.reply@gmail.com
ARG homedir=/home/${user}

RUN groupadd -g ${gid} ${group} && \
useradd -m -u ${uid} -g ${group} -s /bin/zsh ${user} && \
echo "${user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${user} && \
chmod 0440 /etc/sudoers.d/${user} && \
echo "${user}:${user}" | chpasswd && \
mkdir -p /run/user/${uid} && \
chown ${user}:${group} /run/user/${uid} && \
chmod 0700 /run/user/${uid}
ENV XDG_RUNTIME_DIR=/run/user/${uid}
ENV XDG_CONFIG_DIR=${homedir}/.config

USER ${user}
WORKDIR ${homedir}

# Setup git
RUN git config --global core.editor nvim && \
git config --global init.defaultBranch main && \
git config --global pull.rebase true && \
git config --global user.email ${email} && \
git config --global user.name ${name} && \
mkdir -p ${homedir}/.secrets && \
git config --global credential.helper ${homedir}/.secrets/gh-cred-helper.sh && \
git config --global core.attributesfile ${homedir}/.secrets/.gitattributes
COPY --chown=${user}:${group} .gitattributes ${homedir}/.secrets/.gitattributes
COPY --chown=${user}:${group} gh.gpg ${homedir}/.secrets/gh.gpg
COPY --chown=${user}:${group} --chmod=755 gh-cred-helper.sh ${homedir}/.secrets/gh-cred-helper.sh

# Setup oh-my-zsh
RUN mkdir -p ${XDG_CONFIG_DIR}/ezsh && \
git clone https://github.com/vishalgit/ezsh ${homedir}/ezsh && \
touch ${homedir}/.zshrc && \
cd ${homedir}/ezsh && \
chmod +x install.sh && \
./install.sh -n && \
cd && \
rm -rf ${homedir}/ezsh && \
sudo chsh -s /usr/bin/zsh ${user} && \
echo "alias gitdc='gpg --decrypt "${homedir}"/.secrets/gh.gpg'" >> ${homedir}/.zshrc 

# Setup tmux
RUN mkdir -p $homedir/.tmux/plugins/tpm && \
git clone https://github.com/tmux-plugins/tpm ${homedir}/.tmux/plugins/tpm
COPY --chown=${user}:${group} tmux.conf ${homedir}/.tmux.conf

# Setup mise
RUN curl https://mise.run | sh && \
echo "eval \"\$(${homedir}/.local/bin/mise activate zsh)\"" >> ${homedir}/.zshrc
ENV PATH="${homedir}/.local/bin:${homedir}/.local/share/mise/shims:${PATH}"

# Setup rclone
RUN mise use -g aqua:rclone/rclone && \
mkdir -p ${XDG_CONFIG_DIR}/rclone ${homedir}/org && \
echo "alias orgbisync='rclone bisync "${homedir}"/org mega:org --resync --size-only'" >> ${homedir}/.zshrc && \
echo "alias orgsync='rclone sync "${homedir}"/org mega:org'" >> ${homedir}/.zshrc
COPY --chown=${user}:${group} rclone.conf ${XDG_CONFIG_DIR}/rclone/rclone.conf

# Setup Node
COPY --chown=${user}:${group} cert.crt ${homedir}/.certs/cert.crt 
ENV NODE_EXTRA_CA_CERTS=${homedir}/.certs/cert.crt
RUN mise use -g node@lts \
npm:npm \
npm:typescript \
npm:tree-sitter-cli \
npm:neovim

# Setup Rust
RUN mise use -g rust
ENV PATH="${homedir}/.cargo/bin:${PATH}"
RUN rustup component add rust-analyzer
RUN mise use -g cargo-binstall
RUN mise settings set cargo.binstall true
# Terminal utilities
RUN mise use -g aqua:jqlang/jq
RUN mise use -g aqua:sharkdp/bat
RUN mise use -g aqua:eth-p/bat-extras
RUN mise use -g aqua:sxyazi/yazi
RUN mise use -g github:neovide/neovide && mkdir -p ${XDG_CONFIG_DIR}/neovide
COPY --chown=${user}:${group} neovide.toml ${XDG_CONFIG_DIR}/neovide/config.toml

# Setup claude
RUN mise use -g aqua:anthropics/claude-code 
# Setup neovim
ENV SHELL=/bin/zsh
ENV PATH="${homedir}/.local/share/bob/nvim-bin:${PATH}"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
--mount=type=cache,target=/var/lib/apt,sharing=locked \
sudo nala update && sudo nala install -y --no-install-recommends \
unzip \
xclip \
texinfo && \
curl -fsSL https://raw.githubusercontent.com/MordechaiHadad/bob/master/scripts/install.sh | bash && \
bob use stable

RUN git clone https://github.com/vishalgit/kickstart.nvim ${XDG_CONFIG_DIR}/kickstart && \
cd ${XDG_CONFIG_DIR}/kickstart && \
git remote add upstream https://github.com/nvim-lua/kickstart.nvim && \
git remote set-url --push upstream DISABLE && \
echo "alias kvim='NVIM_APPNAME=kickstart nvim'" >> ${homedir}/.zshrc

RUN git clone https://github.com/vishalgit/lazyvim ${XDG_CONFIG_DIR}/lazyvim && \
cd ${XDG_CONFIG_DIR}/lazyvim && \
git remote add upstream https://github.com/LazyVim/starter && \
git remote set-url --push upstream DISABLE && \
echo "alias lvim='NVIM_APPNAME=lazyvim nvim'" >> ${homedir}/.zshrc

RUN <<EOF
git clone https://github.com/vishalgit/vim-kata && mv vim-kata ${homedir}/.vim-kata && \
cat > ${homedir}/.local/bin/kata << 'SCRIPT'
#!/bin/bash
export NVIM_APPNAME=kickstart
cd ~/.vim-kata
./run.sh
SCRIPT
chmod u+x ${homedir}/.local/bin/kata
EOF

# Setup backports
RUN sudo tee /etc/apt/sources.list.d/debian-backports.sources <<'EOF'
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# Set up nerdfont
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
--mount=type=cache,target=/var/lib/apt,sharing=locked \
sudo nala update && \
sudo nala install -y --no-install-recommends \
fonts-symbola \
emacs \
pandoc \
shellcheck \
fontconfig && \
mkdir -p ${homedir}/.fonts && \
wget -q --show-progress https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -O ${homedir}/JetBrainsMono.tar.xz && \
wget -q --show-progress https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz -O ${homedir}/NerdFontsSymbolsOnly.tar.xz && \
tar -xvf ${homedir}/JetBrainsMono.tar.xz -C ${homedir}/.fonts && \
tar -xvf ${homedir}/NerdFontsSymbolsOnly.tar.xz -C ${homedir}/.fonts && \
fc-cache -fv ${homedir}/.fonts \
&& rm -rf ${homedir}/JetBrainsMono.tar.xz ${homedir}/NerdFontsSymbolsOnly.tar.xz
# Setup terminal emacs
RUN git clone https://github.com/vishalgit/doom ${XDG_CONFIG_DIR}/doom && \
git clone --depth 1 https://github.com/doomemacs/doomemacs ${XDG_CONFIG_DIR}/emacs && \
${XDG_CONFIG_DIR}/emacs/bin/doom install --env --force && \
${XDG_CONFIG_DIR}/emacs/bin/doom sync && \
echo "alias cmacs='emacs -nw'" >> ${homedir}/.zshrc
ENV PATH="${XDG_CONFIG_DIR}/emacs/bin:${PATH}"

# Setup GUI
RUN mkdir -p ${XDG_CONFIG_DIR}/i3 \
${XDG_CONFIG_DIR}/i3status \
${XDG_CONFIG_DIR}/neovide
COPY --chown=${user}:${group} i3.config ${XDG_CONFIG_DIR}/i3/config
COPY --chown=${user}:${group} i3status.config ${XDG_CONFIG_DIR}/i3status/config
COPY --chown=${user}:${group} i3_start ${homedir}/.xsession
COPY --chown=${user}:${group} Xresources ${homedir}/.Xresources
COPY --chown=${user}:${group} mimeapps.list ${XDG_CONFIG_DIR}/mimeapps.list
RUN chmod +x ${homedir}/.xsession
RUN mkdir -p ${XDG_CONFIG_DIR}/rofi && \
echo '@theme "gruvbox-dark-hard"' > ${XDG_CONFIG_DIR}/rofi/config.rasi

ENV BROWSER=firefox-esr
ENV EDITOR=nvim
ENV VISUAL=nvim
ENV TERMINAL=xterm
ENV FILE_MANAGER=thunar
USER root
WORKDIR /root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
--mount=type=cache,target=/var/lib/apt,sharing=locked \
nala update && \
nala install -y --no-install-recommends \
xrdp \
xorg \
xorgxrdp \
i3-wm \
i3status \
rofi \
dbus-x11 \
tini \
xterm \
luit \
tumbler \
thunar \
thunar-archive-plugin \
file-roller \
thunar-media-tags-plugin \
xdg-utils \
firefox-esr \
zathura \
zathura-pdf-poppler \
openssh-server \
libnss3-tools

RUN mkdir -p /var/run/sshd && \
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
sed -i 's/^#EnableFuseMount=.*/EnableFuseMount=false/' /etc/xrdp/sesman.ini && \
sed -i 's/^max_bpp=32/max_bpp=16/' /etc/xrdp/xrdp.ini && \
sed -i 's/^crypt_level=high/crypt_level=none/' /etc/xrdp/xrdp.ini && \
sed -i '/^\[Globals\]/a use_client_res=true' /etc/xrdp/xrdp.ini && \
mkdir -p /var/run/xrdp /var/log/xrdp && \
chmod 755 /var/run/xrdp /var/log/xrdp && \
sed -i 's/^UsePrivilegeSeparation=.*/UsePrivilegeSeparation=false/' /etc/xrdp/sesman.ini
COPY start-xrdp.sh /usr/local/bin/start-xrdp.sh
RUN chmod +x /usr/local/bin/start-xrdp.sh && \
mkdir -p /usr/lib/firefox-esr/distribution && \
cat <<'EOF' > /usr/lib/firefox-esr/distribution/policies.json
{
  "policies": {
    "Certificates": {
      "ImportEnterpriseRoots": true,
      "Install": [
        "/home/vishal/.certs/cert.crt"
      ]
    },
    "SearchEngines": {
      "Default": "DuckDuckGo",
      "Remove": ["Google", "Bing"]
    },
    "Preferences": {
      "extensions.activeThemeID": "firefox-compact-dark@mozilla.org",
      "browser.theme.content-theme": 0,
      "browser.theme.toolbar-theme": 0,
      "ui.systemUsesDarkTheme": 1,
      "browser.in-content.dark-mode": true,
      "layout.css.prefers-color-scheme.content-override": 0
    },
    "Homepage": {
      "URL": "https://duckduckgo.com",
      "StartPage": "homepage"
    }
  }
}
EOF
RUN tee /etc/environment << 'EOF'
DEBIAN_FRONTEND=noninteractive
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
TZ=Asia/Kolkata
XDG_RUNTIME_DIR=/run/user/1000
XDG_CONFIG_DIR=${homedir}/.config
NODE_EXTRA_CA_CERTS=/home/vishal/.certs/cert.crt
BROWSER=firefox-esr
EDITOR=nvim
VISUAL=nvim
TERMINAL=xterm
FILE_MANAGER=thunar
EOF
RUN echo "PATH=${PATH}" >> /etc/environment

EXPOSE 3389
EXPOSE 22
EXPOSE 3000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-xrdp.sh"]
