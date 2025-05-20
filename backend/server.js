const express = require('express')
const path = require('path'); // 添加这一行
const antiqueRoutes = require('./routes/antique')
const museumRoutes = require('./routes/Museum')
const dynamicRoutes = require('./routes/Dynamic')
const userRoutes = require('./routes/user')
const cors = require('cors')

const app = express()
const PORT = 3000

app.use(cors())
app.use(express.json())

// 关键配置：暴露 uploads 目录为静态资源
console.log('上传文件目录:', path.join(__dirname, 'comment_image')); // 添加这行
app.use('/comment_image', express.static(path.join(__dirname, 'comment_image')));
// 挂载文物相关API
app.use('/api/antique', antiqueRoutes)
app.use('/api/museum', museumRoutes)
app.use('/api/dynamic', dynamicRoutes)
app.use('/api/user',userRoutes)

app.listen(PORT, () => {
    console.log(`✅ 后端服务已启动: http://localhost:${PORT}`)
})