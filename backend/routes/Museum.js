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

module.exports = router