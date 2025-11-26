# Friend Management API Documentation

This document describes the REST API endpoints for friend management features in the Study P2P application.

## Base URL
All endpoints are prefixed with the base URL: `http://localhost:8080`

## Authentication
All endpoints require an `Authorization` header with a valid JWT token (implementation pending).
Currently using hardcoded `userId = 1` for testing.

---

## Friend Requests API

### 1. Send Friend Request (Add Friend)
**Endpoint:** `POST /api/friend-requests`

**Description:** Send a friend request to another user.

**Request Body:**
```json
{
  "toUserId": 2
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Friend request sent successfully",
  "requestId": 123
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input, already friends, request already exists, or blocked
- `404 Not Found`: User not found
- `500 Internal Server Error`: Database error

**Validations:**
- Cannot send request to yourself
- Cannot send request if already friends
- Cannot send request if one exists already
- Cannot send request if blocked by either party

---

### 2. Accept Friend Request
**Endpoint:** `POST /api/friend-requests/{requestId}/accept`

**Description:** Accept a pending friend request. Creates a friendship record.

**Path Parameters:**
- `requestId` (long): The ID of the friend request

**Success Response (200):**
```json
{
  "success": true,
  "message": "Friend request accepted successfully"
}
```

**Error Responses:**
- `403 Forbidden`: Not authorized to accept (must be the recipient)
- `404 Not Found`: Friend request not found
- `400 Bad Request`: Request is not pending
- `500 Internal Server Error`: Database error

**Side Effects:**
- Updates request status to `ACCEPTED`
- Creates a new friendship record with state `ACTIVE`

---

### 3. Reject Friend Request
**Endpoint:** `POST /api/friend-requests/{requestId}/reject`

**Description:** Reject a pending friend request.

**Path Parameters:**
- `requestId` (long): The ID of the friend request

**Success Response (200):**
```json
{
  "success": true,
  "message": "Friend request rejected successfully"
}
```

**Error Responses:**
- `403 Forbidden`: Not authorized to reject (must be the recipient)
- `404 Not Found`: Friend request not found
- `400 Bad Request`: Request is not pending
- `500 Internal Server Error`: Database error

**Side Effects:**
- Updates request status to `REJECTED`

---

### 4. Cancel Friend Request
**Endpoint:** `DELETE /api/friend-requests/{requestId}`

**Description:** Cancel a pending friend request that you sent.

**Path Parameters:**
- `requestId` (long): The ID of the friend request

**Success Response (200):**
```json
{
  "success": true,
  "message": "Friend request canceled successfully"
}
```

**Error Responses:**
- `403 Forbidden`: Not authorized to cancel (must be the sender)
- `404 Not Found`: Friend request not found
- `400 Bad Request`: Can only cancel pending requests
- `500 Internal Server Error`: Database error

**Side Effects:**
- Updates request status to `CANCELED`

---

### 5. List Received Friend Requests
**Endpoint:** `GET /api/friend-requests?status=PENDING&q=search&limit=50&offset=0`

**Description:** Get list of friend requests received by the current user.

**Query Parameters:**
- `status` (string, optional): Filter by status (PENDING, ACCEPTED, REJECTED, CANCELED). Default: PENDING
- `q` (string, optional): Search query for user name or email
- `limit` (int, optional): Results per page (max 100). Default: 50
- `offset` (int, optional): Pagination offset. Default: 0

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "fromUserId": 2,
      "fromUserName": "Alice",
      "status": "PENDING",
      "createdAt": "2024-11-24 10:30:00"
    }
  ],
  "total": 1
}
```

---

### 6. List Sent Friend Requests
**Endpoint:** `GET /api/friend-requests/sent?q=search&limit=50&offset=0`

**Description:** Get list of friend requests sent by the current user.

