# LDNMP 自动化部署脚本

一键部署 LDNMP (Linux + Docker + Nginx + MySQL + Node.js) 环境。

## 使用方法

1. 准备工作：
   - 一台 Linux 服务器（Ubuntu/Debian）
   - 域名已解析到服务器
   - 确保 80 和 443 端口未被占用

2. 一键部署：
```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/ldnmp-deploy/main/deploy.sh | bash
```

## 包含功能

- 自动安装 Docker 和 Docker Compose
- 配置 Nginx 反向代理
- 自动申请和续期 SSL 证书
- 配置 MySQL 数据库
- 自动备份数据
- 服务监控
- 日志管理
- Prisma 数据库管理
- 自动化数据库迁移

## 配置说明

1. 修改 `.env.example` 为 `.env`，并设置：
   - MySQL 密码（使用 `openssl rand -base64 32` 生成）
   - NextAuth 密钥（使用 `openssl rand -base64 32` 生成）
   - 域名
   - 其他配置项

2. 检查 `nginx/conf.d/default.conf` 中的域名配置

## 数据库管理

1. 初始化数据库：
```bash
./scripts/init-db.sh
```

2. 手动执行 Prisma 命令：
```bash
# 生成 Prisma Client
docker-compose exec nextjs npx prisma generate

# 同步数据库架构
docker-compose exec nextjs npx prisma db push

# 导入测试数据（如果有 seed 脚本）
docker-compose exec nextjs npx prisma db seed
```

## 维护命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 手动备份
./scripts/backup.sh

# 初始化数据库
./scripts/init-db.sh
```

## 多项目部署

1. 端口分配：
```bash
# 为新项目分配端口
./scripts/port_allocator.sh your-project-name
```

2. 环境变量：
- 每个项目需要独立的 `.env` 文件
- 使用不同的端口号
- 使用不同的数据库名

## 注意事项

- 首次部署需要 5-10 分钟
- 请保存好生成的密码
- 定期检查备份
- 数据库变更后需要执行 `prisma generate` 和 `prisma db push`
- 建议在开发环境测试数据库变更