require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const app = express();

// 🔧 Environment Variables - Hardcoded for simplicity
const ENV_CONFIG = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: process.env.PORT || 3001,
  HTTPS_PORT: process.env.HTTPS_PORT || 3443,
  ENABLE_HTTPS: process.env.ENABLE_HTTPS === 'true' || process.env.NODE_ENV === 'development',
  
  // SSL Configuration
  SSL_KEY_PATH: process.env.SSL_KEY_PATH || './certs/localhost.key',
  SSL_CERT_PATH: process.env.SSL_CERT_PATH || './certs/localhost.crt',
  
  // Twitter OAuth Configuration
  TWITTER_CLIENT_ID: process.env.TWITTER_CLIENT_ID || 'T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ',
  TWITTER_CLIENT_SECRET: process.env.TWITTER_CLIENT_SECRET || '9R8RECRDHOuFpZCT_7U4FwrPYI4WjAGllHmJq52',
  TWITTER_REDIRECT_URI: process.env.TWITTER_REDIRECT_URI || 'https://localhost:5173/auth/twitter/callback',
  
  // FireStarter API Configuration
  FIRESTARTER_API_BASE_URL: process.env.FIRESTARTER_API_BASE_URL || 
    (process.env.NODE_ENV === 'development' ? 'http://localhost:3002/api/v1/trustcore' : 'https://api-firestarter.earnai.art/api/v1/trustcore'),
  
  // Additional Production URLs
  PRODUCTION_REDIRECT_URI: process.env.PRODUCTION_REDIRECT_URI || 'https://firestarter-evm-fe-five.vercel.app/auth/twitter/callback',
  FRONTEND_DOMAIN: process.env.FRONTEND_DOMAIN || 'https://firestarter-evm-fe-five.vercel.app',
  
  // API Configuration
  TWITTER_API_URL: process.env.TWITTER_API_URL || 'https://api.x.com/2/oauth2/token',
  
  // Server Configuration  
  CORS_ORIGINS: process.env.CORS_ORIGINS || '*',
  MAX_REQUEST_SIZE: process.env.MAX_REQUEST_SIZE || '10mb',
  REQUEST_TIMEOUT: process.env.REQUEST_TIMEOUT || 30000
};

console.log('🔧 Environment Configuration Loaded:', {
  NODE_ENV: ENV_CONFIG.NODE_ENV,
  PORT: ENV_CONFIG.PORT,
  HTTPS_PORT: ENV_CONFIG.HTTPS_PORT,
  ENABLE_HTTPS: ENV_CONFIG.ENABLE_HTTPS,
  SSL_CERT_EXISTS: fs.existsSync(ENV_CONFIG.SSL_CERT_PATH),
  TWITTER_CLIENT_ID: ENV_CONFIG.TWITTER_CLIENT_ID ? `${ENV_CONFIG.TWITTER_CLIENT_ID.substring(0, 10)}...` : 'Not set',
  TWITTER_REDIRECT_URI: ENV_CONFIG.TWITTER_REDIRECT_URI,
  FIRESTARTER_API_BASE_URL: ENV_CONFIG.FIRESTARTER_API_BASE_URL,
  PRODUCTION_REDIRECT_URI: ENV_CONFIG.PRODUCTION_REDIRECT_URI,
  FRONTEND_DOMAIN: ENV_CONFIG.FRONTEND_DOMAIN,
  timestamp: new Date().toISOString()
});

const PORT = ENV_CONFIG.PORT;

// Enable CORS for all origins (development mode)
const corsOrigins = ENV_CONFIG.CORS_ORIGINS === '*' ? '*' : ENV_CONFIG.CORS_ORIGINS.split(',');

app.use(cors({
  origin: corsOrigins,
  credentials: ENV_CONFIG.CORS_ORIGINS === '*' ? false : true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Origin'],
  optionsSuccessStatus: 200
}));

// Additional CORS middleware for error responses
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization, X-Requested-With');
  res.header('Access-Control-Allow-Credentials', 'true');
  next();
});

