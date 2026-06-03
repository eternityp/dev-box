#!/usr/bin/env bash
set -e

USERNAME=${USERNAME:-user}
SSHD_DIR=/home/user/sshd

echo "[entrypoint] starting..."

# 마운트된 .ssh / p10k 권한 정리 (키 인증 실패 방지)
if [ -d /home/user/.ssh ]; then
    chown -R user:user /home/user/.ssh
    chmod 700 /home/user/.ssh
    [ -f /home/user/.ssh/authorized_keys ] && chmod 600 /home/user/.ssh/authorized_keys
fi
[ -f /home/user/.p10k.zsh ] && chown user:user /home/user/.p10k.zsh || true

mkdir -p /run/sshd

# sshd_config / host key 매번 새로 생성 (이미지에 굽지 않음)
mkdir -p "$SSHD_DIR"
printf '%s\n' \
    'Port 2222' \
    'HostKey /home/user/sshd/ssh_host_rsa_key' \
    'HostKey /home/user/sshd/ssh_host_ecdsa_key' \
    'HostKey /home/user/sshd/ssh_host_ed25519_key' \
    'PidFile /home/user/sshd/sshd.pid' \
    'PermitRootLogin no' \
    'PasswordAuthentication no' \
    'PubkeyAuthentication yes' \
    'UsePAM no' \
    'AuthorizedKeysFile /home/user/.ssh/authorized_keys' \
    'X11Forwarding yes' \
    'AllowTcpForwarding yes' \
    'Subsystem sftp /usr/lib/openssh/sftp-server' \
    > "$SSHD_DIR/sshd_config"

echo "[entrypoint] generating host keys"
rm -f "$SSHD_DIR"/ssh_host_*
for t in rsa ecdsa ed25519; do
    ssh-keygen -q -t "$t" -N "" -f "$SSHD_DIR/ssh_host_${t}_key"
done
chown -R user:user "$SSHD_DIR"

# user로 강등하여 sshd 실행 (:2222)
echo "[entrypoint] starting sshd on :2222 as '$USERNAME'..."
exec gosu "$USERNAME" /usr/sbin/sshd -D -f "$SSHD_DIR/sshd_config"
