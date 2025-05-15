const express = require('express')
const router = express.Router()
const mysqlService = require('../services/mysqlService')
const neo4jService = require('../services/neo4jService')
const path = require('path')
const fs = require('fs')

// 获取文物列表
router.get('/list', (req, res) => {
    const sql = `
        SELECT 
            c.relic_id AS id, 
            c.name AS name, 
            i.img_url AS image, 
            c.dynasty AS category, 
            c.likes_count AS like_count,
            c.views_count AS views_count
        FROM 
            cultural_relic c 
        LEFT JOIN 
            relic_image i ON c.relic_id = i.relic_id
    `;
    mysqlService.query(sql, (err, results) => {
        if (err) {
            console.error('查询失败:', err);
            return res.status(500).json({ error: '数据库查询失败' });
        }

        // 结果直接返回即可，字段名已和前端一致
        res.json(results);
    });
});
// 点赞接口
router.post('/like/:id', (req, res) => {
    const id = req.params.id;
    const { user_id } = req.body;

    // 先检查是否已经点赞
    const checkSql = 'SELECT COUNT(*) as count FROM relic_like WHERE relic_id = ? AND user_id = ?';
    mysqlService.query(checkSql, [id, user_id], (err, results) => {
        if (err) {
            console.error('检查点赞状态失败:', err);
            return res.status(500).json({ error: '数据库查询失败' });
        }

        const hasLiked = results[0].count > 0;
        if (hasLiked) {
            // 取消点赞
            const deleteSql = 'DELETE FROM relic_like WHERE relic_id = ? AND user_id = ?';
            const updateSql = 'UPDATE cultural_relic SET likes_count = likes_count - 1 WHERE relic_id = ?';
            mysqlService.query(deleteSql, [id, user_id], (err) => {
                if (err) {
                    console.error('取消点赞失败:', err);
                    return res.status(500).json({ error: '数据库操作失败' });
                }
                mysqlService.query(updateSql, [id], (err) => {
                    if (err) {
                        console.error('更新点赞数失败:', err);
                        return res.status(500).json({ error: '数据库操作失败' });
                    }
                    const getCountSql = 'SELECT likes_count as like_count FROM cultural_relic WHERE relic_id = ?';
                    mysqlService.query(getCountSql, [id], (err, results) => {
                        if (err) {
                            return res.status(500).json({ error: '查询点赞数失败' });
                        }
                        res.json({ like_count: results[0].like_count });
                    });
                });
            });
        } else {
            // 添加点赞
            const insertSql = 'INSERT INTO relic_like (relic_id, user_id) VALUES (?, ?)';
            const updateSql = 'UPDATE cultural_relic SET likes_count = likes_count + 1 WHERE relic_id = ?';
            mysqlService.query(insertSql, [id, user_id], (err) => {
                if (err) {
                    console.error('添加点赞失败:', err);
                    return res.status(500).json({ error: '数据库操作失败' });
                }
                mysqlService.query(updateSql, [id], (err) => {
                    if (err) {
                        console.error('更新点赞数失败:', err);
                        return res.status(500).json({ error: '数据库操作失败' });
                    }
                    const getCountSql = 'SELECT likes_count as like_count FROM cultural_relic WHERE relic_id = ?';
                    mysqlService.query(getCountSql, [id], (err, results) => {
                        if (err) {
                            return res.status(500).json({ error: '查询点赞数失败' });
                        }
                        res.json({ like_count: results[0].like_count });
                    });
                });
            });
        }
    });
});
// 获取文物评论列表
router.get('/comments/:id', async (req, res) => {
    const id = req.params.id;
    console.log('收到评论请求，relic_id:', id);
    const sql = `
        SELECT
            rc.comment_id,
            rc.content,
            rc.like_count,
            rc.reply_count,
            rc.create_time,
            rc.parent_id,
            rc.status,
            rc.is_deleted,
            u.name AS user_name
        FROM
            relic_comment rc
        JOIN
            user u ON rc.user_id = u.user_id
        LEFT JOIN
            user_image ui ON rc.user_id = ui.user_id AND ui.status = 1
        WHERE
            rc.relic_id = ? AND rc.is_deleted = 0 AND rc.status = 1
        ORDER BY
            rc.create_time DESC
    `;
    const start = Date.now();
    try {
        const results = await mysqlService.query(sql, [id]);
        console.log('SQL执行耗时:', Date.now() - start, 'ms');
        res.json(results);
    } catch (err) {
        console.error('查询评论失败:', err);
        res.status(500).json({ error: '数据库查询失败' });
    }
});

