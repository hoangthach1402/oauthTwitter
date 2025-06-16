require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

// Enable CORS for all origins (development mode)
app.use(cors({
  origin: true, // Cho phép tất cả origins
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

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
    TWITTER_CLIENT_ID: process.env.TWITTER_CLIENT_ID ? `Set (${process.env.TWITTER_CLIENT_ID.substring(0, 10)}...)` : 'Not set',
    TWITTER_CLIENT_SECRET: process.env.TWITTER_CLIENT_SECRET ? `Set (${process.env.TWITTER_CLIENT_SECRET.substring(0, 10)}...)` : 'Not set',
    TWITTER_REDIRECT_URI: process.env.TWITTER_REDIRECT_URI || 'Not set',
    FIRESTARTER_API_BASE_URL: process.env.FIRESTARTER_API_BASE_URL || 'Not set',
    PORT: process.env.PORT || '3001 (default)',
    timestamp: new Date().toISOString()
  });
});

/**
 * Main API endpoint for frontend
 * Nhận authorizationCode, codeVerifier, walletAddress từ frontend
 * Đổi code lấy access token từ Twitter, sau đó gửi đến FireStarter API
 */
app.post('/api/twitter/exchange-and-connect', async (req, res) => {
    console.log('🚀 Nhận request từ frontend:', {
        body: req.body,
        timestamp: new Date().toISOString()
    });

    const { authorizationCode, codeVerifier, walletAddress } = req.body;

    // Validate required fields
    if (!authorizationCode || !codeVerifier || !walletAddress) {
        console.error('❌ Thiếu thông tin bắt buộc:', {
            authorizationCode: !!authorizationCode,
            codeVerifier: !!codeVerifier,
            walletAddress: !!walletAddress
        });
        return res.status(400).json({ 
            success: false,
            message: 'Thiếu thông tin bắt buộc: authorizationCode, codeVerifier, hoặc walletAddress'
        });
    }

    // Validate environment variables
    const twitterClientId = process.env.TWITTER_CLIENT_ID;
    const twitterClientSecret = process.env.TWITTER_CLIENT_SECRET;
    const twitterRedirectUri = process.env.TWITTER_REDIRECT_URI;
    const firestarterApiBaseUrl = process.env.FIRESTARTER_API_BASE_URL;

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
    }

    try {
        // Step 1: Exchange authorization code for access token from Twitter
        console.log('📡 Bước 1: Đổi authorization code lấy access token từ Twitter...');
        
        const twitterTokenUrl = 'https://api.x.com/2/oauth2/token';
        const basicAuth = Buffer.from(`${twitterClientId}:${twitterClientSecret}`).toString('base64');
        
        const twitterTokenParams = new URLSearchParams();
        twitterTokenParams.append('grant_type', 'authorization_code');
        twitterTokenParams.append('code', authorizationCode);
        twitterTokenParams.append('redirect_uri', twitterRedirectUri);
        twitterTokenParams.append('client_id', twitterClientId);
        twitterTokenParams.append('code_verifier', codeVerifier);

        console.log('📤 Gửi request đến Twitter API:', {
            url: twitterTokenUrl,
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Basic ${basicAuth.substring(0, 20)}...`
            },
            body: 'grant_type=authorization_code&code=...&redirect_uri=...&client_id=...&code_verifier=...'
        });

        const twitterResponse = await axios.post(twitterTokenUrl, twitterTokenParams.toString(), {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Basic ${basicAuth}`
            }
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
            }
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
app.listen(PORT, () => {
    console.log(`🚀 Twitter OAuth Backend is running on http://localhost:${PORT}`);
    console.log(`🌐 CORS enabled for: ALL ORIGINS (development mode)`);
    console.log(`🔧 Health check: http://localhost:${PORT}/health`);
    console.log(`🛠️  Debug env vars: http://localhost:${PORT}/debug/env`);
    console.log(`📡 Main API endpoint: POST http://localhost:${PORT}/api/twitter/exchange-and-connect`);
    console.log(`📅 Started at: ${new Date().toISOString()}`);
});
