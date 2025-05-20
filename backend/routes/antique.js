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
router.post('/like/:id', async (req, res) => {
    console.log('收到点赞请求', req.params.id, req.body);
    const id = req.params.id;
    const { user_id } = req.body;

    try {
        // 先检查是否已经点赞
        console.log('[like]检查是否已点赞');
        const checkSql = 'SELECT COUNT(*) as count FROM relic_like WHERE relic_id = ? AND user_id = ?';
        const results = await mysqlService.query(checkSql, [id, user_id]);
        console.log('[like]检查是否已点赞完成');

        const hasLiked = results[0].count > 0;
        console.log('用户', user_id, hasLiked ? '已点赞' : '未点赞', '文物', id);

        if (hasLiked) {
            // 取消点赞
            console.log('[like]执行取消点赞操作');
            const deleteSql = 'DELETE FROM relic_like WHERE relic_id = ? AND user_id = ?';
            await mysqlService.query(deleteSql, [id, user_id]);
            console.log('[like]删除点赞记录完成');

            const updateSql = 'UPDATE cultural_relic SET likes_count = likes_count - 1 WHERE relic_id = ?';
            await mysqlService.query(updateSql, [id]);
            console.log('[like]更新文物点赞数 (-1) 完成');

            const getCountSql = 'SELECT likes_count as like_count FROM cultural_relic WHERE relic_id = ?';
            const countResults = await mysqlService.query(getCountSql, [id]);
            console.log('[like]获取最新点赞数完成');

            res.json({ like_count: countResults[0].like_count });
            console.log('[like]取消点赞响应发送');

        } else {
            // 添加点赞
            console.log('[like]执行添加点赞操作');
            const insertSql = 'INSERT INTO relic_like (relic_id, user_id) VALUES (?, ?)';
            await mysqlService.query(insertSql, [id, user_id]);
            console.log('[like]插入点赞记录完成');

            const updateSql = 'UPDATE cultural_relic SET likes_count = likes_count + 1 WHERE relic_id = ?';
            await mysqlService.query(updateSql, [id]);
            console.log('[like]更新文物点赞数 (+1) 完成');

            const getCountSql = 'SELECT likes_count as like_count FROM cultural_relic WHERE relic_id = ?';
            const countResults = await mysqlService.query(getCountSql, [id]);
            console.log('[like]获取最新点赞数完成');

            res.json({ like_count: countResults[0].like_count });
            console.log('[like]添加点赞响应发送');
        }

    } catch (err) {
        console.error('点赞操作失败:', err);
        res.status(500).json({ error: '服务器内部错误' });
        console.error('点赞操作失败响应发送');
    }
});

