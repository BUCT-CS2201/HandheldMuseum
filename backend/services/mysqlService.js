const mysql = require('mysql2')
const config = require('../config/dbConfig')

const pool = mysql.createPool(config.mysql)

module.exports = {
    query: (sql, params) => {
        console.log('执行的 SQL 语句:', sql);
        console.log('参数:', params);
        return new Promise((resolve, reject) => {
            pool.query(sql, params, (err, results) => {
                if (err) {
                    console.error('数据库查询错误:', err);
                    return reject(err);
                }
                resolve(results);
            });
        });
    },

    // 用户登录
    async login(phoneNumber, password) {
        const sql = 'SELECT * FROM user WHERE phone_number = ? AND password = ? AND account_status = 1';
        const results = await this.query(sql, [phoneNumber, password]);
        return results[0];
    },

    // 用户注册
    async register(userData) {
        const { phone_number, password, id_number, name } = userData;
        const sql = `
            INSERT INTO user 
            (phone_number, password, id_number, name, account_status, comment_status, role_type) 
            VALUES (?, ?, ?, ?, 1, 1, 0)
        `;
        const result = await this.query(sql, [phone_number, password, id_number, name]);
        return result.insertId;
    },

    // 获取用户信息
    async getUserInfo(userId) {
        const sql = 'SELECT * FROM user WHERE user_id = ?';
        const results = await this.query(sql, [userId]);
        return results[0];
    },

    // 更新用户信息
    async updateUserInfo(userId, userData) {
        const allowedFields = ['gender', 'age', 'address', 'wechat', 'qq', 'description'];
        const updates = [];
        const values = [];

        for (const field of allowedFields) {
            if (userData[field] !== undefined) {
                updates.push(`${field} = ?`);
                values.push(userData[field]);
            }
        }

        if (updates.length === 0) {
            return null;
        }

        values.push(userId);
        const sql = `UPDATE user SET ${updates.join(', ')} WHERE user_id = ?`;
        const result = await this.query(sql, values);
        return result.affectedRows > 0;
    },

    // 检查手机号是否已存在
    async checkPhoneExists(phoneNumber) {
        const sql = 'SELECT COUNT(*) as count FROM user WHERE phone_number = ?';
        const results = await this.query(sql, [phoneNumber]);
        return results[0].count > 0;
    },

    // 检查身份证号是否已存在
    async checkIdNumberExists(idNumber) {
        const sql = 'SELECT COUNT(*) as count FROM user WHERE id_number = ?';
        const results = await this.query(sql, [idNumber]);
        return results[0].count > 0;
    }
};
