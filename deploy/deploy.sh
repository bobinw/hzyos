#!/bin/bash
# 阿里云服务器部署脚本 - Ubuntu

set -e

echo "========== 福利团购运营系统部署 =========="

# 更新系统
echo "[1/5] 更新系统..."
sudo apt update && sudo apt upgrade -y

# 安装Nginx
echo "[2/5] 安装Nginx..."
sudo apt install -y nginx

# 创建目录
echo "[3/5] 创建目录..."
sudo mkdir -p /var/www/hzyos
sudo mkdir -p /var/www/hzyos/libs

# 复制文件（假设文件已上传到 /tmp/hzyos/）
echo "[4/5] 复制文件..."
if [ -f "/tmp/hzyos/product-library-cloud.html" ]; then
    sudo cp /tmp/hzyos/product-library-cloud.html /var/www/hzyos/
    sudo cp -r /tmp/hzyos/libs/* /var/www/hzyos/libs/
    echo "文件复制完成"
else
    echo "警告: /tmp/hzyos/ 目录下未找到文件，请手动上传"
fi

# 设置权限
sudo chown -R www-data:www-data /var/www/hzyos
sudo chmod -R 755 /var/www/hzyos

# 配置Nginx
echo "[5/5] 配置Nginx..."
sudo cp /tmp/hzyos/hzyos.conf /etc/nginx/sites-available/hzyos
sudo ln -sf /etc/nginx/sites-available/hzyos /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 测试并重启
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "========== 部署完成 =========="
echo "请通过 http://服务器IP 访问"
