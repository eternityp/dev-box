# dev-box

다수의 사용자가 한 개의 서버를 사용할 때 격리해서 사용하기 위해 만들었습니다. 

SSH로 접속해 쓰는 Ubuntu 24.04 기반 개인 개발 환경 컨테이너입니다.
zsh + Oh My Zsh + powerlevel10k, 한글 로케일(ko_KR.UTF-8)/KST 타임존이 기본 설정되어 있습니다.
pyenv(Python 3.10), sdkman(Java 21), nvm(Node.js LTS) 런타임이 미리 설치됩니다.

- 실행: `ssh/authorized_keys`에 공개키 등록 후 `docker compose up -d --build`
- 접속: `ssh user@<host> -p 40022` (키 인증만 허용, 비밀번호/root 로그인 차단)
- 볼륨: `./data` → `/data`, `./ssh` → `~/.ssh`, `./.p10k.zsh` → 프롬프트 설정
- GPU 호스트는 `docker-compose.yml`의 nvidia 주석을 해제해 사용합니다.


--

AI CLI(Claude Code, Codex, Antigravity)도 추가