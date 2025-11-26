# Friend Feature Testing Guide

## Prerequisites

1. **MySQL Database** must be running with the `study_p2p` schema
2. **Java Backend** running on port 8080
3. **Flutter Frontend** running (web or mobile)
4. At least 2 test users in the database

## Test Database Setup

If you need to create test users, run these SQL commands:

```sql
-- Create test users
INSERT INTO users (email, password_hash, display_name, status, created_at)
VALUES 
  ('alice@test.com', 'password123', 'Alice', 'ACTIVE', NOW()),
  ('bob@test.com', 'password123', 'Bob', 'ACTIVE', NOW()),
  ('charlie@test.com', 'password123', 'Charlie', 'ACTIVE', NOW()),
  ('david@test.com', 'password123', 'David', 'ACTIVE', NOW());
```

## Manual Test Cases

### Test 1: Send Friend Request
**Steps:**
1. Open Find Friends tab
2. Search for "Alice" (or another user)
3. Click "Add" button
4. Verify success message appears
5. Verify button changes to "Pending" badge

**Expected Result:**
- ✅ Success message: "Friend request sent successfully"
- ✅ Button shows orange "Pending" badge
- ✅ Backend creates entry in `friend_requests` table with status 'PENDING'

**SQL Verification:**
```sql
SELECT * FROM friend_requests WHERE from_user_id = 1 AND status = 'PENDING';
```

---

### Test 2: Accept Friend Request
**Prerequisites:** User 2 has received a friend request from User 1

**Steps:**
1. Login as User 2
2. Open Friend Requests tab
3. See request from User 1
4. Click green Accept button
5. Verify success message

**Expected Result:**
- ✅ Success message: "Friend request accepted"
- ✅ Request disappears from list
- ✅ User 1 appears in Friends tab
- ✅ Backend updates `friend_requests.status` to 'ACCEPTED'
- ✅ Backend creates entry in `friendships` table with state 'ACTIVE'

**SQL Verification:**
```sql
-- Check friend request status
SELECT * FROM friend_requests WHERE id = ?;

-- Check friendship created
SELECT * FROM friendships WHERE (user_id_a = 1 AND user_id_b = 2) OR (user_id_a = 2 AND user_id_b = 1);
```

---

### Test 3: Reject Friend Request
**Prerequisites:** User 2 has received a friend request from User 3

**Steps:**
1. Login as User 2
2. Open Friend Requests tab
3. Click red Reject button
4. Verify success message

**Expected Result:**
- ✅ Success message: "Friend request rejected"
- ✅ Request disappears from list
- ✅ Backend updates `friend_requests.status` to 'REJECTED'
- ✅ No friendship created

**SQL Verification:**
```sql
SELECT * FROM friend_requests WHERE id = ? AND status = 'REJECTED';
```

---

### Test 4: Remove Friend
**Prerequisites:** User 1 and User 2 are already friends

**Steps:**
1. Login as User 1
2. Open Friends tab
3. Click menu (3 dots) next to User 2
4. Select "Remove Friend"
5. Confirm in dialog
6. Verify success message

**Expected Result:**
- ✅ Confirmation dialog appears with correct message
- ✅ Success message: "Friend removed successfully"
- ✅ User 2 disappears from Friends list
- ✅ Backend deletes entry from `friendships` table

**SQL Verification:**
```sql
-- Should return no rows
SELECT * FROM friendships WHERE (user_id_a = 1 AND user_id_b = 2) OR (user_id_a = 2 AND user_id_b = 1);
```

---

### Test 5: Block User
**Prerequisites:** User 1 and User 2 are friends

**Steps:**
1. Login as User 1
2. Open Friends tab
3. Click menu (3 dots) next to User 2
4. Select "Block"
5. Read confirmation dialog
6. Confirm blocking