// Body parser middleware with size limits
app.use(express.json({ limit: ENV_CONFIG.MAX_REQUEST_SIZE }));
app.use(express.urlencoded({ extended: true, limit: ENV_CONFIG.MAX_REQUEST_SIZE }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Twitter OAuth Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Debug environment variables endpoint
app.get('/debug/env', (req, res) => {
  res.json({
    status: 'Environment Variables Check',
    NODE_ENV: ENV_CONFIG.NODE_ENV,
    PORT: ENV_CONFIG.PORT,
    TWITTER_CLIENT_ID: ENV_CONFIG.TWITTER_CLIENT_ID ? `Set (${ENV_CONFIG.TWITTER_CLIENT_ID.substring(0, 10)}...)` : 'Not set',
    TWITTER_CLIENT_SECRET: ENV_CONFIG.TWITTER_CLIENT_SECRET ? `Set (${ENV_CONFIG.TWITTER_CLIENT_SECRET.substring(0, 10)}...)` : 'Not set',
    TWITTER_REDIRECT_URI: ENV_CONFIG.TWITTER_REDIRECT_URI,
    PRODUCTION_REDIRECT_URI: ENV_CONFIG.PRODUCTION_REDIRECT_URI,
    FIRESTARTER_API_BASE_URL: ENV_CONFIG.FIRESTARTER_API_BASE_URL,
    FRONTEND_DOMAIN: ENV_CONFIG.FRONTEND_DOMAIN,
    TWITTER_API_URL: ENV_CONFIG.TWITTER_API_URL,
    CORS_ORIGINS: ENV_CONFIG.CORS_ORIGINS,
    MAX_REQUEST_SIZE: ENV_CONFIG.MAX_REQUEST_SIZE,
    REQUEST_TIMEOUT: ENV_CONFIG.REQUEST_TIMEOUT,
    server_time: new Date().toISOString(),
    uptime: process.uptime() + ' seconds'
  });
});

/**
 * Main API endpoint for frontend
 * Nhận authorizationCode, codeVerifier, walletAddress từ frontend
 * Đổi code lấy access token từ Twitter, sau đó gửi đến FireStarter API
 */
app.post('/api/twitter/exchange-and-connect', async (req, res) => {
    console.log('🚀 Nhận request từ frontend:', {
        body: {
            authorizationCode: req.body.authorizationCode ? req.body.authorizationCode.substring(0, 20) + '...' : 'Missing',
            codeVerifier: req.body.codeVerifier ? req.body.codeVerifier.substring(0, 20) + '...' : 'Missing',
            walletAddress: req.body.walletAddress || 'Missing',
            redirectUri: req.body.redirectUri || 'Missing'
        },
        timestamp: new Date().toISOString()
    });

    const { authorizationCode, codeVerifier, walletAddress, redirectUri } = req.body;

    // Validate required fields
    if (!authorizationCode || !codeVerifier || !walletAddress) {
        console.error('❌ Thiếu thông tin bắt buộc:', {
            authorizationCode: !!authorizationCode,
            codeVerifier: !!codeVerifier,
            walletAddress: !!walletAddress,
            redirectUri: !!redirectUri
        });
        return res.status(400).json({ 
            success: false,
            message: 'Thiếu thông tin bắt buộc: authorizationCode, codeVerifier, hoặc walletAddress'
        });
    }

    // Validate environment variables
    const twitterClientId = ENV_CONFIG.TWITTER_CLIENT_ID;
    const twitterClientSecret = ENV_CONFIG.TWITTER_CLIENT_SECRET;
    const twitterRedirectUri = ENV_CONFIG.TWITTER_REDIRECT_URI;
    const firestarterApiBaseUrl = ENV_CONFIG.FIRESTARTER_API_BASE_URL;

    if (!twitterClientId || !twitterClientSecret || !twitterRedirectUri || !firestarterApiBaseUrl) {
        console.error('❌ Thiếu biến môi trường:', {
            TWITTER_CLIENT_ID: !!twitterClientId,
            TWITTER_CLIENT_SECRET: !!twitterClientSecret,
            TWITTER_REDIRECT_URI: !!twitterRedirectUri,
            FIRESTARTER_API_BASE_URL: !!firestarterApiBaseUrl
        });
        return res.status(500).json({ 
            success: false,
            message: 'Lỗi cấu hình server: thiếu biến môi trường cần thiết'
        });
    }    try {
        // Step 1: Exchange authorization code for access token from Twitter
        console.log('📡 Bước 1: Đổi authorization code lấy access token từ Twitter...');
        
        // Sử dụng redirect URI từ frontend, fallback về env nếu không có
        const finalRedirectUri = redirectUri || twitterRedirectUri;
        console.log('🔍 Sử dụng redirect URI:', finalRedirectUri);
        
        const twitterTokenUrl = ENV_CONFIG.TWITTER_API_URL;
        const basicAuth = Buffer.from(`${twitterClientId}:${twitterClientSecret}`).toString('base64');
        
        const twitterTokenParams = new URLSearchParams();
        twitterTokenParams.append('grant_type', 'authorization_code');
        twitterTokenParams.append('code', authorizationCode);
        twitterTokenParams.append('redirect_uri', finalRedirectUri); // Sử dụng redirect URI từ frontend
        twitterTokenParams.append('client_id', twitterClientId);
        twitterTokenParams.append('code_verifier', codeVerifier);

        console.log('📤 Gửi request đến Twitter API:', {
            url: twitterTokenUrl,
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Basic ${basicAuth.substring(0, 20)}...`            },
            params: {
                grant_type: 'authorization_code',
                code: `${authorizationCode.substring(0, 20)}...`,
                redirect_uri: finalRedirectUri,
                client_id: twitterClientId,
                code_verifier: `${codeVerifier.substring(0, 20)}...`
            }
        });

        console.log('🔍 Chi tiết redirect_uri đang sử dụng:', finalRedirectUri);

        const twitterResponse = await axios.post(twitterTokenUrl, twitterTokenParams.toString(), {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Basic ${basicAuth}`
            },
            timeout: ENV_CONFIG.REQUEST_TIMEOUT
        });

        const twitterAccessToken = twitterResponse.data.access_token;
        if (!twitterAccessToken) {
            console.error('❌ Twitter không trả về access token:', twitterResponse.data);
            return res.status(500).json({ 
                success: false,
                message: 'Không lấy được access token từ Twitter'
            });
        }

        console.log('✅ Đã nhận access token từ Twitter:', `${twitterAccessToken.substring(0, 20)}...`);

        // Step 2: Send access token and wallet address to FireStarter API
        console.log('📡 Bước 2: Gửi access token và wallet address đến FireStarter API...');
        
        const firestarterConnectUrl = `${firestarterApiBaseUrl}/social/connect/twitter`;
        const firestarterPayload = {
            accessToken: twitterAccessToken,
            walletAddress: walletAddress
        };

        console.log('📤 Gửi request đến FireStarter API:', {
            url: firestarterConnectUrl,
            payload: {
                accessToken: `${twitterAccessToken.substring(0, 20)}...`,
                walletAddress: walletAddress
            }
        });

        const firestarterResponse = await axios.post(firestarterConnectUrl, firestarterPayload, {
            headers: {
                'Content-Type': 'application/json'
            },
            timeout: ENV_CONFIG.REQUEST_TIMEOUT
        });
        
        console.log('✅ Thành công từ FireStarter API:', firestarterResponse.data);
        
        // Return success response to frontend
        return res.status(200).json({
            success: true,
            message: 'Kết nối Twitter với FireStarter thành công!',
            data: firestarterResponse.data
        });

    } catch (error) {
        console.error('❌ Lỗi trong quá trình xử lý:', {
            message: error.message,
            response: error.response?.data,
            status: error.response?.status
        });

        // Determine which step failed for better error messaging
        if (error.config?.url?.includes('api.x.com')) {
            return res.status(error.response?.status || 500).json({ 
                success: false,
                message: 'Lỗi khi trao đổi token với Twitter',
                error: error.response?.data || error.message
            });
        } else if (error.config?.url?.includes(firestarterApiBaseUrl)) {
            return res.status(error.response?.status || 500).json({ 
                success: false,
                message: 'Lỗi khi kết nối với FireStarter API',
                error: error.response?.data || error.message
            });
        } else {
            return res.status(500).json({ 
                success: false,
                message: 'Lỗi server không xác định',
                error: error.message
            });
        }
    }
});

// Start server
// Start server
const startServer = () => {
  // HTTP Server
  const httpServer = http.createServer(app);
  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 HTTP Server running on http://0.0.0.0:${PORT}`);
  });

  // HTTPS Server (if enabled and certificates exist)
  if (ENV_CONFIG.ENABLE_HTTPS) {
    try {
      if (fs.existsSync(ENV_CONFIG.SSL_KEY_PATH) && fs.existsSync(ENV_CONFIG.SSL_CERT_PATH)) {
        const httpsOptions = {
          key: fs.readFileSync(ENV_CONFIG.SSL_KEY_PATH),
          cert: fs.readFileSync(ENV_CONFIG.SSL_CERT_PATH)
        };
        
        const httpsServer = https.createServer(httpsOptions, app);
        httpsServer.listen(ENV_CONFIG.HTTPS_PORT, '0.0.0.0', () => {
          console.log(`🔒 HTTPS Server running on https://0.0.0.0:${ENV_CONFIG.HTTPS_PORT}`);
          console.log(`🔒 Local HTTPS: https://localhost:${ENV_CONFIG.HTTPS_PORT}`);
        });
      } else {
        console.log(`⚠️  HTTPS certificates not found at:`);
        console.log(`   Key: ${ENV_CONFIG.SSL_KEY_PATH}`);
        console.log(`   Cert: ${ENV_CONFIG.SSL_CERT_PATH}`);
        console.log(`   Run: npm run create-cert to generate certificates`);
      }
    } catch (error) {
      console.error('❌ HTTPS setup failed:', error.message);
    }
  }

  console.log(`🌐 Environment: ${ENV_CONFIG.NODE_ENV}`);
  console.log(`🔧 CORS Origins: ${ENV_CONFIG.CORS_ORIGINS}`);
  console.log(`� Twitter Client ID: ${ENV_CONFIG.TWITTER_CLIENT_ID ? ENV_CONFIG.TWITTER_CLIENT_ID.substring(0, 10) + '...' : 'Not set'}`);
  console.log(`🔗 Twitter Redirect URI: ${ENV_CONFIG.TWITTER_REDIRECT_URI}`);
  console.log(`🔗 Production Redirect URI: ${ENV_CONFIG.PRODUCTION_REDIRECT_URI}`);
  console.log(`🔥 FireStarter API: ${ENV_CONFIG.FIRESTARTER_API_BASE_URL}`);
  console.log(`🌍 Frontend Domain: ${ENV_CONFIG.FRONTEND_DOMAIN}`);
  console.log('');
  console.log('📍 Available Endpoints:');
  console.log(`   GET  http://0.0.0.0:${PORT}/health - Health check`);
  console.log(`   GET  http://0.0.0.0:${PORT}/debug/env - Environment debug`);
  console.log(`   POST http://0.0.0.0:${PORT}/api/twitter/exchange-and-connect - Main API`);
  if (ENV_CONFIG.ENABLE_HTTPS && fs.existsSync(ENV_CONFIG.SSL_CERT_PATH)) {
    console.log(`   GET  https://localhost:${ENV_CONFIG.HTTPS_PORT}/health - HTTPS Health check`);
    console.log(`   POST https://localhost:${ENV_CONFIG.HTTPS_PORT}/api/twitter/exchange-and-connect - HTTPS Main API`);
  }
  console.log('');
  console.log(`📅 Server started at: ${new Date().toISOString()}`);
  console.log(`⚡ Process ID: ${process.pid}`);
  console.log(`💾 Memory usage: ${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB`);
};

startServer();
