// mock-firestarter-api.js - Mock FireStarter API for testing

const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 3002;

// Enable CORS
app.use(cors());
app.use(express.json());

// Mock social connect endpoint
app.post('/api/v1/trustcore/social/connect/twitter', (req, res) => {
    console.log('🔥 Mock FireStarter API - Received request:', {
        body: req.body,
        headers: req.headers,
        timestamp: new Date().toISOString()
    });

    const { accessToken, walletAddress } = req.body;

    // Validate request
    if (!accessToken || !walletAddress) {
        return res.status(400).json({
            success: false,
            message: 'Missing required fields: accessToken or walletAddress'
        });
    }

    // Simulate processing delay
    setTimeout(() => {
        // Mock successful response
        res.json({
            success: true,
            message: 'Account connected successfully',
            data: {
                twitterHandle: 'mock_user_' + Math.random().toString(36).substr(2, 5),
                walletAddress: walletAddress,
                connectedAt: new Date().toISOString(),
                apiVersion: 'mock-v1.0.0'
            }
        });
    }, 1000); // 1 second delay to simulate real API
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        service: 'Mock FireStarter API',
        timestamp: new Date().toISOString()
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🔥 Mock FireStarter API running on http://localhost:${PORT}`);
    console.log(`📡 Twitter connect endpoint: http://localhost:${PORT}/api/v1/trustcore/social/connect/twitter`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
});