**Expected Result:**
- ✅ Confirmation dialog appears with warning about consequences
- ✅ Success message: "User blocked successfully"
- ✅ User 2 disappears from Friends list
- ✅ User 2 appears in Blocked Users tab
- ✅ Backend deletes friendship
- ✅ Backend deletes any pending friend requests
- ✅ Backend creates entry in `user_blocks` table

**SQL Verification:**
```sql
-- Check block created
SELECT * FROM user_blocks WHERE blocker_id = 1 AND blocked_id = 2;

-- Check friendship deleted
SELECT * FROM friendships WHERE (user_id_a = 1 AND user_id_b = 2) OR (user_id_a = 2 AND user_id_b = 1);

-- Check friend requests deleted
SELECT * FROM friend_requests WHERE (from_user_id = 1 AND to_user_id = 2) OR (from_user_id = 2 AND to_user_id = 1);
```

---

### Test 6: Unblock User
**Prerequisites:** User 1 has blocked User 2

**Steps:**
1. Login as User 1
2. Open Blocked Users tab
3. Find User 2 in the list
4. Click "Unblock" button
5. Confirm in dialog

**Expected Result:**
- ✅ Confirmation dialog appears
- ✅ Success message: "User unblocked successfully"
- ✅ User 2 disappears from Blocked Users list
- ✅ Backend deletes entry from `user_blocks` table

**SQL Verification:**
```sql
-- Should return no rows
SELECT * FROM user_blocks WHERE blocker_id = 1 AND blocked_id = 2;
```

---

### Test 7: Search Functionality
**Steps:**
1. Go to each tab (Friends, Friend Requests, Blocked Users, Find Friends)
2. Type in the search box
3. Verify filtered results

**Expected Result:**
- ✅ Results update as you type
- ✅ Minimum 2 characters required for Find Friends
- ✅ Search works for both display name and email
- ✅ Clear button (X) appears when text is entered
- ✅ Clicking clear button resets the search

---

### Test 8: Relationship Status Display
**Steps:**
1. Open Find Friends tab
2. Search for various users

**Expected Result:**
- ✅ Users with no relationship: Show "Add" button
- ✅ Users with pending request: Show orange "Pending" badge
- ✅ Blocked users: Show red "Blocked" badge
- ✅ Current friends: Should not appear in search results

---

### Test 9: Error Handling
**Test various error scenarios:**

**9.1 Send request to yourself**
- Try to send friend request to own account
- Expected: Error message

**9.2 Send duplicate request**
- Send request to same user twice
- Expected: Error message "Friend request already exists"

**9.3 Block already blocked user**
- Block the same user twice
- Expected: Error message

**9.4 Accept non-existent request**
- Manually call API with invalid request ID
- Expected: 404 error

---

## Backend API Testing (Manual)

Use tools like Postman or curl to test endpoints:

### Example: Send Friend Request
```bash
curl -X POST http://localhost:8080/api/friend-requests \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"toUserId": 2}'
```

### Example: List Friends
```bash
curl -X GET http://localhost:8080/api/friends \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Example: Accept Friend Request
```bash
curl -X POST http://localhost:8080/api/friend-requests/1/accept \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Performance Testing

### Load Test Checklist
- [ ] List 100+ friends (add pagination if needed)
- [ ] Search through large dataset
- [ ] Rapid clicking on buttons (test debouncing)
- [ ] Concurrent requests from multiple users

---

## Browser Testing

Test on multiple browsers:
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

Test on mobile devices:
- [ ] iOS Safari
- [ ] Android Chrome

---

## Known Limitations (Current Version)

1. **Authentication:** Using hardcoded `userId = 1` instead of JWT token
2. **Pagination:** Large lists may load slowly (pagination not implemented yet)
3. **Real-time:** No WebSocket updates (need manual refresh)
4. **Message Feature:** Placeholder only, not implemented

---

## Reporting Issues

If you find a bug:
1. Note the exact steps to reproduce
2. Take screenshot of error message
3. Check browser console for errors
4. Check server logs for backend errors
5. Document database state using SQL queries

---

**Test Status:** Ready for Testing  
**Last Updated:** 2025-11-24
