#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查参数
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}错误：请提供域名和邮箱${NC}"
    echo "使用方法: $0 your-domain.com your-email@example.com [github-repo-url]"
    exit 1
fi

DOMAIN=$1
EMAIL=$2
GITHUB_REPO=${3:-"https://github.com/disowning/next-app-template.git"}  # 设置默认仓库或用户提供的仓库

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
GITHUB_REPO=${GITHUB_REPO}

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

# 检查证书是否存在且有效
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo -e "${YELLOW}证书已存在，跳过申请步骤${NC}"
else
    # 申请新证书
    echo -e "${YELLOW}申请 SSL 证书...${NC}"
    certbot certonly --standalone --non-interactive \
        -d "$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email
fi

# 确保证书目录存在
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo -e "${RED}错误：SSL 证书申请失败${NC}"
    echo -e "${YELLOW}提示：由于 Let's Encrypt 速率限制，请稍后再试${NC}"
    echo "或者手动申请证书："
    echo "certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email"
    exit 1
fi

# 复制证书（确保目录存在）
echo -e "${YELLOW}复制 SSL 证书...${NC}"
mkdir -p nginx/ssl
cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" nginx/ssl/cert.pem
cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" nginx/ssl/key.pem

# 克隆项目代码
echo -e "${YELLOW}克隆项目代码...${NC}"
if [ -d "sites/jx099" ]; then
    echo -e "${YELLOW}项目目录已存在，跳过克隆...${NC}"
else
    echo -e "${YELLOW}正在从 ${GITHUB_REPO} 克隆代码...${NC}"
    GIT_TERMINAL_PROMPT=0 git clone ${GITHUB_REPO} sites/jx099 || {
        echo -e "${RED}项目代码克隆失败。${NC}"
        echo -e "${YELLOW}请检查仓库地址是否正确：${NC}"
        echo "${GITHUB_REPO}"
        echo -e "${YELLOW}提示：如果是私有仓库，请使用 Personal Access Token${NC}"
        echo -e "${YELLOW}格式：https://your-token@github.com/username/repo.git${NC}"
        echo -e "${YELLOW}或者手动克隆仓库到 sites/jx099 目录${NC}"
        exit 1
    }
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