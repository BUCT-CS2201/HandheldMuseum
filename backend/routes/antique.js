const express = require('express')
const router = express.Router()
const mysqlService = require('../services/mysqlService')
const neo4jService = require('../services/neo4jService')

// 获取文物列表
router.get('/list', (req, res) => {
    const sql = 'SELECT c.relic_id id, c.name name, i.img_url image, c.dynasty type FROM cultural_relic c JOIN relic_image i ON c.relic_id=i.relic_id';
    mysqlService.query(sql, (err, results) => {
        if (err) {
            console.error('查询失败:', err);
            return res.status(500).json({ error: '数据库查询失败' });
        }

        // 结果转换为前端需要的格式
        const formatted = results.map(item => ({
            id: item.id,
            name: item.name,
            image: item.image,
            category: item.type
        }));

        res.json(formatted);
    });
});

module.exports = router
