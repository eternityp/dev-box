FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul
# 빌드 중에는 en_US (ko_KR 생성 전) → 아래 locale 생성 후 ko_KR로 전환
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# apt 미러를 카카오로 (amd64만 대상; arm64 ports.ubuntu.com 은 카카오 미제공이라 그대로 둠)
RUN sed -i -E 's#https?://(archive|security)\.ubuntu\.com/ubuntu#http://mirror.kakao.com/ubuntu#g' /etc/apt/sources.list.d/ubuntu.sources

# Base packages (한글 폰트 fonts-nanum 포함, TZ=KST 설정)
RUN apt-get update && apt-get install -y \
    tzdata git zsh curl locales vim wget \
    net-tools zip openssh-server sudo gosu \
    gcc build-essential libssl-dev libffi-dev \
    libncurses5-dev zlib1g-dev libreadline-dev \
    libbz2-dev libsqlite3-dev liblzma-dev \
    ffmpeg libsm6 libxext6 \
    fonts-powerline fonts-nanum \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
 && locale-gen en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

# Locale: en_US / ko_KR 생성 후 기본을 한글(ko_KR.UTF-8)로 전환
RUN apt-get update && apt-get install -y locales \
 && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && sed -i 's/# ko_KR.UTF-8 UTF-8/ko_KR.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen

ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# user (zsh 기본 shell, passwordless sudo)
RUN useradd -m -u 1001 -s /bin/zsh user \
 && echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# SSH: sshd_config / host key 는 이미지에 굽지 않고 런타임(entrypoint)에서 생성

# Oh My Zsh + powerlevel10k + plugins
USER user
WORKDIR /home/user

RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh \
 && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      ~/.oh-my-zsh/custom/themes/powerlevel10k \
 && git clone https://github.com/zsh-users/zsh-autosuggestions \
      ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
 && git clone https://github.com/zsh-users/zsh-syntax-highlighting \
      ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
 && cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc \
 && sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc \
 && sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc \
 && sed -i '/^source \$ZSH\/oh-my-zsh.sh/i POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' ~/.zshrc \
 && echo '[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh' >> ~/.zshrc
# p10k 새로 설정하려면: compose의 ./.p10k.zsh 마운트 제거 + 위 두 줄(DISABLE_WIZARD / source) 제거 후 접속해 `p10k configure`

# locale 등록 (SSH 로그인 셸에 ko_KR 적용 — ENV는 sshd 세션에 전달 안 됨)
RUN echo '' >> ~/.zshrc \
 && echo '# locale (ko_KR)' >> ~/.zshrc \
 && echo 'export LANG=ko_KR.UTF-8' >> ~/.zshrc \
 && echo 'export LANGUAGE=ko_KR:ko' >> ~/.zshrc \
 && echo 'export LC_ALL=ko_KR.UTF-8' >> ~/.zshrc

# pyenv + Python 3.10
ENV PYENV_ROOT="/home/user/.pyenv"
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

RUN curl -fsSL https://pyenv.run | bash

RUN echo '' >> ~/.zshrc \
 && echo '# pyenv' >> ~/.zshrc \
 && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc \
 && echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc \
 && echo 'eval "$(pyenv init -)"' >> ~/.zshrc

RUN zsh -lc "pyenv install 3.10 && pyenv global 3.10"

# sdkman + Java 21
RUN curl -s "https://get.sdkman.io" | bash

RUN echo '' >> ~/.zshrc \
 && echo '# sdkman' >> ~/.zshrc \
 && echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> ~/.zshrc \
 && echo '[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"' >> ~/.zshrc

RUN zsh -lc "source ~/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.5-tem"

# nvm + Node.js LTS (PROFILE=/dev/null 로 자동 프로필 수정 차단, zshrc 직접 등록)
ENV NVM_DIR="/home/user/.nvm"

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | PROFILE=/dev/null bash \
 && echo '' >> ~/.zshrc \
 && echo '# nvm' >> ~/.zshrc \
 && echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc \
 && echo '[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"' >> ~/.zshrc \
 && echo '[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"' >> ~/.zshrc \
 && zsh -lc "source $NVM_DIR/nvm.sh && nvm install --lts && nvm alias default 'lts/*' && nvm use default && npm cache clean --force"

# AI CLIs: claude/agy → ~/.local/bin, codex → nvm 전역
ENV PATH="/home/user/.local/bin:$PATH"

RUN curl -fsSL https://claude.ai/install.sh | bash                                      # Claude Code
RUN zsh -lc "source $NVM_DIR/nvm.sh && npm install -g @openai/codex"                     # Codex
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash                         # Antigravity (PATH는 인스톨러가 자동 등록)

# entrypoint: root로 시작 → .ssh 권한/host key 정리 → gosu로 user 강등
USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/entrypoint.sh"]

# user 비밀번호 설정 (필요 시 주석 해제)
# RUN echo 'user:password' | chpasswd
