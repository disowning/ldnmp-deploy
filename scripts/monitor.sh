#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 设置告警邮箱
ALERT_EMAIL="your@email.com"

# 检查服务状态
echo -e "${YELLOW}检查服务状态...${NC}"
SERVICES_STATUS=$(docker-compose ps)
if echo "$SERVICES_STATUS" | grep -q "Exit"; then
    echo -e "${RED}发现服务异常，发送告警邮件...${NC}"
    echo "$SERVICES_STATUS" | mail -s "服务异常告警" $ALERT_EMAIL
else
    echo -e "${GREEN}所有服务运行正常${NC}"
fi

# 检查资源使用情况
echo -e "${YELLOW}检查资源使用情况...${NC}"
RESOURCE_USAGE=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}")
echo "$RESOURCE_USAGE" | mail -s "服务器资源使用报告" $ALERT_EMAIL

# 检查磁盘使用情况
echo -e "${YELLOW}检查磁盘使用情况...${NC}"
DISK_USAGE=$(df -h /)
echo "$DISK_USAGE" | mail -s "磁盘使用报告" $ALERT_EMAIL

# 检查日志错误
echo -e "${YELLOW}检查错误日志...${NC}"
ERROR_LOGS=$(docker-compose logs --tail=100 | grep -i "error")
if [ ! -z "$ERROR_LOGS" ]; then
    echo -e "${RED}发现错误日志，发送告警邮件...${NC}"
    echo "$ERROR_LOGS" | mail -s "错误日志告警" $ALERT_EMAIL
else
    echo -e "${GREEN}未发现错误日志${NC}"
fi

echo -e "${GREEN}监控检查完成${NC}"
