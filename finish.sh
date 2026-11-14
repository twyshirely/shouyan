#!/bin/bash
# 寿宴请柬 · 服务器一键收尾（root 执行）
# 前置条件：DNSPod 已添加 @ 和 www 两条 A 记录，且解析已生效
# 作用：绑定域名 -> 签发 HTTPS 证书 -> 自动开启 443 与 80 跳转 -> 自检
set -e

echo "== 1/6 拉取最新版请柬（浅朱红配色 + 备案号） =="
curl -fsSL https://twyshirely.github.io/shouyan/ -o /var/www/html/index.html \
  || curl -fsSL https://cdn.jsdelivr.net/gh/twyshirely/shouyan@main/index.html -o /var/www/html/index.html
if grep -q "浙ICP备2026094381号" /var/www/html/index.html; then
  echo "  OK $(stat -c%s /var/www/html/index.html) bytes"
else
  echo "  页面校验失败，请停止并把输出发我"; exit 1
fi

echo "== 2/6 解析自检 =="
getent hosts twyshirely100.cn | head -2 || echo "  警告：域名尚未解析，请先在 DNSPod 添加 A 记录"

echo "== 3/6 写入站点配置 =="
cat > /etc/nginx/sites-available/shouyan <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name twyshirely100.cn www.twyshirely100.cn;
    root /var/www/html;
    index index.html;
    charset utf-8;
    location / { try_files $uri $uri/ =404; }
}
EOF
ln -sfn /etc/nginx/sites-available/shouyan /etc/nginx/sites-enabled/shouyan
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "== 4/6 安装 certbot =="
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq certbot python3-certbot-nginx

echo "== 5/6 签发证书（自动配置 443 + 80 跳转） =="
certbot --nginx -d twyshirely100.cn -d www.twyshirely100.cn \
  --redirect --register-unsafely-without-email --agree-tos -n

echo "== 6/6 自检 =="
systemctl reload nginx
curl -sI https://twyshirely100.cn/ | head -4
echo "完成。把上面的输出发我，我从外网复测并重新生成二维码。"
