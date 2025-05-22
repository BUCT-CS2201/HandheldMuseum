const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const mysqlService = require('../services/mysqlService');

function md5Encrypt(password) {
    return crypto.createHash('md5').update(password).digest('hex');
}

// 验证手机号格式
function validatePhoneNumber(phone) {
    const phoneRegex = /^1\d{10}$/;
    return phoneRegex.test(phone);
}

// 验证密码长度
function validatePasswordLength(password) {
    return password.length >= 6 && password.length <= 18;
}

// 验证身份证号格式
function validateIdNumber(idNumber) {
    const idNumberRegex = /^\d{18}$/;
    return idNumberRegex.test(idNumber);
}

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
        // 对密码进行 MD5 加密
        const encryptedPassword = md5Encrypt(password);
        const result = await mysqlService.userLogin(phone_number, encryptedPassword);

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
        console.log('收到注册请求:', req.body);
        const { phone_number, password, name } = req.body;
        
        if (!phone_number || !password || !name) {
            console.log('注册信息不完整:', { phone_number, name });
            return res.status(400).json({
                code: 1,
                message: '请填写完整信息'
            });
        }

        // 验证手机号格式
        if (!validatePhoneNumber(phone_number)) {
            console.log('手机号格式不正确:', phone_number);
            return res.json({
                code: 1,
                message: '请输入11位手机号码'
            });
        }

        // 验证密码长度
        if (!validatePasswordLength(password)) {
            console.log('密码长度不正确:', password.length);
            return res.json({
                code: 1,
                message: '密码长度应为6-18位'
            });
        }

        // 检查手机号是否已存在
        const phoneExists = await mysqlService.checkPhoneExists(phone_number);
        if (phoneExists) {
            console.log('手机号已存在:', phone_number);
            return res.json({
                code: 1,
                message: '该手机号已被注册'
            });
        }

        // 对密码进行 MD5 加密
        const encryptedPassword = md5Encrypt(password);
        console.log('准备注册用户:', { phone_number, name });
        const result = await mysqlService.userRegister(phone_number, encryptedPassword, name);
        
        if (result) {
            console.log('注册成功:', result);
            res.json({
                code: 0,
                message: '注册成功',
                data: {
                    user_id: result.insertId
                }
            });
        } else {
            console.log('注册失败: 数据库返回空结果');
            res.json({
                code: 1,
                message: '注册失败'
            });
        }
    } catch (error) {
        console.error('注册失败，详细错误:', error);
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
        const { name, phone_number, id_number, gender, age, description, address, wechat, qq } = req.body;
        
        if (!userId) {
            return res.status(400).json({
                code: 1,
                message: '用户ID不能为空'
            });
        }

        // 验证身份证号格式
        if (id_number && !validateIdNumber(id_number)) {
            return res.json({
                code: 1,
                message: '请输入18位身份证号码'
            });
        }

        const result = await mysqlService.updateUserInfo(userId, {
            name,
            phone_number,
            id_number,
            gender,
            age,
            description,
            address,
            wechat,
            qq
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