#!/bin/bash
# 云端版部署脚本 - Ubuntu

set -e

echo "========== 福利团购运营系统（云端版）部署 =========="

# 更新系统
echo "[1/6] 更新系统..."
sudo apt update && sudo apt upgrade -y

# 安装Node.js
echo "[2/6] 安装Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi
node -v
npm -v

# 安装PM2（进程管理器）
echo "[3/6] 安装PM2..."
sudo npm install -g pm2

# 安装Nginx
echo "[4/6] 安装Nginx..."
sudo apt install -y nginx

# 创建目录结构
echo "[5/6] 创建目录结构..."
sudo mkdir -p /var/www/hzyos/public/libs
sudo mkdir -p /var/www/hzyos/server
sudo mkdir -p /var/www/hzyos/data

# 复制前端文件
echo "[6/6] 复制文件..."
if [ -f "/tmp/hzyos/product-library-cloud.html" ]; then
    sudo cp /tmp/hzyos/product-library-cloud.html /var/www/hzyos/public/
    sudo cp -r /tmp/hzyos/libs/* /var/www/hzyos/public/libs/
    sudo cp -r /tmp/hzyos/server/* /var/www/hzyos/server/
    echo "文件复制完成"
else
    echo "警告: /tmp/hzyos/ 目录下未找到文件，请手动上传"
fi

# 设置权限
sudo chown -R www-data:www-data /var/www/hzyos
sudo chmod -R 755 /var/www/hzyos

# 配置Nginx
echo "配置Nginx..."
sudo cp /tmp/hzyos/nginx.conf /etc/nginx/sites-available/hzyos
sudo ln -sf /etc/nginx/sites-available/hzyos /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 安装后端依赖
echo "安装后端依赖..."
cd /var/www/hzyos/server
sudo npm install

# 启动后端服务
echo "启动后端服务..."
sudo pm2 start server.js --name hzyos-api
sudo pm2 save
sudo pm2 startup

# 重启Nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "========== 部署完成 =========="
echo "前端: http://服务器IP"
echo "API: http://服务器IP/api"
echo ""
echo "常用命令:"
echo "  查看日志: pm2 logs hzyos-api"
echo "  重启服务: pm2 restart hzyos-api"
echo "  查看状态: pm2 status"
