const mysql = require('mysql2')
const config = require('../config/dbConfig')

const pool = mysql.createPool(config.mysql)

module.exports = {
    // 获取普通查询连接
    query: (sql, params) => {
        console.log('执行的 SQL 语句:', sql)
        console.log('参数:', params)
        return new Promise((resolve, reject) => {
            pool.query(sql, params, (err, results) => {
                if (err) {
                    console.error('数据库查询错误:', err)
                    return reject(err)
                }
                resolve(results)
            })
        })
    },

    // 事务相关方法
    beginTransaction: async () => {
        const connection = await pool.getConnection()
        await connection.beginTransaction()
        return connection
    },

    commit: async (connection) => {
        try {
            await connection.commit()
        } finally {
            connection.release() // 无论成功与否都释放连接
        }
    },

    rollback: async (connection) => {
        try {
            await connection.rollback()
        } finally {
            connection.release() // 无论成功与否都释放连接
        }
    }
}