# Backend Twitter OAuth for FireStarter

Backend API để xử lý OAuth 2.0 Authorization Code Flow với PKCE cho Twitter (X) và kết nối với FireStarter API.

## 🚀 Tính năng

- ✅ OAuth 2.0 Authorization Code Flow với PKCE cho Twitter/X
- ✅ Đổi authorization code lấy access token từ Twitter
- ✅ Gửi access token + wallet address đến FireStarter API
- ✅ CORS được cấu hình cho frontend (localhost:5173)
- ✅ Error handling chi tiết và logging
- ✅ Response format chuẩn cho frontend

## 📋 Yêu cầu

- Node.js >= 16.x
- NPM/Yarn
- Twitter Developer Account với OAuth 2.0 app
- Biến môi trường được cấu hình đúng

## 🛠️ Cài đặt

1. **Clone và cài đặt dependencies:**
```bash
cd backendTwitter
npm install
```

2. **Cấu hình biến môi trường (.env):**
```env
TWITTER_CLIENT_ID=your_twitter_client_id
TWITTER_CLIENT_SECRET=your_twitter_client_secret
TWITTER_REDIRECT_URI=http://localhost:5173/auth/twitter/callback
FIRESTARTER_API_BASE_URL=https://api.firestarter.com/api/v1
PORT=3001
```

3. **Khởi động server:**
```bash
npm start
```

## 🌐 API Endpoints

### Main API Endpoint (cho Frontend)

**POST** `/api/twitter/exchange-and-connect`

Nhận authorization code từ frontend, đổi lấy access token từ Twitter, sau đó gửi đến FireStarter API.

**Request Body:**
```json
{
  "authorizationCode": "string", // Authorization code từ Twitter OAuth
  "codeVerifier": "string",      // Code verifier dùng trong PKCE
  "walletAddress": "string"      // Wallet address của user
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Kết nối Twitter với FireStarter thành công!",
  "data": {
    // Response từ FireStarter API
  }
}
```

**Response Error (400/500):**
```json
{
  "success": false,
  "message": "Mô tả lỗi",
  "error": "Chi tiết lỗi"
}
```

### Debug Endpoints

**GET** `/health` - Health check
**GET** `/debug/env` - Kiểm tra biến môi trường

## 🔧 Cách tích hợp với Frontend

Frontend cần thực hiện các bước sau:

1. **Tạo PKCE parameters:**
```javascript
// Tạo code_verifier và code_challenge
const codeVerifier = generateCodeVerifier();
const codeChallenge = await generateCodeChallenge(codeVerifier);
```

2. **Chuyển hướng user đến Twitter OAuth:**
```javascript
const authUrl = new URL('https://twitter.com/i/oauth2/authorize');
authUrl.searchParams.append('response_type', 'code');
authUrl.searchParams.append('client_id', 'YOUR_TWITTER_CLIENT_ID');
authUrl.searchParams.append('redirect_uri', 'YOUR_REDIRECT_URI');
authUrl.searchParams.append('scope', 'tweet.read users.read offline.access');
authUrl.searchParams.append('state', 'random_state_string');
authUrl.searchParams.append('code_challenge', codeChallenge);
authUrl.searchParams.append('code_challenge_method', 'S256');

window.location.href = authUrl.toString();
```

3. **Xử lý callback và gọi backend API:**
```javascript
// Sau khi user authorize, nhận được authorization code
const authorizationCode = urlParams.get('code');

// Gọi backend API
const response = await fetch('http://localhost:3001/api/twitter/exchange-and-connect', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    authorizationCode: authorizationCode,
    codeVerifier: codeVerifier, // Lưu từ bước 1
    walletAddress: userWalletAddress
  })
});

const result = await response.json();
if (result.success) {
  // Thành công
  console.log('Kết nối thành công:', result.data);
} else {
  // Lỗi
  console.error('Lỗi:', result.message);
}
```

## 🔒 Security

- ✅ PKCE (Proof Key for Code Exchange) để bảo mật OAuth flow
- ✅ State parameter để chống CSRF attacks
- ✅ CORS chỉ cho phép frontend domain được cấu hình
- ✅ Environment variables để bảo vệ credentials
- ✅ Input validation và error handling

## 📊 Logging

Backend log chi tiết cho debugging:
- ✅ Request/response từ frontend
- ✅ Giao tiếp với Twitter API
- ✅ Giao tiếp với FireStarter API
- ✅ Error tracking với stack trace

## 🐛 Troubleshooting

### Lỗi thường gặp:

1. **CORS Error**: Đảm bảo frontend chạy trên `localhost:5173`
2. **Twitter API Error**: Kiểm tra CLIENT_ID, CLIENT_SECRET, REDIRECT_URI
3. **FireStarter API Error**: Kiểm tra FIRESTARTER_API_BASE_URL và endpoint
4. **Missing Environment Variables**: Kiểm tra file .env

### Debug Commands:

```bash
# Kiểm tra health
curl http://localhost:3001/health

# Kiểm tra environment variables
curl http://localhost:3001/debug/env

# Test API endpoint
curl -X POST http://localhost:3001/api/twitter/exchange-and-connect \
  -H "Content-Type: application/json" \
  -d '{"authorizationCode":"test","codeVerifier":"test","walletAddress":"test"}'
```

## 📝 Notes

- Backend chỉ cung cấp API, không có UI
- Frontend chịu trách nhiệm xử lý toàn bộ OAuth flow UI/UX
- Server chạy trên port 3001 mặc định
- Logs được output ra console với emoji để dễ đọc

## 🔄 Flow Overview

```
Frontend → Twitter OAuth → Frontend (receives code) → Backend API → Twitter (exchange token) → FireStarter API → Backend → Frontend (success/error)
```

1. Frontend khởi tạo OAuth flow với Twitter
2. User authorize trên Twitter
3. Twitter redirect về frontend với authorization code
4. Frontend gọi backend API với code + codeVerifier + walletAddress
5. Backend đổi code lấy access token từ Twitter
6. Backend gửi access token + walletAddress đến FireStarter
7. Backend trả kết quả về frontend
# oauthTwitter
