const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// 数据文件路径
const DATA_DIR = path.join(__dirname, '..', 'data');
const DATA_FILE = path.join(DATA_DIR, 'product-library-data.json');

// 确保数据目录存在
if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
}

// 中间件
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// 获取数据
app.get('/api/data', (req, res) => {
    try {
        if (fs.existsSync(DATA_FILE)) {
            const data = fs.readFileSync(DATA_FILE, 'utf8');
            res.json(JSON.parse(data));
        } else {
            res.json({ products: [], settings: {} });
        }
    } catch (error) {
        console.error('读取数据失败:', error);
        res.status(500).json({ error: '读取数据失败' });
    }
});

// 保存数据
app.post('/api/data', (req, res) => {
    try {
        const data = JSON.stringify(req.body, null, 2);
        fs.writeFileSync(DATA_FILE, data, 'utf8');
        res.json({ success: true, message: '保存成功' });
    } catch (error) {
        console.error('保存数据失败:', error);
        res.status(500).json({ error: '保存数据失败' });
    }
});

// 检查健康状态
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
    console.log(`服务器运行在端口 ${PORT}`);
    console.log(`数据文件: ${DATA_FILE}`);
});
