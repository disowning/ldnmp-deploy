#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查参数
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}错误：请提供域名和邮箱${NC}"
    echo "使用方法: $0 your-domain.com your-email@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

echo -e "${GREEN}开始部署 LDNMP 环境...${NC}"

# 创建目录结构
echo -e "${YELLOW}创建目录结构...${NC}"
mkdir -p /www/wwwroot/jx099
cd /www/wwwroot/jx099 || exit

# 安装依赖
echo -e "${YELLOW}安装依赖...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git vim

# 克隆配置文件
echo -e "${YELLOW}克隆配置文件...${NC}"
if [ ! -d ".git" ]; then
    git clone https://github.com/disowning/ldnmp-deploy.git .
fi

# 创建必要的目录
mkdir -p nginx/conf.d nginx/ssl mysql/data mysql/conf.d sites/jx099

# 生成环境变量
echo -e "${YELLOW}配置环境变量...${NC}"
cat > .env << EOF
# MySQL 配置
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_DATABASE=jx099
MYSQL_CHARSET=utf8mb4
MYSQL_COLLATION=utf8mb4_unicode_ci

# NextAuth 配置
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=https://${DOMAIN}

# 域名配置
DOMAIN=${DOMAIN}
SSL_EMAIL=${EMAIL}

# GitHub 仓库
GITHUB_REPO=https://github.com/your-username/your-repo.git

# Node 环境
NODE_ENV=production

# 备份配置
BACKUP_DIR=/www/backup
BACKUP_KEEP_DAYS=7

# SSL 证书路径
SSL_CERTIFICATE=/etc/letsencrypt/live/${DOMAIN}/fullchain.pem
SSL_CERTIFICATE_KEY=/etc/letsencrypt/live/${DOMAIN}/privkey.pem
EOF

# 安装 Docker
echo -e "${YELLOW}安装 Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi
apt install -y docker-compose

# 配置 SSL 证书
echo -e "${YELLOW}配置 SSL 证书...${NC}"
apt install -y certbot

# 强制更新证书
echo -e "${YELLOW}申请/更新 SSL 证书...${NC}"
certbot certonly --standalone --non-interactive --force-renewal \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email

# 确保证书目录存在
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo -e "${RED}错误：SSL 证书申请失败${NC}"
    exit 1
fi

# 复制证书（确保目录存在）
echo -e "${YELLOW}复制 SSL 证书...${NC}"
mkdir -p nginx/ssl
cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" nginx/ssl/cert.pem
cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" nginx/ssl/key.pem

# 克隆项目代码
echo -e "${YELLOW}克隆项目代码...${NC}"
if [ ! -d "sites/jx099/.git" ]; then
    git clone $(grep GITHUB_REPO .env | cut -d= -f2) sites/jx099
fi

# 启动服务
echo -e "${YELLOW}启动 Docker 服务...${NC}"
docker-compose up -d

# 保存重要信息
echo -e "${YELLOW}保存重要信息...${NC}"
echo "MySQL Root 密码: $(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2)" > /root/jx099_credentials.txt
echo "NextAuth Secret: $(grep NEXTAUTH_SECRET .env | cut -d= -f2)" >> /root/jx099_credentials.txt
chmod 600 /root/jx099_credentials.txt

echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}请检查以下内容：${NC}"
echo "1. 访问 https://$DOMAIN 确认网站是否正常运行"
echo "2. 检查 docker-compose ps 确认所有服务是否正常"
echo "3. 检查日志 docker-compose logs -f"