// 收藏接口
router.post('/favorite/:id', async (req, res) => {
    console.log('收到收藏请求', req.params.id, req.body);
    const id = req.params.id;
    const { user_id } = req.body;

    try {
        // 先检查是否已经点赞
        console.log('检查是否已收藏');
        const checkSql = 'SELECT COUNT(*) as count FROM user_favorite WHERE relic_id = ? AND user_id = ?';
        const results = await mysqlService.query(checkSql, [id, user_id]);
        console.log('检查是否已收藏完成');

        const hasFavorited = results[0].count > 0;
        console.log('用户', user_id, hasFavorited ? '已收藏' : '未收藏', '文物', id);

        if (hasFavorited) {
            // 取消点赞
            console.log('执行取消收藏操作');
            const deleteSql = 'DELETE FROM user_favorite WHERE relic_id = ? AND user_id = ?';
            await mysqlService.query(deleteSql, [id, user_id]);
            console.log('删除收藏记录完成');

            const getCountSql = 'SELECT COUNT(*) as favorite_count FROM user_favorite WHERE relic_id = ?';
            const countResults = await mysqlService.query(getCountSql, [id]);
            console.log('获取最新收藏数完成');

            res.json({ favorite_count: countResults[0].favorite_count });
            console.log('取消收藏响应发送');

        } else {
            // 添加点赞
            console.log('执行添加收藏操作');
            const insertSql = 'INSERT INTO user_favorite (user_id, relic_id, favorite_type) VALUES (?, ?, 1)';
            await mysqlService.query(insertSql, [user_id, id]);
            console.log('插入收藏记录完成');

            const getCountSql = 'SELECT COUNT(*) as favorite_count FROM user_favorite WHERE relic_id = ?';
            const countResults = await mysqlService.query(getCountSql, [id]);
            console.log('获取最新收藏数完成');

            res.json({ favorite_count: countResults[0].favorite_count });
            console.log('添加收藏响应发送');
        }

    } catch (err) {
        console.error('收藏操作失败:', err);
        res.status(500).json({ error: '服务器内部错误' });
        console.error('收藏操作失败响应发送');
    }
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
            u.name AS user_name,
            COALESCE(
              CONCAT(
                '[',
                GROUP_CONCAT(
                  JSON_OBJECT(
                    'image_id', img.image_id,
                    'suffix', img.image_suffix,
                    'status', img.status
                  )
                ),
                ']'
              ),
              '[]'
            ) as images
        FROM
            relic_comment rc
        JOIN
            user u ON rc.user_id = u.user_id
        LEFT JOIN
            user_image img ON rc.comment_id = img.comment_id
        WHERE
            rc.relic_id = ? AND rc.is_deleted = 0 AND rc.status = 1
        GROUP BY
            rc.comment_id
        ORDER BY
            rc.create_time DESC
    `;
    const start = Date.now(); // 记录开始时间，用于计算SQL执行耗时
    try {
        const results = await mysqlService.query(sql, [id]); // 执行SQL查询，获取评论数据
        const comments =  results.map(item => {
            let images = [] ;
            if( item.images && item.images !== '[]' ) {
                // 移除可能的空值
                const cleanJson = item.images.replace(/null,?/g, '').replace(/,\]/g, ']');
                try {
                    images = JSON.parse(cleanJson);
                    // 只保留状态为1的图片
                    images = images.filter(img => img && img.status === 1);
                    images = images.map(img => `${img.image_id}.${img.suffix}`);
                } catch (e) {
                    console.error('解析图片JSON失败:', item.comment_id);
                    images = []; // 如果解析失败，设置为空数组
                }
            }
            return {
                ...item,
                images: images
            }
        })
        console.log('SQL执行耗时:', Date.now() - start, 'ms'); // 打印SQL查询耗时
        console.log('评论接口返回结果:', comments); // 打印查询到的评论结果，便于调试
        res.json(comments); // 将评论数据以JSON格式返回给前端
    } catch (err) {
        console.error('查询评论失败:', err); // 打印错误信息
        res.status(500).json({ error: '数据库查询失败' }); // 返回500错误和错误信息给前端
    }
});

// 提交评论
router.post('/upload_comments/:id', async (req, res) => {
    const relicId = req.params.id;
    const { user_id, content, parent_id } = req.body;

    if (!user_id || user_id == 0) {
        return res.status(400).json({ error: '用户未登录或user_id无效' });
    }

    const sql = 'INSERT INTO relic_comment (relic_id, user_id, content, parent_id) VALUES (?, ?, ?, ?)';

    const results = await mysqlService.query(sql, [relicId, user_id, content, parent_id]);
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

// 获取文物详情（含多图和视频）
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

// 获取文物点赞状态
router.get('/status/:id', async (req, res) => {
    console.log('[status]收到 status 路由请求:', req.url, req.params, req.query);
    const relicId = req.params.id;
    const userId = Number(req.query.user_id);

    try {
        // 获取文物的点赞数
        const likeCountSql = 'SELECT likes_count FROM cultural_relic WHERE relic_id = ?';
        const likeCountResult = await mysqlService.query(likeCountSql, [relicId]);

        if (!likeCountResult || likeCountResult.length === 0) {
            console.log('[status]未找到文物:', relicId);
            return res.status(404).json({ error: '文物不存在' });
        }

        // 获取用户是否点赞
        const isLikedSql = 'SELECT COUNT(*) as count FROM relic_like WHERE relic_id = ? AND user_id = ?';
        const isLikedResult = await mysqlService.query(isLikedSql, [relicId, userId]);

        const response = {
            like_count: likeCountResult[0].likes_count,
            is_liked: isLikedResult[0].count > 0
        };

        console.log('[status]返回状态:', response);
        res.json(response);
    } catch (err) {
        console.error('[status]查询状态失败:', err);
        res.status(500).json({ error: '数据库查询失败' });
    }
});

// 获取文物收藏状态
router.get('/fstatus/:id', async (req, res) => {
    console.log('收到 status 路由请求:', req.url, req.params, req.query);
    const relicId = req.params.id;
    const userId = Number(req.query.user_id);
    try {
        // 获取文物的收藏数
        const favoriteCountSql = 'SELECT COUNT(*) as favorite_count FROM user_favorite WHERE relic_id = ?';
        const favoriteCountResult = await mysqlService.query(favoriteCountSql, [relicId]);

        if (!favoriteCountResult || favoriteCountResult.length === 0) {
            console.log('未找到文物:', relicId);
            return res.status(404).json({ error: '文物不存在' });
        }
        // 获取用户是否点赞
        const isFavoritedSql = 'SELECT COUNT(*) as count FROM user_favorite WHERE relic_id = ? AND user_id = ?';
        const isFavoritedResult = await mysqlService.query(isFavoritedSql, [relicId, userId]);
        const response = {
            favorite_count: favoriteCountResult[0].favorite_count,
            is_favorited: isFavoritedResult[0].count > 0
        };
        console.log('返回状态:', response);
        res.json(response);
    } catch (err) {
        console.error('查询状态失败:', err);
        res.status(500).json({ error: '数据库查询失败' });
    }
});

// 更新文物浏览量
router.post('/views/:id', async (req, res) => {
    const id = req.params.id;
    const { user_id } = req.body;

    try {
        // 1. 获取文物的 museum_id
        const getMuseumSql = 'SELECT museum_id FROM cultural_relic WHERE relic_id = ?';
        const museumResult = await mysqlService.query(getMuseumSql, [id]);
        if (museumResult.length === 0) {
            return res.status(404).json({ error: '文物不存在' });
        }
        const museum_id = museumResult[0].museum_id;

        // 2. 更新文物浏览量
        const updateViewsSql = 'UPDATE cultural_relic SET views_count = views_count + 1 WHERE relic_id = ?';
        await mysqlService.query(updateViewsSql, [id]);

        // 3. 记录用户浏览历史
        const insertHistorySql = `
            INSERT INTO user_browsing_history (user_id, relic_id, museum_id, browse_time)
            VALUES (?, ?, ?, NOW())
        `;
        await mysqlService.query(insertHistorySql, [user_id, id, museum_id]);

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

// 获取用户浏览历史
router.get('/history/:user_id', async (req, res) => {
    const user_id = req.params.user_id;
    try {
        const sql = `
            SELECT b.relic_id, c.name, i.img_url, b.browse_time
            FROM user_browsing_history b
            JOIN cultural_relic c ON c.relic_id = b.relic_id
            JOIN relic_image i ON c.relic_id = i.relic_id
            WHERE b.user_id = ?
            ORDER BY b.browse_time DESC
        `;
        const results = await mysqlService.query(sql, [user_id]);

        if (results.length === 0) {
            return res.status(200).json([]); // 返回空数组更合理
        }

        // 格式化结果数组
        const formatted = results.map(row => ({
            id: row.relic_id,
            name: row.name,
            imageUrl: row.img_url,
            browseTime: row.browse_time
        }));

        res.json(formatted); // 返回数组
    } catch (err) {
        console.error('获取浏览历史失败:', err);
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
