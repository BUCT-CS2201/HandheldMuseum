const mysql = require('mysql2')
const config = require('../config/dbConfig')

const pool = mysql.createPool(config.mysql)

const mysqlService = {
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

    // 获取连接
    getConnection: () => {
        return new Promise((resolve, reject) => {
            pool.getConnection((err, connection) => {
                if (err) {
                    console.error('获取数据库连接失败:', err)
                    return reject(err)
                }
                resolve(connection)
            })
        })
    },

    // 事务相关方法
    beginTransaction: async () => {
        const connection = await mysqlService.getConnection()
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
    },

    // 用户相关方法
    userLogin: async (phone_number, password) => {
        const sql = 'SELECT * FROM user WHERE phone_number = ? AND password = ? AND account_status = 1'
        const results = await mysqlService.query(sql, [phone_number, password])
        return results[0] || null
    },

    checkPhoneExists: async (phone_number) => {
        const sql = 'SELECT COUNT(*) as count FROM user WHERE phone_number = ?'
        const results = await mysqlService.query(sql, [phone_number])
        return results[0].count > 0
    },

    userRegister: async (phone_number, password, name, id_number) => {
        const sql = 'INSERT INTO user (phone_number, password, name, id_number, account_status, comment_status, role_type) VALUES (?, ?, ?, ?, 1, 1, 0)'
        const results = await mysqlService.query(sql, [phone_number, password, name, id_number])
        return results
    },

    getUserInfo: async (userId) => {
        const sql = 'SELECT user_id, phone_number, name, description, gender, age, address, wechat, qq, account_status, comment_status, role_type, create_time, update_time FROM user WHERE user_id = ?'
        const results = await mysqlService.query(sql, [userId])
        return results[0] || null
    },

    updateUserInfo: async (userId, { name, phone_number, gender, age, description, address, wechat, qq }) => {
        const sql = 'UPDATE user SET name = ?, phone_number = ?, gender = ?, age = ?, description = ?, address = ?, wechat = ?, qq = ? WHERE user_id = ?'
        const result = await mysqlService.query(sql, [name, phone_number, gender, age, description, address, wechat, qq, userId])
        return result.affectedRows > 0
    }
}

module.exports = mysqlService