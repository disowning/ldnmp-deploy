#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查必要的环境变量
if [ -z "$MYSQL_ROOT_PASSWORD" ] || [ -z "$MYSQL_DATABASE" ] || [ -z "$BACKUP_DIR" ] || [ -z "$BACKUP_RETENTION_DAYS" ]; then
    echo -e "${RED}错误：缺少必要的环境变量${NC}"
    echo "请确保以下环境变量已设置："
    echo "- MYSQL_ROOT_PASSWORD"
    echo "- MYSQL_DATABASE"
    echo "- BACKUP_DIR"
    echo "- BACKUP_RETENTION_DAYS"
    exit 1
fi

# 设置备份目录
BACKUP_PATH="${BACKUP_DIR}/$(date +%Y%m%d)"
mkdir -p "$BACKUP_PATH"

echo -e "${YELLOW}开始备份...${NC}"

# 备份数据库
echo -e "${YELLOW}备份数据库...${NC}"
if docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" > "$BACKUP_PATH/database.sql"; then
    echo -e "${GREEN}数据库备份成功${NC}"
else
    echo -e "${RED}数据库备份失败${NC}"
    exit 1
fi

# 备份配置文件
echo -e "${YELLOW}备份配置文件...${NC}"
if tar -czf "$BACKUP_PATH/config.tar.gz" ./nginx ./nginx/conf.d ./nginx/ssl .env; then
    echo -e "${GREEN}配置文件备份成功${NC}"
else
    echo -e "${RED}配置文件备份失败${NC}"
    exit 1
fi

# 删除过期备份
echo -e "${YELLOW}清理旧备份...${NC}"
find "$BACKUP_DIR" -type d -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -rf {} \;

echo -e "${GREEN}备份完成！备份文件保存在: $BACKUP_PATH${NC}"
