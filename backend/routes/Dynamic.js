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

// 发布动态
router.post('/publish', async (req, res) => {
  const { user_id, content, image_ids } = req.body

  if (!user_id) {
    return res.status(400).json({ error: '缺少用户ID' })
  }
  if (!content && (!image_ids || image_ids.length === 0)) {
    return res.status(400).json({ error: '内容或图片至少需要一项' })
  }

  let connection // 用于保存数据库连接
  try {
    // 1. 开启事务
    connection = await mysqlService.beginTransaction()

    // 2. 创建评论记录
    const commentSql = `
      INSERT INTO relic_comment
      (relic_id, user_id, content, parent_id, status, like_count, reply_count)
      VALUES (0, ?, ?, NULL, 0, 0, 0)
    `
    const commentResult = await connection.query(commentSql, [user_id, content])
    const commentId = commentResult.insertId

    // 3. 关联图片与评论
    if (image_ids && image_ids.length > 0) {
      const updateImageSql = `
        UPDATE user_image
        SET comment_id = ?
        WHERE image_id IN (?)
      `
      await connection.query(updateImageSql, [commentId, image_ids])
    }

    // 4. 提交事务
    await mysqlService.commit(connection)

    res.json({
      comment_id: commentId,
      message: '动态发布成功，等待审核'
    })
  } catch (err) {
    // 5. 回滚事务
    if (connection) {
      await mysqlService.rollback(connection)
    }
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

module.exports = router