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
// ✅ 获取文物详情（含多图和视频）
router.get('/detail/:id', async (req, res) => {
    const id = req.params.id;
    const sql = `
    SELECT
      a.relic_id, a.name, a.type, a.size, a.matrials, a.dynasty, a.author, a.entry_time, a.description,
      GROUP_CONCAT(DISTINCT ai.img_url) AS images,
      GROUP_CONCAT(DISTINCT av.video_url) AS videos
    FROM cultural_relic a
    LEFT JOIN relic_image ai ON a.relic_id = ai.relic_id
    LEFT JOIN relic_video av ON a.relic_id = av.relic_id AND av.is_official=1
    WHERE a.relic_id =?
    GROUP BY a.relic_id
  `;
    try {
        const results = await mysqlService.query(sql, [id]);
        if (results.length === 0) {
            return res.status(404).json({ error: 'Not found' });
        }
        const item = results[0];
        item.images = item.images? item.images.split(',') : [];
        item.videos = item.videos? item.videos.split(',') : [];
        res.json(item);
    } catch (err) {
        console.error('查询过程中出现错误:', err);
        res.status(500).json({ error: err.message });
    }
});
module.exports = router
