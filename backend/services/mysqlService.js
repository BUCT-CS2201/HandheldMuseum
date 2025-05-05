const mysql = require('mysql2')
const config = require('../config/dbConfig')

const pool = mysql.createPool(config.mysql)

module.exports = {
    query: (sql, params) => {
        return new Promise((resolve, reject) => {
            pool.query(sql, params, (err, results) => {
                if (err) return reject(err)
                resolve(results)
            })
        })
    }
}
