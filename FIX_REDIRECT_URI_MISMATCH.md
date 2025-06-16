# 🚨 FIX: Twitter OAuth Redirect URI Mismatch

## ❌ Lỗi hiện tại:
```
error: 'invalid_request',
error_description: 'Value passed for the redirect uri did not match the uri of the authorization code.'
```

## 🔍 Root Cause:
**Redirect URI mismatch** - Frontend và Backend đang sử dụng khác nhau redirect_uri.

## ✅ Solution:

### 1. Kiểm tra Backend Redirect URI:
```bash
curl http://localhost:3001/debug/env
```
**Backend đang sử dụng:** `http://localhost:5173/auth/twitter/callback`

### 2. Frontend PHẢI sử dụng CHÍNH XÁC cùng redirect_uri:

Trong function `authenticateWithTwitter` hoặc nơi tạo Twitter authorization URL, đảm bảo:

```javascript
// ❌ SAI - Nếu frontend đang dùng:
const redirectUri = "http://localhost:3001/auth/twitter/callback"; // Backend URL

// ✅ ĐÚNG - Frontend phải dùng:
const redirectUri = "http://localhost:5173/auth/twitter/callback"; // Frontend URL
```

### 3. Cập nhật Frontend Code:

Trong file tạo Twitter OAuth URL (có thể là `authenticateWithTwitter`):

```javascript
const generateTwitterAuthUrl = (clientId, codeChallenge, state) => {
  const authUrl = new URL('https://twitter.com/i/oauth2/authorize');
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('client_id', clientId);
  
  // ✅ QUAN TRỌNG: Phải match với backend .env
  authUrl.searchParams.append('redirect_uri', 'http://localhost:5173/auth/twitter/callback');
  
  authUrl.searchParams.append('scope', 'tweet.read users.read offline.access');
  authUrl.searchParams.append('state', state);
  authUrl.searchParams.append('code_challenge', codeChallenge);
  authUrl.searchParams.append('code_challenge_method', 'S256');
  
  return authUrl.toString();
};
```

### 4. Kiểm tra Twitter Developer Console:

Trong Twitter Developer Console, Callback URLs phải có:
```
http://localhost:5173/auth/twitter/callback
```

### 5. Verify Fix:

Sau khi fix frontend, test lại:
```bash
# Authorization code sẽ được tạo với đúng redirect_uri
# Backend sẽ exchange thành công
```

## 🔄 OAuth Flow Đúng:

1. **Frontend tạo auth URL** với `redirect_uri=http://localhost:5173/auth/twitter/callback`
2. **Twitter tạo authorization code** gắn với redirect_uri này
3. **Twitter redirect về frontend** với authorization code
4. **Frontend gửi code tới backend**
5. **Backend exchange code** với CÙNG redirect_uri `http://localhost:5173/auth/twitter/callback`
6. **✅ Success!**

## 📝 Summary:

**Root cause:** Frontend đang tạo authorization code với redirect_uri khác với backend.

**Fix:** Đảm bảo frontend sử dụng `http://localhost:5173/auth/twitter/callback` khi tạo Twitter OAuth URL.

**Test:** Sau khi fix, authorization code sẽ exchange thành công.
