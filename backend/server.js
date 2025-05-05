const express = require('express')
const antiqueRoutes = require('./routes/antique')
const cors = require('cors')

const app = express()
const PORT = 3000

app.use(cors())
app.use(express.json())

// 挂载文物相关API
app.use('/api/antique', antiqueRoutes)

app.listen(PORT, () => {
    console.log(`✅ 后端服务已启动: http://localhost:${PORT}`)
})
