const express = require('express')
const antiqueRoutes = require('./routes/antique')
const museumRoutes = require('./routes/Museum')
const userRoutes = require('./routes/user')
const cors = require('cors')

const app = express()
const PORT = 3000

app.use(cors())
app.use(express.json())

// 挂载文物相关API
app.use('/api/antique', antiqueRoutes)
// 挂载博物馆相关API
app.use('/api/museum', museumRoutes)
// 挂载用户相关API
app.use('/api/user', userRoutes)

app.listen(PORT, () => {
    console.log(`✅ 后端服务已启动: http://localhost:${PORT}`)
})