**Query Parameters:**
- `q` (string, optional): Search query for user name or email
- `limit` (int, optional): Results per page (max 100). Default: 50
- `offset` (int, optional): Pagination offset. Default: 0

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "fromUserId": 3,
      "fromUserName": "Bob",
      "status": "PENDING",
      "createdAt": "2024-11-24 10:30:00"
    }
  ],
  "total": 1
}
```

---

## Friends API

### 7. List Friends
**Endpoint:** `GET /api/friends?q=search&limit=50&offset=0`

**Description:** Get list of current user's friends.

**Query Parameters:**
- `q` (string, optional): Search query for user name or email
- `limit` (int, optional): Results per page (max 100). Default: 50
- `offset` (int, optional): Pagination offset. Default: 0

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 2,
      "email": "alice@example.com",
      "displayName": "Alice"
    }
  ],
  "total": 1
}
```

---

### 8. Get Friend Details
**Endpoint:** `GET /api/friends/{userId}`

**Description:** Get details of a specific friend.

**Path Parameters:**
- `userId` (long): The ID of the friend

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 2,
    "email": "alice@example.com",
    "displayName": "Alice"
  }
}
```

**Error Responses:**
- `404 Not Found`: Friend not found or not your friend
- `500 Internal Server Error`: Database error

---

### 9. Remove Friend
**Endpoint:** `DELETE /api/friends/{userId}`

**Description:** Remove a user from your friends list.

**⚠️ Important:** Frontend should display a confirmation dialog before calling this endpoint.

**Path Parameters:**
- `userId` (long): The ID of the friend to remove

**Success Response (200):**
```json
{
  "success": true,
  "message": "Friend removed successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Cannot remove yourself
- `404 Not Found`: Friendship not found
- `500 Internal Server Error`: Database error

**Side Effects:**
- Deletes the friendship record

---

## Blocked Users API

### 10. Block User
**Endpoint:** `POST /api/blocked-users`

**Description:** Block a user and remove any existing friendship or friend requests.

**⚠️ Important:** Frontend should display a confirmation dialog before calling this endpoint.

**Request Body:**
```json
{
  "blockedUserId": 2
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "User blocked successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Cannot block yourself or already blocked
- `404 Not Found`: User not found
- `500 Internal Server Error`: Database error

**Side Effects:**
- Creates a user_blocks record
- Deletes any existing friendship
- Deletes any pending friend requests

---

### 11. Unblock User
**Endpoint:** `DELETE /api/blocked-users/{userId}`

**Description:** Unblock a previously blocked user.

**Path Parameters:**
- `userId` (long): The ID of the user to unblock

**Success Response (200):**
```json
{
  "success": true,
  "message": "User unblocked successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid operation
- `404 Not Found`: Block not found
- `500 Internal Server Error`: Database error

**Side Effects:**
- Deletes the user_blocks record

---

### 12. List Blocked Users
**Endpoint:** `GET /api/blocked-users?q=search&limit=50&offset=0`

**Description:** Get list of users blocked by the current user.

**Query Parameters:**
- `q` (string, optional): Search query for user name or email
- `limit` (int, optional): Results per page (max 100). Default: 50
- `offset` (int, optional): Pagination offset. Default: 0

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 3,
      "email": "bob@example.com",
      "displayName": "Bob",
      "blockedAt": "2024-11-24 10:30:00"
    }
  ],
  "total": 1
}
```

---

### 13. List Users Blocking Me
**Endpoint:** `GET /api/blocked-users/blocking-me?q=search&limit=50&offset=0`

**Description:** Get list of users who have blocked the current user.

**Query Parameters:**
- `q` (string, optional): Search query for user name or email
- `limit` (int, optional): Results per page (max 100). Default: 50
- `offset` (int, optional): Pagination offset. Default: 0

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 4,
      "email": "charlie@example.com",
      "displayName": "Charlie",
      "blockedAt": "2024-11-24 10:30:00"
    }
  ],
  "total": 1
}
```

---

## Find Friends API

### 14. Search Users
**Endpoint:** `GET /api/find-friends?q=search&limit=50&offset=0`

**Description:** Search for users who are not your friends and not blocked.

