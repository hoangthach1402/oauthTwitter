# 🔗 Frontend Integration Guide

## ✅ Backend Status

- ✅ Backend đang chạy trên: http://localhost:3001
- ✅ CORS enabled cho frontend: http://localhost:5173
- ✅ TWITTER_REDIRECT_URI đã được sửa: `http://localhost:5173/auth/twitter/callback`
- ✅ Main API endpoint: `POST /api/twitter/exchange-and-connect`

## 🔧 Frontend Implementation

### 1. Cập nhật Verification.tsx

Thay thế phần `handleTwitterConnect` trong file `Verification.tsx`:

```typescript
const handleTwitterConnect = async () => {
  if (!address) {
    console.error('Please connect your wallet first');
    showVerificationFailureModal({
      provider: 'X/Twitter account',
      message: 'Please connect your wallet first.'
    });
    return;
  }
  
  setIsBusy(prev => ({ ...prev, twitter: true }));

  try {
    const clientId = import.meta.env.VITE_TWITTER_CLIENT_ID;
    if (!clientId) {
      throw new Error("Twitter client ID is not configured");
    }

    console.log("🐦 Starting Twitter OAuth flow...");

    // 1. Nhận authorization code từ Twitter thông qua popup
    const { code: authorizationCode, state: returnedState } = await authenticateWithTwitter(clientId);
    
    // 2. Xác thực state để ngăn CSRF
    const originalState = localStorage.getItem("twitter_oauth_state");
    const codeVerifier = localStorage.getItem("twitter_code_verifier");
    
    if (returnedState !== originalState) {
      throw new Error("Invalid state parameter. Possible CSRF attack.");
    }
    
    if (!codeVerifier) {
      throw new Error("Code verifier not found in storage.");
    }
    
    console.log("✅ Frontend: Received auth code:", authorizationCode?.substring(0, 20) + "...");
    console.log("✅ Frontend: Code verifier:", codeVerifier?.substring(0, 20) + "...");
    console.log("✅ Frontend: Wallet address:", address);
    
    // 3. Gửi authorization code, code verifier và wallet address đến backend
    const backendUrl = "http://localhost:3001/api/twitter/exchange-and-connect";
    
    console.log("📡 Frontend: Calling backend API...");
    
    const backendResponse = await fetch(backendUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        authorizationCode,
        codeVerifier,
        walletAddress: address
      })
    });
    
    const responseData = await backendResponse.json();
    
    // 4. Xử lý phản hồi từ backend
    if (!backendResponse.ok) {
      console.error("❌ Frontend: Backend error:", responseData);
      throw new Error(responseData.message || "Error connecting Twitter account");
    }
    
    console.log("✅ Frontend: Backend success response:", responseData);
    
    // 5. Hiển thị thông báo thành công và refresh trạng thái
    showVerificationSuccessModal();
    await refreshLinkedAccounts();
    
  } catch (error: any) {
    console.error("❌ Frontend: Error in Twitter connect:", error);
    showVerificationFailureModal({
      provider: 'X/Twitter account',
      message: `Connection failed: ${error.message || "Unknown error occurred."}`
    });
  } finally {
    setIsBusy(prev => ({ ...prev, twitter: false }));
    // Clean up localStorage
    localStorage.removeItem("twitter_code_verifier");
    localStorage.removeItem("twitter_oauth_state");
  }
};
```

### 2. Environment Variables Frontend

Đảm bảo file `.env` frontend có:

```env
VITE_TWITTER_CLIENT_ID=T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ
```

### 3. Twitter Developer Console

Đảm bảo trong Twitter Developer Console, Callback URL được set là:
```
http://localhost:5173/auth/twitter/callback
```

## 🔄 OAuth Flow Hoàn Chỉnh

### Frontend → Backend Flow:

1. **Frontend**: User click "Connect Twitter"
2. **Frontend**: Generate PKCE parameters (code_verifier, code_challenge)
3. **Frontend**: Redirect user đến Twitter OAuth với callback URL: `http://localhost:5173/auth/twitter/callback`
4. **Twitter**: User authorize
5. **Twitter**: Redirect về frontend với authorization code
6. **Frontend**: Extract authorization code từ URL params
7. **Frontend**: Call backend API:
   ```javascript
   POST http://localhost:3001/api/twitter/exchange-and-connect
   {
     "authorizationCode": "...",
     "codeVerifier": "...", 
     "walletAddress": "..."
   }
   ```
8. **Backend**: Exchange code for access token từ Twitter
9. **Backend**: Call FireStarter API với access token + wallet address
10. **Backend**: Return response về frontend
11. **Frontend**: Show success/error message

## 🐛 Testing

### Test Backend API trực tiếp:

```bash
# Test với dữ liệu giả (sẽ fail ở Twitter API - expected)
curl -X POST http://localhost:3001/api/twitter/exchange-and-connect \
  -H "Content-Type: application/json" \
  -d '{
    "authorizationCode": "fake_code",
    "codeVerifier": "fake_verifier", 
    "walletAddress": "0x1234567890123456789012345678901234567890"
  }'
```

Expected response (error vì fake data):
```json
{
  "success": false,
  "message": "Lỗi khi trao đổi token với Twitter",
  "error": "..."
}
```

### Test với dữ liệu thật:

Chỉ có thể test sau khi frontend implement đầy đủ OAuth flow và có authorization code thật từ Twitter.

## 📝 Notes

- ✅ Backend sẵn sàng nhận requests từ frontend
- ✅ CORS đã được cấu hình cho localhost:5173
- ✅ Redirect URI đã được sửa về frontend
- ✅ API endpoint trả structured response (success/error)
- ✅ Logging chi tiết cho debugging

## 🚀 Ready to Go!

Backend đã hoàn toàn sẵn sàng. Frontend chỉ cần implement code trên và OAuth flow sẽ hoạt động end-to-end!
