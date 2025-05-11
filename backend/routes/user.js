const express = require('express');
const router = express.Router();
const mysqlService = require('../services/mysqlService');

// 用户登录
router.post('/login', async (req, res) => {
    try {
        const { phone_number, password } = req.body;
        
        if (!phone_number || !password) {
            return res.status(400).json({
                code: 1,
                message: '手机号和密码不能为空'
            });
        }

        const result = await mysqlService.userLogin(phone_number, password);
        
        if (result) {
            res.json({
                code: 0,
                message: '登录成功',
                data: {
                    user_id: result.user_id
                }
            });
        } else {
            res.json({
                code: 1,
                message: '手机号或密码错误'
            });
        }
    } catch (error) {
        console.error('登录失败:', error);
        res.status(500).json({
            code: 1,
            message: '服务器错误'
        });
    }
});

// 用户注册
router.post('/register', async (req, res) => {
    try {
        const { phone_number, password, name } = req.body;
        
        if (!phone_number || !password || !name) {
            return res.status(400).json({
                code: 1,
                message: '请填写完整信息'
            });
        }

        // 检查手机号是否已存在
        const phoneExists = await mysqlService.checkPhoneExists(phone_number);
        if (phoneExists) {
            return res.json({
                code: 1,
                message: '该手机号已被注册'
            });
        }

        const result = await mysqlService.userRegister(phone_number, password, name);
        
        if (result) {
            res.json({
                code: 0,
                message: '注册成功',
                data: {
                    user_id: result.insertId
                }
            });
        } else {
            res.json({
                code: 1,
                message: '注册失败'
            });
        }
    } catch (error) {
        console.error('注册失败:', error);
        res.status(500).json({
            code: 1,
            message: '服务器错误'
        });
    }
});

// 获取用户信息
router.get('/info/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        
        if (!userId) {
            return res.status(400).json({
                code: 1,
                message: '用户ID不能为空'
            });
        }

        const userInfo = await mysqlService.getUserInfo(userId);
        
        if (userInfo) {
            res.json({
                code: 0,
                message: '获取成功',
                data: userInfo
            });
        } else {
            res.json({
                code: 1,
                message: '用户不存在'
            });
        }
    } catch (error) {
        console.error('获取用户信息失败:', error);
        res.status(500).json({
            code: 1,
            message: '服务器错误'
        });
    }
});

// 更新用户信息
router.put('/info/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const { name, phone_number, id_number, gender, age } = req.body;
        
        if (!userId) {
            return res.status(400).json({
                code: 1,
                message: '用户ID不能为空'
            });
        }

        const result = await mysqlService.updateUserInfo(userId, {
            name,
            phone_number,
            id_number,
            gender,
            age
        });
        
        if (result) {
            res.json({
                code: 0,
                message: '更新成功'
            });
        } else {
            res.json({
                code: 1,
                message: '更新失败'
            });
        }
    } catch (error) {
        console.error('更新用户信息失败:', error);
        res.status(500).json({
            code: 1,
            message: '服务器错误'
        });
    }
});

module.exports = router; 