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

# 检查系统要求
echo -e "${YELLOW}检查系统要求...${NC}"

# 安装依赖
echo -e "${YELLOW}安装依赖...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git vim

# 创建目录结构
echo -e "${YELLOW}创建目录结构...${NC}"
mkdir -p /www/wwwroot/jx099
cd /www/wwwroot/jx099

# 克隆配置文件
echo -e "${YELLOW}克隆配置文件...${NC}"
git clone https://github.com/disowning/ldnmp-deploy.git .

# 创建必要的目录
mkdir -p nginx/conf.d nginx/ssl mysql/data mysql/conf.d sites/jx099

# 生成环境变量
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
NEXTAUTH_SECRET=$(openssl rand -base64 32)

# 配置环境变量
echo -e "${YELLOW}配置环境变量...${NC}"
if [ ! -f ".env.example" ]; then
    echo -e "${RED}错误：环境变量模板文件不存在${NC}"
    exit 1
fi

cp .env.example .env
sed -i "s/your_strong_password/$MYSQL_ROOT_PASSWORD/" .env
sed -i "s/your_secret_key/$NEXTAUTH_SECRET/" .env
sed -i "s/your-domain.com/$DOMAIN/g" .env
sed -i "s/your-email@example.com/$EMAIL/g" .env

# 安装 Docker
echo -e "${YELLOW}安装 Docker...${NC}"
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose

# 配置 SSL 证书
echo -e "${YELLOW}配置 SSL 证书...${NC}"
apt install -y certbot
certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email

# 复制证书
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem nginx/ssl/cert.pem
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem nginx/ssl/key.pem

# 克隆项目代码
echo -e "${YELLOW}克隆项目代码...${NC}"
git clone $(grep GITHUB_REPO .env | cut -d= -f2) sites/jx099

# 启动服务
echo -e "${YELLOW}启动 Docker 服务...${NC}"
docker-compose up -d

# 等待服务就绪
echo -e "${YELLOW}等待服务就绪...${NC}"
sleep 10

# 初始化数据库
echo -e "${YELLOW}初始化数据库...${NC}"
chmod +x scripts/init-db.sh
./scripts/init-db.sh

# 设置自动更新证书
echo -e "${YELLOW}配置证书自动更新...${NC}"
echo "0 0 1 * * certbot renew --quiet" | crontab -

# 配置备份
echo -e "${YELLOW}配置自动备份...${NC}"
chmod +x scripts/backup.sh
echo "0 3 * * * /www/wwwroot/jx099/scripts/backup.sh" | crontab -

echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}请检查以下内容：${NC}"
echo "1. 访问 https://$DOMAIN 确认网站是否正常运行"
echo "2. 检查 docker-compose ps 确认所有服务是否正常"
echo "3. 检查日志 docker-compose logs -f"

# 保存重要信息
echo -e "${YELLOW}保存重要信息...${NC}"
echo "MySQL Root 密码: $MYSQL_ROOT_PASSWORD" > /root/jx099_credentials.txt
echo "NextAuth Secret: $NEXTAUTH_SECRET" >> /root/jx099_credentials.txt
chmod 600 /root/jx099_credentials.txt