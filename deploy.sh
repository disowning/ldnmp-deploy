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

# 错误处理函数
handle_error() {
    echo -e "${RED}错误: $1${NC}"
    exit 1
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        handle_error "$1 未安装"
    fi
}

# 检查系统要求
check_requirements() {
    echo -e "${YELLOW}检查系统要求...${NC}"
    
    # 检查操作系统
    if [ ! -f /etc/os-release ]; then
        handle_error "不支持的操作系统"
    fi
    
    # 检查内存
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ $total_mem -lt 2048 ]; then
        handle_error "内存不足，至少需要 2GB 内存"
    fi
    
    # 检查磁盘空间
    free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ $free_space -lt 10240 ]; then
        handle_error "磁盘空间不足，至少需要 10GB 可用空间"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}安装依赖...${NC}"
    
    # 更新系统
    apt update || handle_error "系统更新失败"
    apt upgrade -y || handle_error "系统升级失败"
    
    # 安装必要工具
    apt install -y curl wget git vim || handle_error "工具安装失败"
    
    # 安装 Docker
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh || handle_error "Docker 安装失败"
        systemctl start docker || handle_error "Docker 启动失败"
        systemctl enable docker || handle_error "Docker 设置开机启动失败"
    fi
    
    # 安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        apt install -y docker-compose || handle_error "Docker Compose 安装失败"
    fi
}

# 创建目录结构
create_directories() {
    echo -e "${YELLOW}创建目录结构...${NC}"
    
    mkdir -p /www/wwwroot/{nginx/{conf.d,ssl},mysql/{data,conf.d},sites/jx099} || handle_error "目录创建失败"
}

# 配置 SSL 证书
setup_ssl() {
    echo -e "${YELLOW}配置 SSL 证书...${NC}"
    
    # 安装 certbot
    apt install -y certbot || handle_error "Certbot 安装失败"
    
    # 申请证书
    certbot certonly --standalone \
        -d $DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --non-interactive || handle_error "SSL 证书申请失败"
    
    # 复制证书
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /www/wwwroot/nginx/ssl/cert.pem || handle_error "证书复制失败"
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /www/wwwroot/nginx/ssl/key.pem || handle_error "私钥复制失败"
}

# 配置环境变量
setup_env() {
    echo -e "${YELLOW}配置环境变量...${NC}"
    
    # 复制环境变量示例文件
    cp .env.example .env || handle_error "环境变量文件创建失败"
    
    # 生成随机密码
    mysql_password=$(openssl rand -base64 32)
    nextauth_secret=$(openssl rand -base64 32)
    
    # 更新环境变量
    sed -i "s/your_strong_password/$mysql_password/" .env
    sed -i "s/your_secret_key/$nextauth_secret/" .env
    sed -i "s/your-domain.com/$DOMAIN/" .env
}

# 启动服务
start_services() {
    echo -e "${YELLOW}启动服务...${NC}"
    
    docker-compose up -d || handle_error "服务启动失败"
    
    # 等待服务启动
    sleep 10
    
    # 检查服务状态
    if ! docker-compose ps | grep -q "Up"; then
        handle_error "服务启动失败"
    fi
}

# 配置定时任务
setup_cron() {
    echo -e "${YELLOW}配置定时任务...${NC}"
    
    # 添加备份任务
    echo "0 3 * * * /www/wwwroot/scripts/backup.sh" | crontab - || handle_error "备份任务配置失败"
    
    # 添加证书更新任务
    echo "0 0 1 * * certbot renew --quiet" | crontab - || handle_error "证书更新任务配置失败"
}

# 保存凭证
save_credentials() {
    echo -e "${YELLOW}保存凭证...${NC}"
    
    echo "MySQL Root 密码: $mysql_password" > /root/credentials.txt
    echo "NextAuth Secret: $nextauth_secret" >> /root/credentials.txt
    chmod 600 /root/credentials.txt
}

# 主函数
main() {
    echo -e "${GREEN}开始部署 LDNMP 环境...${NC}"
    
    check_requirements
    install_dependencies
    create_directories
    setup_ssl
    setup_env
    start_services
    setup_cron
    save_credentials
    
    echo -e "${GREEN}部署完成！${NC}"
    echo -e "${GREEN}请检查以下内容：${NC}"
    echo "1. 访问 https://$DOMAIN 确认网站是否正常运行"
    echo "2. 检查 docker-compose ps 确认所有服务是否正常"
    echo "3. 检查 /root/credentials.txt 保存的密码"
    echo "4. 查看 docker-compose logs 检查是否有错误"
}

# 执行主函数
main
