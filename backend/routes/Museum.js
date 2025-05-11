const express = require('express')
const router = express.Router()
const mysqlService = require('../services/mysqlService')

// 获取所有公告
router.get('/list', (req, res) => {
    const sql = 'SELECT * FROM museum_notice'
    mysqlService.query(sql)
        .then(results => res.json(results))
        .catch(err => {
            console.error('查询失败:', err)
            res.status(500).json({ error: '数据库查询失败' })
        })
})

// 获取博物馆信息
router.get('/info', (req, res) => {
    const sql = `
        SELECT 
            m.museum_id,
            m.museum_name,
            mi.img_url as museum_image
        FROM 
            museum m
        LEFT JOIN 
            museum_image mi ON m.museum_id = mi.museum_id
        ORDER BY 
            m.museum_id ASC
    `
    mysqlService.query(sql)
        .then(results => {
            res.json(results)
        })
        .catch(err => {
            console.error('获取博物馆信息失败:', err)
            res.status(500).json({ error: '获取博物馆信息失败' })
        })
})

// 获取博物馆详情
router.get('/detail/:id', (req, res) => {
    const museumId = req.params.id;
    const sql = `
        SELECT 
            m.museum_id,
            m.museum_name,
            m.description,
            m.address,
            m.website_url,
            m.booking_url
        FROM 
            museum m
        WHERE 
            m.museum_id = ?
        LIMIT 1
    `
    mysqlService.query(sql, [museumId])
        .then(results => {
            if (results.length > 0) {
                console.log('博物馆详情数据:', JSON.stringify(results[0]));
                res.json(results[0])
            } else {
                res.status(404).json({ error: '博物馆不存在' })
            }
        })
        .catch(err => {
            console.error('获取博物馆详情失败:', err)
            res.status(500).json({ error: '获取博物馆详情失败' })
        })
})

// 获取博物馆藏品
router.get('/relics/:id', (req, res) => {
    const museumId = req.params.id;
    console.log('正在获取博物馆藏品，博物馆ID:', museumId);

    const sql = `
        SELECT 
            cr.relic_id,
            cr.name as relic_name,
            ri.img_url as relic_image
        FROM 
            cultural_relic cr
        LEFT JOIN
            relic_image ri ON cr.relic_id = ri.relic_id
        WHERE 
            cr.museum_id = ?
        ORDER BY 
            cr.relic_id ASC
    `;

    mysqlService.query(sql, [museumId])
        .then(results => {
            console.log('查询结果:', JSON.stringify(results));
            res.json(results)
        })
        .catch(err => {
            console.error('获取博物馆藏品失败，详细错误:', err);
            console.error('错误堆栈:', err.stack);
            res.status(500).json({ error: '获取博物馆藏品失败' })
        })
})

// 获取博物馆排行榜
router.get('/ranking', (req, res) => {
    const sql = `
        SELECT 
            m.museum_id,
            m.museum_name,
            m.address,
            mi.img_url as museum_image,
            COUNT(cr.relic_id) as relic_count
        FROM 
            museum m
        LEFT JOIN 
            cultural_relic cr ON m.museum_id = cr.museum_id
        LEFT JOIN
            museum_image mi ON m.museum_id = mi.museum_id
        GROUP BY 
            m.museum_id, m.museum_name, m.address, mi.img_url
        ORDER BY 
            relic_count DESC, m.museum_id ASC
    `;

    mysqlService.query(sql)
        .then(results => {
            console.log('博物馆排行榜数据:', JSON.stringify(results));
            res.json(results);
        })
        .catch(err => {
            console.error('获取博物馆排行榜失败:', err);
            res.status(500).json({ error: '获取博物馆排行榜失败' });
        });
});

module.exports = router