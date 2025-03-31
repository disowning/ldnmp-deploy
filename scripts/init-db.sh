#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}开始初始化数据库...${NC}"

# 检查环境变量
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}错误：未设置 DATABASE_URL 环境变量${NC}"
    exit 1
fi

# 进入项目目录
cd sites/jx099 || {
    echo -e "${RED}错误：无法进入项目目录${NC}"
    exit 1
}

# 生成 Prisma Client
echo -e "${YELLOW}生成 Prisma Client...${NC}"
if docker-compose exec nextjs npx prisma generate; then
    echo -e "${GREEN}Prisma Client 生成成功${NC}"
else
    echo -e "${RED}Prisma Client 生成失败${NC}"
    exit 1
fi

# 同步数据库架构
echo -e "${YELLOW}同步数据库架构...${NC}"
if docker-compose exec nextjs npx prisma db push; then
    echo -e "${GREEN}数据库架构同步成功${NC}"
else
    echo -e "${RED}数据库架构同步失败${NC}"
    exit 1
fi

# 检查是否有 seed 脚本
if [ -f "prisma/seed.ts" ]; then
    echo -e "${YELLOW}导入测试数据...${NC}"
    if docker-compose exec nextjs npx prisma db seed; then
        echo -e "${GREEN}测试数据导入成功${NC}"
    else
        echo -e "${RED}测试数据导入失败${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}未找到 seed 脚本，跳过测试数据导入${NC}"
fi

echo -e "${GREEN}数据库初始化完成！${NC}" 