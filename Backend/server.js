// server.js
// Translatar 后端API代理服务
//
// 功能说明：
// 这是一个轻量级的Node.js后端服务，核心职责是：
// 1. 作为iOS客户端和OpenAI API之间的安全代理
// 2. 保护API密钥不暴露在客户端代码中
// 3. 为客户端生成临时的WebSocket连接凭证
// 4. 记录使用量（为后续计费做准备）
//
// 部署方式：
// 可部署到 Vercel、Railway、Render 等免费/低成本平台
// 也可以部署到 AWS Lambda + API Gateway

const express = require('express');
const cors = require('cors');
const { createServer } = require('http');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// 中间件配置
// ============================================

// 启用CORS（跨域资源共享）
app.use(cors());
// 解析JSON请求体
app.use(express.json());
// 请求日志
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// ============================================
// 环境变量配置
// ============================================

// OpenAI API密钥 - 必须通过环境变量配置，绝不硬编码
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
    console.error('错误：未设置 OPENAI_API_KEY 环境变量');
    console.error('请设置环境变量后重新启动：');
    console.error('  export OPENAI_API_KEY="your-api-key-here"');
    process.exit(1);
}

// ============================================
// API路由
// ============================================

/**
 * 健康检查接口
 * 用于监控服务是否正常运行
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'Translatar API Proxy',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

/**
 * 获取临时API会话凭证
 * 
 * iOS客户端调用此接口获取一个临时的、有时效的会话令牌，
 * 然后使用该令牌直接连接OpenAI的WebSocket服务。
 * 这样API密钥始终保存在服务器端，不会泄露到客户端。
 * 
 * POST /api/session
 * 请求体：{ "model": "gpt-4o-realtime-preview" }
 * 响应：{ "client_secret": { "value": "临时令牌" } }
 */
app.post('/api/session', async (req, res) => {
    try {
        const model = req.body.model || 'gpt-4o-realtime-preview';
        const voice = req.body.voice || 'shimmer';
        
        console.log(`[Session] 正在为模型 ${model} 创建临时会话...`);
        
        // 调用OpenAI的会话创建API
        const response = await fetch('https://api.openai.com/v1/realtime/sessions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: model,
                voice: voice,
            }),
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[Session] OpenAI API错误: ${response.status} - ${errorText}`);
            return res.status(response.status).json({
                error: '创建会话失败',
                details: errorText
            });
        }
        
        const sessionData = await response.json();
        
        console.log(`[Session] 临时会话创建成功`);
        
        // 返回临时凭证给客户端
        res.json(sessionData);
        
    } catch (error) {
        console.error(`[Session] 服务器错误: ${error.message}`);
        res.status(500).json({
            error: '服务器内部错误',
            message: error.message
        });
    }
});

/**
 * 直接代理模式（备选方案）
 * 如果OpenAI不支持临时会话令牌，可以使用此接口
 * 客户端通过此服务器中继WebSocket消息
 * 
 * POST /api/translate
 * 请求体：包含要转发给OpenAI的消息
 */
app.post('/api/translate', async (req, res) => {
    try {
        const { messages, config } = req.body;
        
        if (!messages || !config) {
            return res.status(400).json({
                error: '缺少必要参数：messages 和 config'
            });
        }
        
        console.log(`[Translate] 翻译请求: ${config.sourceLanguage} -> ${config.targetLanguage}`);
        
        // 使用OpenAI Chat API作为备选翻译方案
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: 'gpt-4o-mini',
                messages: [
                    {
                        role: 'system',
                        content: `You are a professional translator. Translate the following text from ${config.sourceLanguage} to ${config.targetLanguage}. Only output the translation, nothing else.`
                    },
                    ...messages
                ],
                temperature: 0.3,
            }),
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            return res.status(response.status).json({
                error: '翻译请求失败',
                details: errorText
            });
        }
        
        const data = await response.json();
        res.json(data);
        
    } catch (error) {
        console.error(`[Translate] 错误: ${error.message}`);
        res.status(500).json({
            error: '翻译服务错误',
            message: error.message
        });
    }
});

/**
 * 获取支持的语言列表
 * GET /api/languages
 */
app.get('/api/languages', (req, res) => {
    res.json({
        languages: [
            { code: 'en', name: 'English', chineseName: '英语', flag: '🇺🇸' },
            { code: 'zh', name: '中文', chineseName: '中文', flag: '🇨🇳' },
            { code: 'ja', name: '日本語', chineseName: '日语', flag: '🇯🇵' },
            { code: 'ko', name: '한국어', chineseName: '韩语', flag: '🇰🇷' },
            { code: 'es', name: 'Español', chineseName: '西班牙语', flag: '🇪🇸' },
            { code: 'fr', name: 'Français', chineseName: '法语', flag: '🇫🇷' },
            { code: 'de', name: 'Deutsch', chineseName: '德语', flag: '🇩🇪' },
            { code: 'it', name: 'Italiano', chineseName: '意大利语', flag: '🇮🇹' },
            { code: 'pt', name: 'Português', chineseName: '葡萄牙语', flag: '🇧🇷' },
            { code: 'ru', name: 'Русский', chineseName: '俄语', flag: '🇷🇺' },
        ]
    });
});

// ============================================
// 启动服务器
// ============================================

const server = createServer(app);

server.listen(PORT, () => {
    console.log('');
    console.log('========================================');
    console.log('  Translatar API代理服务已启动');
    console.log(`  地址: http://localhost:${PORT}`);
    console.log(`  健康检查: http://localhost:${PORT}/health`);
    console.log('========================================');
    console.log('');
});

// 优雅关闭
process.on('SIGTERM', () => {
    console.log('收到SIGTERM信号，正在关闭服务...');
    server.close(() => {
        console.log('服务已关闭');
        process.exit(0);
    });
});