// 提交评论
router.post('/upload_comments/:id', async (req, res) => {
    // 输出请求的详细信息
    console.log('接收到评论提交请求');
    console.log('请求参数:', req.params);
    console.log('请求体:', req.body);

    const relicId = req.params.id; // 从路由参数中获取 relic_id
    const { user_id, content, parent_id } = req.body; // 从请求体中获取用户ID、评论内容和父评论ID

    // 输出获取到的参数值
    console.log('文物ID (relic_id):', relicId);
    console.log('用户ID (user_id):', user_id);
    console.log('评论内容 (content):', content);
    console.log('父评论ID (parent_id):', parent_id);

    const sql = 'INSERT INTO relic_comment (relic_id, user_id, content, parent_id) VALUES (?, ?, ?, ?)';

    // 输出即将执行的 SQL 语句和参数
    console.log('即将执行的 SQL 语句:', sql);
    console.log('SQL 参数:', [relicId, user_id, content, parent_id]);

    const results = await mysqlService.query(sql, [relicId, user_id, content, parent_id]);
    console.log(results);
    res.json({ comment_id: results.insertId });
});

// 点赞评论
router.post('/comments/like/:comment_id', (req, res) => {
    const comment_id = req.params.comment_id;
    const { user_id } = req.body;
    const sql1 = 'INSERT INTO comment_like (comment_id, user_id) VALUES (?,?)';
    mysqlService.query(sql1, [comment_id, user_id], (err1, result1) => {
        if (err1) {
            console.error('点赞评论失败:', err1);
            return res.status(500).json({ error: '数据库插入失败' });
        }
        const sql2 = 'UPDATE relic_comment SET like_count = like_count + 1 WHERE comment_id = ?';
        mysqlService.query(sql2, [comment_id], (err2, result2) => {
            if (err2) {
                console.error('更新评论点赞数失败:', err2);
                return res.status(500).json({ error: '数据库更新失败' });
            }
            const sql3 = 'SELECT like_count FROM relic_comment WHERE comment_id = ?';
            mysqlService.query(sql3, [comment_id], (err3, results3) => {
                if (err3) {
                    console.error('查询评论点赞数失败:', err3);
                    return res.status(500).json({ error: '数据库查询失败' });
                }
                res.json({ like_count: results3[0].like_count });
            });
        });
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
        item.images = item.images ? item.images.split(',') : [];
        item.videos = item.videos ? item.videos.split(',') : [];
        res.json(item);
    } catch (err) {
        console.error('查询过程中出现错误:', err);
        res.status(500).json({ error: err.message });
    }
});

router.get('/comment_status/:user_id', (req, res) => {
    const user_id = req.params.user_id;
    const sql = 'SELECT comment_status, name FROM user WHERE user_id = ?';
    mysqlService.query(sql, [user_id], (err, results) => {
        if (err || results.length === 0) {
            return res.status(500).json({ error: '查询失败' });
        }
        const resultObj = results[0];
        if (resultObj.comment_status !== 1) {
            return res.status(500).json({ error: '您已被禁止评论' });
        }
        res.json({ comment_status: resultObj.comment_status, name: resultObj.name });
    });
});

// 获取文物点赞和收藏状态
router.get('/status/:id', async (req, res) => {
    console.log('收到 status 路由请求:', req.url, req.params, req.query);
    const id = Number(req.params.id);
    const userId = Number(req.query.user_id);

    const sql = `
    SELECT 
      c.likes_count as like_count,
      (SELECT COUNT(*) FROM user_favorite WHERE relic_id = ? AND user_id = ? AND favorite_type = 1) as favorite_count,
      (SELECT COUNT(*) FROM relic_like WHERE relic_id = ? AND user_id = ?) as is_liked,
      (SELECT COUNT(*) FROM user_favorite WHERE relic_id = ? AND user_id = ? AND favorite_type = 1) as is_favorited
    FROM cultural_relic c
    WHERE c.relic_id = ?
  `;

    try {
        const results = await mysqlService.query(sql, [id, userId, id, userId, id, userId, id]);
        if (!results || results.length === 0) {
            console.log('status接口SQL结果为空:', results);
            return res.status(404).json({ error: '文物不存在' });
        }
        const result = results[0];
        console.log('status接口SQL结果:', results);
        console.log('接口返回like_count:', result.like_count);
        res.json({
            like_count: result.like_count,
            favorite_count: result.favorite_count,
            is_liked: result.is_liked > 0,
            is_favorited: result.is_favorited > 0
        });
    } catch (err) {
        console.error('查询状态失败:', err);
        res.status(500).json({ error: '数据库查询失败' });
    }
});

// 更新文物浏览量
router.post('/views/:id', async (req, res) => {
    const id = req.params.id;
    //const { user_id } = req.body;

    try {
        // 1. 获取文物的 museum_id
        // const getMuseumSql = 'SELECT museum_id FROM cultural_relic WHERE relic_id = ?';
        // const museumResult = await mysqlService.query(getMuseumSql, [id]);
        // if (museumResult.length === 0) {
        //     return res.status(404).json({ error: '文物不存在' });
        // }
        // const museum_id = museumResult[0].museum_id;

        // 2. 更新文物浏览量
        const updateViewsSql = 'UPDATE cultural_relic SET views_count = views_count + 1 WHERE relic_id = ?';
        await mysqlService.query(updateViewsSql, [id]);

        // 3. 记录用户浏览历史
        // const insertHistorySql = `
        //     INSERT INTO user_browsing_history (user_id, relic_id, museum_id, browse_time)
        //     VALUES (?, ?, ?, NOW())
        // `;
        // await mysqlService.query(insertHistorySql, [user_id, id, museum_id]);

        // 4. 获取更新后的浏览量
        const getViewsSql = 'SELECT views_count FROM cultural_relic WHERE relic_id = ?';
        const results = await mysqlService.query(getViewsSql, [id]);

        res.json({ views_count: results[0].views_count });
    } catch (err) {
        console.error('更新浏览量失败:', err);
        res.status(500).json({ error: '数据库操作失败' });
    }
});

// 获取文物浏览量
router.get('/views/:id', async (req, res) => {
    const id = req.params.id;
    try {
        const sql = 'SELECT views_count FROM cultural_relic WHERE relic_id = ?';
        const results = await mysqlService.query(sql, [id]);
        if (results.length === 0) {
            return res.status(404).json({ error: '文物不存在' });
        }
        res.json({ views_count: results[0].views_count });
    } catch (err) {
        console.error('获取浏览量失败:', err);
        res.status(500).json({ error: '数据库查询失败' });
    }
});

// 上传图片
router.post('/upload_images', async (req, res) => {

    const userId = req.headers['user_id']; // 获取用户ID
    const commentId = req.headers['comment_id']; // 获取评论ID

    // console.log('请求参数:', req.params);
    console.log('请求头:');
    console.log('上传的文件:', req.file);

    // console.log(' (images):', req.files['image']);
    console.log(' (userId):', userId);
    console.log(' (commentId):', commentId);

    // if (!images || images.length === 0) {
    //     return res.status(400).json({ error: '没有上传图片' });
    // }

});

module.exports = router
