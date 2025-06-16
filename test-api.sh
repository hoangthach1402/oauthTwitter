#!/bin/bash

# Test script for Backend Twitter OAuth API
# Đảm bảo backend đang chạy trên http://localhost:3001

echo "🚀 Testing Backend Twitter OAuth API"
echo "===================================="

# Test 1: Health check
echo ""
echo "📋 Test 1: Health Check"
echo "GET /health"
curl -s -X GET http://localhost:3001/health | jq .
echo ""

# Test 2: Environment variables
echo "📋 Test 2: Environment Variables Check"
echo "GET /debug/env" 
curl -s -X GET http://localhost:3001/debug/env | jq .
echo ""

# Test 3: Main API endpoint (invalid data - expect error)
echo "📋 Test 3: Main API Endpoint (Invalid Data)"
echo "POST /api/twitter/exchange-and-connect"
curl -s -X POST http://localhost:3001/api/twitter/exchange-and-connect \
  -H "Content-Type: application/json" \
  -d '{"authorizationCode":"test","codeVerifier":"test","walletAddress":"test"}' | jq .
echo ""

# Test 4: Main API endpoint (missing fields - expect error)
echo "📋 Test 4: Main API Endpoint (Missing Fields)"
echo "POST /api/twitter/exchange-and-connect"
curl -s -X POST http://localhost:3001/api/twitter/exchange-and-connect \
  -H "Content-Type: application/json" \
  -d '{"authorizationCode":"test"}' | jq .
echo ""

echo "✅ All tests completed!"
echo ""
echo "📝 Notes:"
echo "- Test 3 và 4 sẽ trả về lỗi vì không có dữ liệu thật từ Twitter"
echo "- Để test thành công, cần authorization code thật từ Twitter OAuth flow"
echo "- Frontend sẽ cung cấp authorizationCode, codeVerifier, walletAddress thật"
