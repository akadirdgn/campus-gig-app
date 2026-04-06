# Zoom Server-to-Server OAuth Backend Architecture Guide

This guide outlines exactly how your backend (Python/Java/Node) should authenticate with Zoom securely without requiring user logins (Server-to-Server OAuth), and how to generate an instant meeting `join_url`.

## Prerequisites
1. Create a "Server-to-Server OAuth" app in the [Zoom App Marketplace](https://marketplace.zoom.us/).
2. Note your **Account ID**, **Client ID**, and **Client Secret**.
3. Add the Scope: `meeting:write` to allow creating meetings.

---

## The Flow

### 1. Get the Access Token
Your backend must securely request an `access_token` from Zoom using Basic Authentication.

**HTTP Request:**
```http
POST https://zoom.us/oauth/token?grant_type=account_credentials&account_id={YOUR_ACCOUNT_ID}
Authorization: Basic Base64Encode({CLIENT_ID}:{CLIENT_SECRET})
```

**Python (FastAPI/Flask) Example:**
```python
import os
import base64
import requests

def get_zoom_token():
    account_id = os.environ.get("ZOOM_ACCOUNT_ID")
    client_id = os.environ.get("ZOOM_CLIENT_ID")
    client_secret = os.environ.get("ZOOM_CLIENT_SECRET")
    
    # Create Basic Auth String
    auth_str = f"{client_id}:{client_secret}"
    b64_auth_str = base64.b64encode(auth_str.encode()).decode()
    
    headers = {"Authorization": f"Basic {b64_auth_str}"}
    data = {
        "grant_type": "account_credentials",
        "account_id": account_id
    }
    
    response = requests.post("https://zoom.us/oauth/token", headers=headers, data=data)
    if response.status_code == 200:
        return response.json().get("access_token")
    else:
        raise Exception("Failed to get Zoom token")
```

### 2. Create the Meeting
Once you have the `access_token`, use it to create an instant meeting on behalf of the `me` user (or a specific licensed user ID on your Zoom account).

**HTTP Request:**
```http
POST https://api.zoom.us/v2/users/me/meetings
Authorization: Bearer {ACCESS_TOKEN}
Content-Type: application/json
```

**Payload:**
```json
{
  "topic": "CampusApp Canlı Ders Odası",
  "type": 1, // 1 = Instant Meeting
  "settings": {
    "host_video": true,
    "participant_video": true,
    "waiting_room": false,
    "join_before_host": true
  }
}
```

**Python Implementation:**
```python
def create_zoom_meeting():
    token = get_zoom_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "topic": "CampusApp Canlı Ders Odası",
        "type": 1, 
        "settings": {
            "join_before_host": True,
            "waiting_room": False
        }
    }
    
    response = requests.post("https://api.zoom.us/v2/users/me/meetings", headers=headers, json=payload)
    if response.status_code == 201:
        meeting_data = response.json()
        return {
            "join_url": meeting_data.get("join_url"),
            "meeting_id": meeting_data.get("id"),
            "password": meeting_data.get("password")
        }
    else:
        raise Exception("Failed to create Zoom meeting")
```

## 3. Expose the API to Flutter
Create an endpoint `POST /api/zoom/create-meeting`. Ensure it verifies the user's Firebase Auth token first.
The Flutter code will call this endpoint, parse the `join_url`, and inject it into the `chat_rooms` message feed using `type: 'zoom_call'`.