**Query Parameters:**
- `q` (string, required): Search query (minimum 2 characters)
- `limit` (int, optional): Results per page (max 100). Default: 50
- `offset` (int, optional): Pagination offset. Default: 0

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "email": "david@example.com",
      "displayName": "David",
      "relationshipStatus": "NONE"
    }
  ],
  "total": 1
}
```

**Relationship Status Values:**
- `NONE`: No relationship
- `PENDING`: Friend request exists
- `BLOCKED`: User is blocked

**Error Responses:**
- `400 Bad Request`: Search query too short (< 2 characters)
- `500 Internal Server Error`: Database error

---

### 15. Get Online Users
**Endpoint:** `GET /api/find-friends/online?limit=20`

**Description:** Get list of recently active users who are not your friends.

**Query Parameters:**
- `limit` (int, optional): Results per page (max 100). Default: 20

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "email": "david@example.com",
      "displayName": "David"
    }
  ],
  "total": 1
}
```

---

## Database Schema

### friend_requests
```sql
CREATE TABLE friend_requests (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    from_user_id BIGINT NOT NULL,
    to_user_id BIGINT NOT NULL,
    status ENUM('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELED'),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (from_user_id) REFERENCES users(id),
    FOREIGN KEY (to_user_id) REFERENCES users(id),
    UNIQUE KEY (from_user_id, to_user_id)
);
```

### friendships
```sql
CREATE TABLE friendships (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id_a BIGINT NOT NULL,
    user_id_b BIGINT NOT NULL,
    state ENUM('ACTIVE', 'BLOCKED'),
    created_at TIMESTAMP,
    FOREIGN KEY (user_id_a) REFERENCES users(id),
    FOREIGN KEY (user_id_b) REFERENCES users(id),
    UNIQUE KEY (user_id_a, user_id_b)
);
```

### user_blocks
```sql
CREATE TABLE user_blocks (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    blocker_id BIGINT NOT NULL,
    blocked_id BIGINT NOT NULL,
    created_at TIMESTAMP,
    FOREIGN KEY (blocker_id) REFERENCES users(id),
    FOREIGN KEY (blocked_id) REFERENCES users(id),
    UNIQUE KEY (blocker_id, blocked_id)
);
```

---

## Frontend Integration Notes

### Confirmation Dialogs
The following actions should show confirmation dialogs in the frontend:

1. **Block User** (`POST /api/blocked-users`)
   - Message: "Are you sure you want to block this user? This will remove them from your friends list and delete any pending friend requests."
   
2. **Remove Friend** (`DELETE /api/friends/{userId}`)
   - Message: "Are you sure you want to remove this friend?"

3. **Unblock User** (`DELETE /api/blocked-users/{userId}`)
   - Message: "Are you sure you want to unblock this user?"

### Suggested User Flow

1. **Finding Friends:**
   - User searches via `/api/find-friends?q=alice`
   - Click "Add Friend" → `POST /api/friend-requests` with `toUserId`

2. **Managing Friend Requests:**
   - View received requests → `GET /api/friend-requests`
   - Accept → `POST /api/friend-requests/{requestId}/accept`
   - Reject → `POST /api/friend-requests/{requestId}/reject`
   - View sent requests → `GET /api/friend-requests/sent`
   - Cancel sent request → `DELETE /api/friend-requests/{requestId}`

3. **Managing Friends:**
   - View friends list → `GET /api/friends`
   - View friend details → `GET /api/friends/{userId}`
   - Remove friend (with confirmation) → `DELETE /api/friends/{userId}`
   - Block friend (with confirmation) → `POST /api/blocked-users`

4. **Managing Blocked Users:**
   - View blocked users → `GET /api/blocked-users`
   - Unblock user (with confirmation) → `DELETE /api/blocked-users/{userId}`

---

## Error Response Format

All error responses follow this format:

```json
{
  "success": false,
  "message": "Error message describing what went wrong"
}
```

Common HTTP status codes:
- `200 OK`: Successful operation
- `400 Bad Request`: Invalid input or business logic violation
- `403 Forbidden`: Not authorized to perform this action
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server-side error

---

## TODO / Future Enhancements

1. **Authentication**: Replace hardcoded `userId = 1` with actual JWT token parsing
2. **Notifications**: Send notifications when friend requests are sent/accepted/rejected
3. **Pagination Metadata**: Add total count and hasMore flags to list endpoints
4. **Rate Limiting**: Prevent spam friend requests
5. **Soft Delete**: Consider soft delete for friendships to maintain history
6. **Activity Log**: Track friendship and block actions in audit_logs table

---

**Last Updated:** 2024-11-24
**API Version:** 1.0
