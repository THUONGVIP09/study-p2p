# 🔧 Fix: Relay Messages Not Being Saved to Storage

## Bug Description
Messages sent via relay fallback were **NOT** being saved to storage, causing them to disappear after reload.

### Scenario
1. Friend is **online** → P2P info retrieved
2. Send message → P2P socket already **closed** (short-lived pattern)
3. Fallback to relay → `relay == null` ❌
4. Message sent to UI but **NOT saved** to storage
5. Lost messages: "thanks", "okok, you can join"

## Root Cause
From logs analysis:
```
📨 [HYBRID] SEND to friend 16: thanks
   Attempting P2P to 127.0.0.1:64626...
❌ [HYBRID] P2P send failed: SocketException... trying relay...
✅ [UI] Send completed, updating UI...
   After add: 4 messages
```
**NO STORAGE OPERATION** executed! ❌

**Why?**
- Old code opened relay connection **ONLY when friend was offline**
- If friend online → relay = null
- P2P fails later → relay fallback code executes but `relay == null`
- Storage save code never reached:
  ```dart
  final ch = relay;
  if (ch != null) {  // ← ch is NULL!
    ch.sink.add(...);
    await ChatStorageService.addMessage(...); // Never executes!
  }
  ```

## Solution Applied
**Always open relay connection as backup** (defense in depth strategy)

### Code Changes in `hybrid_chat_service.dart`

#### Before (Bug):
```dart
Future<bool> connectToFriend(int friendId) async {
  // Check if friend is online from broadcast list
  if (_friendToPeerId.containsKey(friendId)) {
    return true; // We have their IP:Port
  }
  
  // Query server
  final info = await ChatApiService.getFriendPeerInfo(friendId);
  if (info['online'] == true) {
    // Setup P2P mapping
    return true;
  }
  
  // ONLY open relay if friend is OFFLINE ❌
  print('❌ Friend $friendId is offline, will use relay when available');
  try {
    final ws = await WebSocket.connect(...);
    relay = IOWebSocketChannel(ws);
    // ...
  }
}
```

#### After (Fixed):
```dart
Future<bool> connectToFriend(int friendId) async {
  // ALWAYS open relay connection FIRST as backup ✅
  if (relay == null) {
    try {
      print('🔌 [HYBRID] Opening relay connection as backup...');
      final ws = await WebSocket.connect(...);
      relay = IOWebSocketChannel(ws);
      // Setup relay receive handler with storage save
      print('✅ [HYBRID] Relay connection opened successfully');
    } catch (e) {
      print('❌ [HYBRID] Failed to open relay: $e');
    }
  }

  // NOW check if friend is online
  if (_friendToPeerId.containsKey(friendId)) {
    return true;
  }
  
  // Query server for P2P info
  final info = await ChatApiService.getFriendPeerInfo(friendId);
  if (info['online'] == true) {
    // Setup P2P mapping
    return true;
  }
  
  print('⚠️ [HYBRID] Friend $friendId offline, relay-only mode');
  return false;
}
```

## Expected Behavior After Fix

### Test Scenario (Same as before):
1. User 15 sends: "hi" (P2P works)
2. User 15 sends: "how are you" (P2P works)
3. User 15 sends: "thanks" (P2P fails → **relay fallback**)

### Expected Logs:
```
📨 [HYBRID] SEND to friend 16: thanks
   Attempting P2P to 127.0.0.1:64626...
❌ [HYBRID] P2P send failed: SocketException... trying relay...
📤 [HYBRID] Sending via Relay to friend 16
💾 [HYBRID] Calling ChatStorageService.addMessage for sent relay...
🔵 [Op #5] ADD MESSAGE to peer 16
   Current messages count: 4
   Adding message: {sender: me, content: thanks, ...}
💾 [Write #5] Writing to file...
💾 [Write #5] File written, size: 842 bytes
✅ [Op #5] COMPLETED
   Final count: 5 messages
```

### Verification:
✅ Message "thanks" saved to storage  
✅ Message "okok, you can join" saved to storage  
✅ Messages persist after reload  
✅ No duplicates  

## Summary
**Defense in Depth**: Open relay connection **proactively** regardless of friend's online status. This ensures relay fallback always works, even when P2P initially succeeds but later fails mid-conversation.

## Related Files Modified
- `lib/services/hybrid_chat_service.dart` (lines 105-181)

## Testing Instructions
1. Run `.\run_test_instances.ps1` to start 2 Flutter instances
2. Login as User 15 and User 16
3. Send messages: "hi", "how are you", "thanks", "okok, you can join"
4. Check logs for storage operations on ALL messages
5. Reload app → verify all messages still present
6. Check logs in `logs_instance1.txt` and `logs_instance2.txt`

## Keywords for Log Filtering
- `[Op #` - Storage operations
- `💾 [HYBRID]` - Storage save calls
- `📤 [HYBRID] Sending via Relay` - Relay send
- `✅ [Op #` - Completed operations
