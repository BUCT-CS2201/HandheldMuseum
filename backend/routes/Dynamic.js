const express = require('express')
const router = express.Router()
const mysqlService = require('../services/mysqlService')
const multer = require('multer')
const path = require('path')
const fs = require('fs')

// 确保上传目录存在
const uploadDir = path.join(__dirname, '../uploads')
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true })
}

// 配置multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir)
  },
  filename: (req, file, cb) => {
    // 生成文件名：时间戳 + 随机数 + 原始扩展名
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9)
    cb(null, uniqueSuffix + path.extname(file.originalname))
  }
})

const upload = multer({
  storage: storage,
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true)
    } else {
      cb(new Error('只允许上传图片文件！'), false)
    }
  },
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  }
})


// 发布动态
router.post('/publish', async (req, res) => {
  const { user_id, content, image_ids } = req.body

  if (!user_id) {
    return res.status(400).json({ error: '缺少用户ID' })
  }
  if (!content && (!image_ids || image_ids.length === 0)) {
    return res.status(400).json({ error: '内容或图片至少需要一项' })
  }

  try {
    // 1. 创建评论记录
    const commentSql = `
      INSERT INTO relic_comment
      (relic_id, user_id, content, parent_id, status, like_count, reply_count)
      VALUES (0, ?, ?, NULL, 0, 0, 0)
    `
    const commentResult = await mysqlService.query(commentSql, [user_id, content])
    const commentId = commentResult.insertId

    // 2. 关联图片与评论
    if (image_ids && image_ids.length > 0) {
      const updateImageSql = `
        UPDATE user_image
        SET comment_id = ?
        WHERE image_id IN (?)
      `
      await mysqlService.query(updateImageSql, [commentId, image_ids])
    }

    res.json({
      comment_id: commentId,
      message: '动态发布成功，等待审核'
    })
  } catch (err) {
    console.error('动态发布失败:', err)
    res.status(500).json({ error: '动态发布失败' })
  }
})

// 获取动态列表
router.get('/list', async (req, res) => {
  try {
    console.log('开始获取动态列表')
    const sql = `
      SELECT
        c.comment_id as dynamic_id,
        c.content,
        c.create_time,
        c.status as comment_status,
        c.like_count,
        c.reply_count,
        u.name AS username,
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
      FROM relic_comment c
      LEFT JOIN user_image img ON c.comment_id = img.comment_id
      LEFT JOIN user u ON c.user_id = u.user_id
      WHERE c.relic_id = 0
      AND c.is_deleted = 0
      AND c.parent_id = 0
      GROUP BY c.comment_id
      ORDER BY c.create_time DESC
    `
    console.log('执行SQL查询:', sql)
    const results = await mysqlService.query(sql)
    console.log('查询结果:', results)

    // 处理图片状态
    const dynamics = results.map(item => {
      let images = [];
      try {
        if (item.images && item.images !== '[]') {
          // 移除可能的空值
          const cleanJson = item.images.replace(/null,?/g, '').replace(/,\]/g, ']');
          images = JSON.parse(cleanJson);
          // 只保留状态为1的图片
          images = images.filter(img => img && img.status === 1);
        }
      } catch (e) {
        console.error('解析图片JSON失败:', e);
      }
      return {
        ...item,
        images: images
      };
    });

    console.log('处理后的动态数据:', dynamics)
    res.json(dynamics)
  } catch (err) {
    console.error('获取动态失败:', err)
    res.status(500).json({ error: '获取动态失败' })
  }
})

// 获取图片
router.get('/image/:imageId', async (req, res) => {
  try {
    const { imageId } = req.params

    // 查询图片信息
    const sql = `
      SELECT image_id, image_suffix, status
      FROM user_image
      WHERE image_id = ?
    `
    const [image] = await mysqlService.query(sql, [imageId])

    if (!image) {
      return res.status(404).json({ error: '图片不存在' })
    }

    // 构建图片路径
    const imagePath = path.join(uploadDir, `${image.image_id}.${image.image_suffix}`)

    // 检查文件是否存在
    if (!fs.existsSync(imagePath)) {
      return res.status(404).json({ error: '图片文件不存在' })
    }

    // 根据状态返回不同的响应
    if (image.status === 0) {
      return res.json({
        status: 'pending',
        message: '图片审核中',
        imageUrl: '/api/static/pending.png' // 返回审核中的占位图
      })
    } else if (image.status === 2) {
      return res.json({
        status: 'rejected',
        message: '图片未通过审核',
        imageUrl: '/api/static/rejected.png' // 返回未通过审核的占位图
      })
    }

    // 图片已审核通过，返回文件
    res.sendFile(imagePath)
  } catch (err) {
    console.error('获取图片失败:', err)
    res.status(500).json({ error: '获取图片失败' })
  }
})

