#!/bin/bash

echo "🧪 Testing Backend Integration After REDIRECT_URI Fix"
echo "=================================================="

echo ""
echo "📋 1. Health Check"
curl -s http://localhost:3001/health | jq .

echo ""
echo "📋 2. Environment Variables (Should show localhost:5173 redirect URI)"
curl -s http://localhost:3001/debug/env | jq .

echo ""
echo "📋 3. Test API Endpoint (Expected: Twitter API error with fake data)"
curl -s -X POST http://localhost:3001/api/twitter/exchange-and-connect \
  -H "Content-Type: application/json" \
  -d '{
    "authorizationCode": "fake_code_for_testing",
    "codeVerifier": "fake_verifier_for_testing",
    "walletAddress": "0x1234567890123456789012345678901234567890"
  }' | jq .

echo ""
echo "✅ Integration Test Complete!"
echo ""
echo "📝 Notes:"
echo "- Health check should return OK"
echo "- Redirect URI should be http://localhost:5173/auth/twitter/callback" 
echo "- API test should fail at Twitter step (expected with fake data)"
echo "- Real test will work when frontend sends real authorization code"
