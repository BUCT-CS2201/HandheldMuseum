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
    }
};