// 点赞/取消点赞接口
router.post('/like', async (req, res) => {
  console.log('收到点赞请求:', req.body);
  const { dynamic_id, action } = req.body;

  if (!dynamic_id || !action) {
    console.log('参数不完整:', { dynamic_id, action });
    return res.status(400).json({ error: '参数不完整' });
  }

  try {
    // 首先检查动态是否存在
    const checkSql = `
      SELECT comment_id, like_count
      FROM relic_comment
      WHERE comment_id = ? AND is_deleted = 0
    `;
    console.log('检查动态是否存在:', checkSql, [dynamic_id]);
    const [existingComment] = await mysqlService.query(checkSql, [dynamic_id]);

    if (!existingComment) {
      console.log('动态不存在:', dynamic_id);
      return res.status(404).json({ error: '动态不存在' });
    }

    // 根据action决定是增加还是减少点赞数
    const updateSql = `
      UPDATE relic_comment
      SET like_count = like_count ${action === 'like' ? '+ 1' : '- 1'}
      WHERE comment_id = ? AND is_deleted = 0
    `;
    console.log('执行SQL:', updateSql, [dynamic_id]);

    const updateResult = await mysqlService.query(updateSql, [dynamic_id]);
    console.log('更新结果:', updateResult);

    if (updateResult.affectedRows === 0) {
      console.log('更新失败，没有记录被修改');
      return res.status(500).json({ error: '点赞操作失败' });
    }

    // 获取更新后的点赞数
    const getCountSql = `
      SELECT like_count
      FROM relic_comment
      WHERE comment_id = ?
    `;
    console.log('执行SQL:', getCountSql, [dynamic_id]);
    const [result] = await mysqlService.query(getCountSql, [dynamic_id]);
    console.log('查询结果:', result);

    if (!result) {
      console.log('获取更新后的点赞数失败');
      return res.status(500).json({ error: '获取点赞数失败' });
    }

    res.json({
      newLikeCount: result.like_count,
      isLiked: action === 'like'
    });
  } catch (err) {
    console.error('点赞操作失败:', err);
    res.status(500).json({ error: '点赞操作失败' });
  }
});

// 图片上传接口
router.post('/upload/image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '请选择要上传的图片' })
    }

    const { user_id } = req.body
    if (!user_id) {
      return res.status(400).json({ error: '缺少用户ID' })
    }

    const suffix = path.extname(req.file.originalname).substring(1)

    // 插入图片记录
    const insertSql = `
      INSERT INTO user_image
      (user_id, image_suffix, status)
      VALUES (?, ?, 0)
    `
    const result = await mysqlService.query(insertSql, [user_id, suffix])

    // 重命名文件为 image_id.suffix
    const newFilename = `${result.insertId}.${suffix}`
    const newPath = path.join(uploadDir, newFilename)
    fs.renameSync(req.file.path, newPath)

    res.json({
      image_id: result.insertId,
      filename: newFilename,
      status: 0 // 初始状态为审核中
    })
  } catch (err) {
    console.error('图片上传失败:', err)
    res.status(500).json({ error: '图片上传失败' })
  }
})

// 获取评论列表
router.get('/comments/:dynamicId', async (req, res) => {
  try {
    const { dynamicId } = req.params;
    console.log('获取评论列表，动态ID:', dynamicId);
    
    // 修改SQL查询，获取所有相关评论
    const sql = `
      SELECT 
        c.comment_id,
        c.content,
        c.create_time,
        c.like_count,
        c.reply_count,
        c.parent_id,
        u.name AS username
      FROM relic_comment c
      LEFT JOIN user u ON c.user_id = u.user_id
      WHERE c.relic_id = 0 
      AND c.is_deleted = 0
      AND c.status = 1
      AND (c.parent_id = ? OR c.comment_id = ?)
      ORDER BY c.create_time ASC
    `;
    
    console.log('执行查询SQL:', sql, [dynamicId, dynamicId]);
    const comments = await mysqlService.query(sql, [dynamicId, dynamicId]);
    console.log('查询结果:', comments);
    
    // 处理评论层级关系
    const commentMap = new Map();
    const rootComments = [];

    // 首先将所有评论放入Map
    comments.forEach(comment => {
      commentMap.set(comment.comment_id, {
        ...comment,
        replies: []
      });
    });

    // 构建评论树
    comments.forEach(comment => {
      const commentWithReplies = commentMap.get(comment.comment_id);
      if (comment.parent_id === parseInt(dynamicId)) {
        // 这是对动态的评论
        rootComments.push(commentWithReplies);
      } else if (comment.parent_id) {
        // 这是对评论的回复
        const parentComment = commentMap.get(comment.parent_id);
        if (parentComment) {
          parentComment.replies.push(commentWithReplies);
        }
      }
    });
    
    res.json(rootComments);
  } catch (err) {
    console.error('获取评论失败，详细错误:', err);
    res.status(500).json({ 
      error: '获取评论失败',
      details: err.message || '未知错误'
    });
  }
});

