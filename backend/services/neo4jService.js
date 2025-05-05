const neo4j = require('neo4j-driver')
const config = require('../config/dbConfig')

const driver = neo4j.driver(
    config.neo4j.uri,
    neo4j.auth.basic(config.neo4j.user, config.neo4j.password)
)

module.exports = {
    runQuery: async (cypher, params = {}) => {
        const session = driver.session()
        try {
            const result = await session.run(cypher, params)
            return result.records
        } finally {
            await session.close()
        }
    }
}
