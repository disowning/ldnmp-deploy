#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查项目名称参数
if [ -z "$1" ]; then
    echo -e "${RED}错误：请提供项目名称${NC}"
    echo "使用方法: $0 <项目名称>"
    exit 1
fi

PROJECT_NAME=$1
PORT_FILE=".port_allocations"

# 如果端口分配文件不存在，创建它
if [ ! -f "$PORT_FILE" ]; then
    touch "$PORT_FILE"
fi

# 检查项目是否已经有分配的端口
EXISTING_PORT=$(grep "^$PROJECT_NAME:" "$PORT_FILE" | cut -d':' -f2)
if [ ! -z "$EXISTING_PORT" ]; then
    echo -e "${GREEN}项目 '$PROJECT_NAME' 已分配端口: $EXISTING_PORT${NC}"
    exit 0
fi

# 获取当前使用的最大端口号
MAX_PORT=$(grep -o '[0-9]*' "$PORT_FILE" | sort -nr | head -n1)
if [ -z "$MAX_PORT" ]; then
    MAX_PORT=2999
fi

# 分配新端口
NEW_PORT=$((MAX_PORT + 1))

# 检查端口是否在有效范围内
if [ $NEW_PORT -gt 3999 ]; then
    echo -e "${RED}错误：端口超出范围 (3000-3999)${NC}"
    exit 1
fi

# 保存端口分配
echo "$PROJECT_NAME:$NEW_PORT" >> "$PORT_FILE"

echo -e "${GREEN}为项目 '$PROJECT_NAME' 分配端口: $NEW_PORT${NC}"
echo -e "${YELLOW}请将此端口添加到项目的 .env 文件中：${NC}"
echo "PORT=$NEW_PORT" 