// 发表评论
router.post('/comment', async (req, res) => {
  const { dynamic_id, user_id, content, parent_id } = req.body;

  console.log('收到评论请求:', { dynamic_id, user_id, content, parent_id });

  if (!dynamic_id || !user_id || !content) {
    console.log('参数不完整:', { dynamic_id, user_id, content });
    return res.status(400).json({ error: '参数不完整' });
  }

  try {
    // 检查动态是否存在
    const checkDynamicSql = `
      SELECT comment_id 
      FROM relic_comment 
      WHERE comment_id = ? AND relic_id = 0 AND is_deleted = 0
    `;
    const [dynamic] = await mysqlService.query(checkDynamicSql, [dynamic_id]);
    
    if (!dynamic) {
      console.log('动态不存在:', dynamic_id);
      return res.status(404).json({ error: '动态不存在' });
    }

    // 如果是回复评论，检查父评论是否存在
    if (parent_id) {
      const checkParentSql = `
        SELECT comment_id 
        FROM relic_comment 
        WHERE comment_id = ? AND relic_id = 0 AND is_deleted = 0
      `;
      const [parent] = await mysqlService.query(checkParentSql, [parent_id]);
      
      if (!parent) {
        console.log('父评论不存在:', parent_id);
        return res.status(404).json({ error: '父评论不存在' });
      }
    }

    // 设置 parent_id
    let actualParentId = null;
    if (parent_id) {
      actualParentId = parent_id;
    } else {
      actualParentId = dynamic_id;
    }
    // 插入评论
    const insertSql = `
      INSERT INTO relic_comment
      (relic_id, user_id, content, parent_id, status, like_count, reply_count)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    const params = [0, user_id, content, actualParentId, 1, 0, 0];
    console.log('执行插入SQL:', insertSql, params);
    const result = await mysqlService.query(insertSql, params);
    console.log('插入结果:', result);

    // 更新父评论的回复数
    const updateSql = `
      UPDATE relic_comment
      SET reply_count = reply_count + 1
      WHERE comment_id = ? AND relic_id = 0
    `;
    console.log('执行更新SQL:', updateSql, [actualParentId]);
    await mysqlService.query(updateSql, [actualParentId]);

    res.json({
      comment_id: result.insertId,
      message: '评论发布成功'
    });
  } catch (err) {
    console.error('评论发布失败，详细错误:', err);
    res.status(500).json({ 
      error: '评论发布失败',
      details: err.message || '未知错误'
    });
  }
});

// 删除评论
router.delete('/comment/:commentId', async (req, res) => {
  const { commentId } = req.params;
  const { user_id } = req.body;

  if (!user_id) {
    return res.status(400).json({ error: '缺少用户ID' });
  }

  try {
    // 检查评论是否存在且属于该用户
    const checkSql = `
      SELECT comment_id, parent_id
      FROM relic_comment
      WHERE comment_id = ? AND user_id = ? AND is_deleted = 0
    `;
    const [comment] = await mysqlService.query(checkSql, [commentId, user_id]);

    if (!comment) {
      return res.status(404).json({ error: '评论不存在或无权限删除' });
    }

    // 软删除评论
    const deleteSql = `
      UPDATE relic_comment
      SET is_deleted = 1
      WHERE comment_id = ?
    `;
    await mysqlService.query(deleteSql, [commentId]);

    // 如果是回复评论，减少父评论的回复数
    if (comment.parent_id) {
      const updateSql = `
        UPDATE relic_comment
        SET reply_count = reply_count - 1
        WHERE comment_id = ?
      `;
      await mysqlService.query(updateSql, [comment.parent_id]);
    }

    res.json({ message: '评论删除成功' });
  } catch (err) {
    console.error('删除评论失败:', err);
    res.status(500).json({ error: '删除评论失败' });
  }
});

module.exports = router