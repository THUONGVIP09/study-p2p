# PHÂN TÍCH CHI TIẾT CÁC LỚP VÀ PHƯƠNG THỨC TRONG PHÒNG HỌP (ROOM)

## I. CÁC LỚP MODEL (Data Models)

### 1. **Room** (`lib/models/room.dart`)
**Mục đích:** Đại diện cho một phòng họp trong hệ thống.

**Thuộc tính:**
- `int id` - ID phòng trong database
- `int conversationId` - ID của cuộc hội thoại liên kết
- `String name` - Tên phòng
- `String roomCode` - Mã phòng duy nhất (VD: "R000001")
- `String? description` - Mô tả phòng (tùy chọn)
- `String visibility` - Chế độ hiển thị: PUBLIC/PRIVATE/PROTECTED
- `int? maxParticipants` - Số người tối đa (tùy chọn)
- `int createdBy` - ID người tạo phòng
- `bool isActive` - Trạng thái hoạt động
- `DateTime? createdAt` - Thời gian tạo

**Phương thức:**
- `Room.fromJson(Map<String, dynamic> json)` - Factory constructor để parse JSON từ API

---

### 2. **CallSession** (`lib/models/call_session.dart`)
**Mục đích:** Đại diện cho một phiên gọi video/audio trong phòng.

**Thuộc tính:**
- `int id` - ID phiên gọi
- `int roomId` - ID phòng liên kết
- `int createdBy` - ID người khởi tạo
- `String topology` - Kiểu kết nối: "p2p" hoặc "sfu"
- `String? sfuRegion` - Vùng SFU server (nếu dùng SFU)
- `String? sfuRoomId` - ID phòng SFU (thường = roomCode)
- `DateTime? startedAt` - Thời gian bắt đầu
- `DateTime? endedAt` - Thời gian kết thúc
- `int? liveCount` - Số người đang online

**Phương thức:**
- `CallSession.fromJson(Map<String, dynamic> json)` - Parse từ JSON
- `bool get isLive` - Kiểm tra phiên còn hoạt động (endedAt == null)

---

### 3. **ChatMessage** (`lib/models/chat_message.dart`)
**Mục đích:** Đại diện cho một tin nhắn chat trong phòng.

**Thuộc tính:**
- `String id` - ID tin nhắn (client-side)
- `int senderId` - ID người gửi
- `String senderName` - Tên người gửi
- `String text` - Nội dung tin nhắn
- `DateTime timestamp` - Thời gian gửi
- `bool isSelf` - Kiểm tra có phải tin nhắn của mình
- `int? messageId` - ID tin nhắn từ server DB (tùy chọn)

---

### 4. **PeerInfo** (`lib/call_page.dart`, dòng 40-46)
**Mục đích:** Lưu thông tin về một peer (người tham gia khác) trong phòng.

**Thuộc tính:**
- `String uid` - Unique ID của peer
- `String name` - Tên hiển thị
- `RTCVideoRenderer renderer` - Video renderer để hiển thị video
- `RTCPeerConnection? pc` - WebRTC PeerConnection (nullable)

---

## II. LỚP UI CHÍNH

### 5. **P2PCallPage** (`lib/call_page.dart`, dòng 17-37)
**Mục đích:** Widget chính cho màn hình phòng họp P2P.

**Thuộc tính (Input):**
- `Room room` - Thông tin phòng
- `CallSession callSession` - Thông tin phiên gọi
- `int currentUserId` - ID người dùng hiện tại
- `bool? initialMicMuted` - Trạng thái mic ban đầu
- `bool? initialCamEnabled` - Trạng thái camera ban đầu
- `String? displayName` - Tên hiển thị

**Phương thức:**
- `State<P2PCallPage> createState()` - Tạo state widget

---

### 6. **_P2PCallPageState** (`lib/call_page.dart`, dòng 49+)
**Mục đích:** State quản lý toàn bộ logic phòng họp.

#### **A. THUỘC TÍNH STATE**

**Media & WebRTC:**
- `RTCVideoRenderer _localRenderer` - Renderer video local
- `Map<String, PeerInfo> _peers` - Map các peer (uid → PeerInfo)
- `MediaStream? _localStream` - Stream video/audio local
- `MediaStream? _screenStream` - Stream chia sẻ màn hình
- `WebSocketChannel? _ws` - WebSocket signaling
- `String _myUid` - UID của mình

**P2P Chat:**
- `P2PTcpServer? _p2pServer` - TCP server cho mobile/desktop
- `Map<String, Map<String, dynamic>> _roomPeers` - Danh sách peers với IP/port
- `String? _myLocalIp` - IP cục bộ
- `WebRTCP2PChat? _webrtcP2PChat` - P2P chat cho web

**UI State:**
- `bool micMuted` - Mic tắt/bật
- `bool camEnabled` - Camera bật/tắt
- `bool _isAudioOnlyMode` - Chế độ chỉ audio
- `bool _isScreenSharing` - Đang chia sẻ màn hình
- `String _activePanel` - Panel đang mở: none/participants/chat/settings
- `List<ChatMessage> _messages` - Danh sách tin nhắn
- `TextEditingController _chatController` - Controller input chat
- `ScrollController _chatScrollController` - Controller scroll chat
- `String? _awaitEchoText` - Text chờ để tránh duplicate echo
- `String _viewMode` - Chế độ xem: grid/list
- `bool _isFullscreen` - Chế độ toàn màn hình

---

#### **B. PHƯƠNG THỨC KHỞI TẠO & LIFECYCLE**

**1. initState()**
- Tạo unique UID cho user
- Khởi tạo trạng thái mic/cam từ props
- Gọi `_initAll()`

**2. _initAll()**
```dart
Future<void> _initAll() async
```
- Initialize local renderer
- Khởi tạo P2P chat (web: WebRTC, mobile: TCP)
- Bật local stream (getUserMedia)
- Kết nối WebSocket signaling

**3. dispose()**
- Đóng WebSocket
- Đóng tất cả PeerConnections
- Dispose renderers & streams

---

#### **C. PHƯƠNG THỨC P2P CHAT**

**1. _initWebRTCP2PChat()**
```dart
void _initWebRTCP2PChat()
```
- Tạo instance `WebRTCP2PChat`
- Truyền callback `sendSignal` để gửi signaling qua WS
- Truyền callback `onMessageReceived` để nhận tin nhắn P2P

**2. _initP2PServer()**
```dart
Future<void> _initP2PServer() async
```
- Lấy IP local của device
- Khởi tạo `P2PTcpServer` trên port 9999
- Set callback `onMessageReceived` để nhận chat từ TCP peers

**3. _broadcastToPeersP2P()**
```dart
Future<void> _broadcastToPeersP2P(String text, int senderId, String senderName, DateTime timestamp)
```
- **Web:** Gọi `_webrtcP2PChat.broadcast()` qua DataChannel
- **Mobile/Desktop:** Gọi `_p2pServer.broadcastToPeers()` qua TCP
- **Pure P2P:** Không relay qua server

**4. _handleIncomingChat()**
```dart
void _handleIncomingChat(int senderId, String senderName, String text, DateTime ts, {int? messageId})
```
- Tạo `ChatMessage` object
- Thêm vào `_messages` list
- Scroll chat xuống dưới cùng
- Update UI (setState)

**5. _onSendChat()**
```dart
void _onSendChat()
```
- Đọc text từ `_chatController`
- Tạo `ChatMessage` (isSelf = true)
- Thêm vào UI local ngay lập tức (optimistic update)
- Lưu vào `LocalMessageStorage`
- Broadcast qua P2P (`_broadcastToPeersP2P`)
- Set `_awaitEchoText` để tránh duplicate

---

#### **D. PHƯƠNG THỨC MEDIA & WEBRTC**

**1. _startLocalStream()**
```dart
Future<void> _startLocalStream({bool allowFailure = false})
```
- Gọi `getUserMedia({audio: true, video: {...}})`
- **Fallback:** Nếu lỗi video → chỉ lấy audio (audio-only mode)
- Set `_localRenderer.srcObject`
- Add tracks vào tất cả PeerConnections đã có
- Áp dụng trạng thái mic/cam (`_applyPrejoinStates`)

**2. _applyPrejoinStates()**
```dart
void _applyPrejoinStates()
```
- Enable/disable audio tracks theo `micMuted`
- Enable/disable video tracks theo `camEnabled`

**3. _createPeerConnection()**
```dart
Future<RTCPeerConnection> _createPeerConnection(String peerUid)
```
- Tạo `RTCPeerConnection` với STUN server
- Set `sdpSemantics: 'unified-plan'`
- Set callback `onIceCandidate` → gửi ICE qua signaling
- Set callback `onTrack` → nhận remote video/audio → gán vào renderer
- Set callback `onAddStream` (fallback Plan-B)
- Add local tracks nếu đã có stream

---

#### **E. PHƯƠNG THỨC SIGNALING & PEER MANAGEMENT**

**1. _connectWs()**
```dart
Future<void> _connectWs()
```
- Kết nối WebSocket tới signaling server (port 8081)
- Listen stream → gọi `_onWsMessage()`
- Gửi message `{t: 'join', room, uid, name, userId, peerIp, peerPort}`

**2. _send()**
```dart
void _send(Map<String, dynamic> m)
```
- Encode JSON và gửi qua WebSocket
- Log message gửi đi

**3. _onWsMessage()**
```dart
Future<void> _onWsMessage(Map<String, dynamic> m)
```
**Switch case theo message type:**
- **'peers'**: Nhận danh sách peers có sẵn
  - Lưu vào `_roomPeers`
  - Khởi tạo WebRTC P2P cho từng peer (web)
  - Gọi `_addPeer()` và `_createOfferForPeer()`
  
- **'peer.joined'**: Có người mới join
  - Lưu peer info
  - Gọi `_addPeer()`
  - Chờ người mới gửi offer (tránh glare)
  
- **'offer'**: Nhận WebRTC call offer
  - Gọi `_handleOffer()`
  
- **'answer'**: Nhận WebRTC call answer
  - Gọi `_handleAnswer()`
  
- **'ice'**: Nhận ICE candidate
  - Gọi `_handleIce()`
  
- **'webrtc.offer'**: Nhận P2P chat offer
  - Gọi `_webrtcP2PChat.handleOffer()`
  
- **'webrtc.answer'**: Nhận P2P chat answer
  - Gọi `_webrtcP2PChat.handleAnswer()`
  
- **'webrtc.ice'**: Nhận P2P chat ICE
  - Gọi `_webrtcP2PChat.handleIceCandidate()`
  
- **'peer.left'**: Peer rời phòng
  - Gọi `_removePeer()`
  
- **'peer.kicked'**: Peer bị kick
  - Nếu là mình → `_leave()`
  - Nếu là người khác → `_removePeer()`

**4. _addPeer()**
```dart
Future<void> _addPeer(String uid, String name)
```
- Bỏ qua nếu peer đã tồn tại
- Bỏ qua approval connection (dựa trên pattern uid)
- Tạo `RTCVideoRenderer` mới
- Initialize renderer
- Tạo `PeerInfo` và thêm vào `_peers`
- Update UI (setState)

**5. _removePeer()**
```dart
Future<void> _removePeer(String uid)
```
- Lấy peer từ `_peers`
- Đóng PeerConnection
- Dispose renderer
- Xóa khỏi map
- Update UI

**6. _createOfferForPeer()**
```dart
Future<void> _createOfferForPeer(String peerUid)
```
- Đảm bảo local stream đã sẵn sàng
- Tạo PC nếu chưa có
- Tạo offer với `offerToReceiveAudio/Video = 1`
- Set local description
- Gửi offer qua signaling

**7. _handleOffer()**
```dart
Future<void> _handleOffer(Map<String, dynamic> m)
```
- Lấy fromUid và SDP
- Tạo peer nếu chưa có
- Tạo PC nếu chưa có
- Set remote description (offer)
- Tạo answer
- Set local description
- Gửi answer qua signaling

**8. _handleAnswer()**
```dart
Future<void> _handleAnswer(Map<String, dynamic> m)
```
- Lấy PC của peer
- Set remote description (answer)

**9. _handleIce()**
```dart
Future<void> _handleIce(Map<String, dynamic> m)
```
- Lấy PC của peer
- Tạo `RTCIceCandidate`
- Add candidate vào PC

---

#### **F. PHƯƠNG THỨC CHIA SẺ MÀN HÌNH**

**1. _toggleScreenSharing()**
```dart
Future<void> _toggleScreenSharing()
```
- Nếu đang share → `_stopScreenSharing()`
- Nếu chưa share → `_startScreenSharing()`

**2. _startScreenSharing()**
```dart
Future<void> _startScreenSharing()
```
- **Kiểm tra platform:** Cảnh báo nếu desktop (khuyến nghị web)
- Gọi `getDisplayMedia()` để capture màn hình
- Set `_screenStream`
- Set `_isScreenSharing = true`
- Listen `videoTrack.onEnded` → auto stop khi user dừng từ browser
- Replace video track trong `_localRenderer`
- Replace video track trong TẤT CẢ PeerConnections (gọi `replaceTrack`)
- Hiển thị thông báo

**3. _stopScreenSharing()**
```dart
Future<void> _stopScreenSharing()
```
- Stop tất cả tracks của screen stream
- Dispose screen stream
- Set `_isScreenSharing = false`
- Quay về camera stream trong `_localRenderer`
- Replace lại video track về camera trong TẤT CẢ PeerConnections
- Hiển thị thông báo

---

#### **G. PHƯƠNG THỨC UI BUILDERS**

**1. build()**
```dart
Widget build(BuildContext context)
```
- Scaffold với AppBar, body (Row chứa taskbar + video + panel), controls

**2. _buildVideoGrid()**
```dart
Widget _buildVideoGrid()
```
- Responsive grid layout (1-4 cột tùy width)
- GridView.builder với local tile (index 0) + remote tiles
- Tính `crossAxisCount` dựa trên số người và width

**3. _buildLocalVideoTile()**
```dart
Widget _buildLocalVideoTile()
```
- Hiển thị video local hoặc placeholder (avatar)
- Border màu tím (local)
- Label "You (Sharing Screen)" nếu đang share

**4. _buildRemoteVideoTile()**
```dart
Widget _buildRemoteVideoTile(PeerInfo peer)
```
- Hiển thị video remote hoặc placeholder
- Border xám (remote)
- Label tên peer

**5. _buildChatPanel()**
```dart
Widget _buildChatPanel()
```
- Header với title "Chat trong cuộc gọi"
- ListView tin nhắn với bubble style (tím cho self, xám cho other)
- Input field với emoji picker button + send button

**6. _buildParticipantsPanel()**
```dart
Widget _buildParticipantsPanel()
```
- ListView participants
- Hiển thị role (host/member)
- Kick button cho host (nếu không phải chính mình và không phải host khác)

**7. _buildSettingsPanel()**
```dart
Widget _buildSettingsPanel()
```
- Chuyển chế độ xem (grid/list)
- Toggle fullscreen

**8. _openEmojiPicker()**
```dart
void _openEmojiPicker()
```
- Show modal bottom sheet với grid emoji
- Chọn emoji → append vào chat input

**9. _scrollChatToBottom()**
```dart
void _scrollChatToBottom()
```
- Scroll chat controller xuống cuối (sau khi có tin nhắn mới)
- Dùng `addPostFrameCallback` để đảm bảo layout đã xong

---

#### **H. PHƯƠNG THỨC QUẢN LÝ PHÒNG**

**1. _kickMember()**
```dart
void _kickMember(String uid)
```
- Gửi message `{t: 'kick', uid, room}`
- Optimistic remove local
- Hiển thị snackbar

**2. _leave()**
```dart
Future<void> _leave()
```
- Gửi message `{t: 'leave', uid}`
- Đóng WebSocket
- Đóng tất cả PeerConnections
- Dispose renderers
- Stop screen stream nếu có
- Stop local stream
- Pop navigator (quay về màn hình trước)

**3. _isApprovalConnection()**
```dart
bool _isApprovalConnection(String uid)
```
- Kiểm tra uid có phải approval connection không (pattern: `host_` hoặc `_`)
- Dùng để filter peer approval vs. call connection

**4. _isLocalVideoActive()**
```dart
bool _isLocalVideoActive()
```
- Kiểm tra video local có đang hiển thị không
- True nếu: screen sharing HOẶC (có stream + không audio-only + cam enabled + có video track enabled)

**5. _isPeerVideoActive()**
```dart
bool _isPeerVideoActive(PeerInfo peer)
```
- Kiểm tra video của peer có đang hiển thị không
- Dựa trên `renderer.srcObject` và video tracks enabled

**6. _formatTime()**
```dart
String _formatTime(DateTime dt)
```
- Format DateTime thành "HH:mm"
- Dùng cho timestamp tin nhắn chat

---

## III. LỚP P2P CHAT SERVICE

### 7. **WebRTCP2PChat** (`lib/services/webrtc_p2p_chat.dart`)
**Mục đích:** Quản lý WebRTC DataChannel P2P cho chat (chỉ web).

**Thuộc tính:**
- `String myUid` - UID của mình
- `Function(Map<String, dynamic>) sendSignal` - Callback gửi signaling
- `Function(String peerId, Map<String, dynamic> message)? onMessageReceived` - Callback nhận message
- `Map<String, RTCPeerConnection> _peerConnections` - Map PeerConnections
- `Map<String, RTCDataChannel> _dataChannels` - Map DataChannels
- `Map<String, List<RTCIceCandidate>> _pendingCandidates` - ICE candidates chờ xử lý

**Phương thức:**

**1. initPeerConnection(String peerId)**
```dart
Future<void> initPeerConnection(String peerId)
```
- Kiểm tra platform (chỉ web)
- Tạo PC nếu chưa có
- Gọi `_createAndSendOffer()`

**2. _createPeerConnectionForPeer(String peerId)**
```dart
Future<RTCPeerConnection> _createPeerConnectionForPeer(String peerId)
```
- Tạo `RTCPeerConnection` với STUN
- Set `onIceCandidate` → gửi signaling
- Set `onDataChannel` → setup khi nhận channel từ remote

**3. _createAndSendOffer(String peerId, RTCPeerConnection pc)**
```dart
Future<void> _createAndSendOffer(String peerId, RTCPeerConnection pc)
```
- Tạo DataChannel "chat" trước khi offer
- Setup DataChannel
- Tạo offer
- Set local description
- Gửi signaling `{t: 'webrtc.offer', targetUid, sdp}`

**4. _setupDataChannel(String peerId, RTCDataChannel channel)**
```dart
void _setupDataChannel(String peerId, RTCDataChannel channel)
```
- Lưu vào `_dataChannels`
- Set `onMessage` → parse JSON → gọi callback
- Set `onDataChannelState` → log khi open/closed

**5. handleOffer(String fromUid, String sdp)**
```dart
Future<void> handleOffer(String fromUid, String sdp)
```
- Tạo PC nếu chưa có
- Set remote description
- Tạo answer
- Set local description
- Gửi signaling `{t: 'webrtc.answer', targetUid, sdp}`
- Add pending ICE candidates

**6. handleAnswer(String fromUid, String sdp)**
```dart
Future<void> handleAnswer(String fromUid, String sdp)
```
- Lấy PC
- Set remote description
- Add pending ICE candidates

**7. handleIceCandidate(String fromUid, String candidate, String? sdpMid, int sdpMLineIndex)**
```dart
Future<void> handleIceCandidate(...)
```
- Nếu chưa có PC hoặc chưa có remote description → queue vào `_pendingCandidates`
- Nếu đã sẵn sàng → add candidate ngay

**8. sendToPeer(String peerId, Map<String, dynamic> message)**
```dart
Future<bool> sendToPeer(String peerId, Map<String, dynamic> message)
```
- Kiểm tra DataChannel đã open chưa
- Encode JSON
- Send qua DataChannel
- Return true/false

**9. broadcast(Map<String, dynamic> message)**
```dart
Future<void> broadcast(Map<String, dynamic> message)
```
- Loop qua tất cả `_dataChannels`
- Gọi `sendToPeer()` cho từng peer

**10. closePeer(String peerId)**
```dart
Future<void> closePeer(String peerId)
```
- Đóng DataChannel
- Đóng PeerConnection
- Xóa khỏi maps

**11. dispose()**
```dart
Future<void> dispose()
```
- Đóng tất cả peers

---

### 8. **P2PTcpServer** (`lib/services/p2p_tcp_server.dart`)
**Mục đích:** TCP server local để nhận tin nhắn P2P (mobile/desktop).

**Thuộc tính:**
- `dynamic _server` - ServerSocket (null trên web)
- `int port` - Port (mặc định 9999)
- `Function(Map<String, dynamic>)? onMessageReceived` - Callback nhận message

**Phương thức:**

**1. start()**
```dart
Future<bool> start()
```
- Kiểm tra platform (disabled trên web)
- Bind ServerSocket trên '0.0.0.0:9999'
- Listen connections → gọi `_handlePeerSocket()`

**2. _handlePeerSocket(dynamic socket)**
```dart
void _handlePeerSocket(dynamic socket)
```
- Listen socket data
- Buffer và split theo delimiter '\n'
- Parse JSON
- Gọi `onMessageReceived` callback

**3. sendToPeer(String peerIp, Map<String, dynamic> message)**
```dart
Future<bool> sendToPeer(String peerIp, Map<String, dynamic> message)
```
- Connect tới peer:9999
- Write JSON + '\n'
- Close socket
- Return true/false

**4. broadcastToPeers(List<String> peerIps, Map<String, dynamic> message)**
```dart
Future<void> broadcastToPeers(List<String> peerIps, Map<String, dynamic> message)
```
- Loop qua peer IPs
- Gọi `sendToPeer()` cho từng IP
- Dùng `Future.wait()`

**5. stop()**
```dart
Future<void> stop()
```
- Đóng server socket

---

### 9. **LocalMessageStorage** (`lib/services/local_message_storage.dart`)
**Mục đích:** Lưu tin nhắn chat offline sử dụng SharedPreferences.

**Thuộc tính:**
- `static SharedPreferences? _prefs` - Instance SharedPreferences

**Phương thức:**

**1. initialize()**
```dart
static Future<void> initialize()
```
- Khởi tạo SharedPreferences nếu chưa có

**2. saveMessage(...)**
```dart
static Future<void> saveMessage({
  required String roomCode,
  required int senderId,
  required String senderName,
  required String text,
  required DateTime timestamp,
  bool synced = false,
})
```
- Tạo message object
- Lưu vào list messages của room (key: `room_messages_{roomCode}`)
- Track unsynced messages nếu `synced = false`

**3. getMessages(String roomCode)**
```dart
static Future<List<Map<String, dynamic>>> getMessages(String roomCode)
```
- Lấy tất cả messages của room từ SharedPreferences
- Parse JSON và return list

**4. getUnsyncedMessages(String roomCode)**
```dart
static Future<List<Map<String, dynamic>>> getUnsyncedMessages(String roomCode)
```
- Lấy messages chưa sync (synced != true)
- Dùng để sync lên server sau

**5. markAsSynced(String roomCode, List<String> messageIds)**
```dart
static Future<void> markAsSynced(String roomCode, List<String> messageIds)
```
- Update `synced = true` cho các message IDs
- Clear danh sách unsynced

**6. clearRoom(String roomCode)**
```dart
static Future<void> clearRoom(String roomCode)
```
- Xóa tất cả messages của room

---

## IV. SERVER-SIDE (Java)

### 10. **SignalingEndpoint** (`server-java/.../SignalingEndpoint.java`)
**Mục đích:** WebSocket endpoint cho signaling.

**Thuộc tính:**
- `static Map<Session, ClientCtx> CLIENTS` - Map session → client context
- `static Map<String, Session> UID_INDEX` - Map uid → session
- `static Map<String, Set<Session>> ROOM_SESS` - Map roomCode → sessions
- `static Map<String, List<Map<String, String>>> PENDING_REQUESTS` - Join requests

**Phương thức chính:**

**1. onOpen(Session s, EndpointConfig cfg)**
```java
@OnOpen
public void onOpen(Session s, EndpointConfig cfg)
```
- Tạo `ClientCtx` cho session mới
- Lưu vào `CLIENTS`

**2. onMessage(String raw, Session s)**
```java
@OnMessage
public void onMessage(String raw, Session s)
```
**Switch case theo message type:**

- **"join"**: 
  - Parse roomCode, uid, name, userId, peerIp, peerPort
  - Lưu vào `ClientCtx`
  - Add vào `UID_INDEX` và `ROOM_SESS`
  - Trả danh sách peers với `{t: 'peers', peers: [...]}`
  - Gửi chat history từ DB (nếu có)
  - Broadcast `{t: 'peer.joined', uid, name, ip, port}` cho người khác

- **"leave"**:
  - Broadcast `{t: 'peer.left', uid}`
  - Remove khỏi `ROOM_SESS`

- **"join_request"** (PROTECTED room):
  - Lưu request vào `PENDING_REQUESTS`
  - Tìm host → gửi `{t: 'join_request', requestId, uid, name}`

- **"approve_join"**:
  - Tìm requester session
  - Gửi `{t: 'join_approved', roomCode}`
  - Remove request khỏi pending

- **"reject_join"**:
  - Gửi `{t: 'join_rejected', roomCode, reason}`
  - Remove request

- **"kick"**:
  - Tìm target session
  - Gửi `{t: 'peer.kicked', uid}`
  - Broadcast cho người khác `{t: 'peer.left', uid}`
  - Close target session

- **"offer"**: Forward WebRTC call offer
- **"answer"**: Forward WebRTC call answer
- **"ice"**: Forward ICE candidate

- **"webrtc.offer"**: Forward P2P chat offer
  - Parse targetUid, sdp
  - Tạo payload `{t: 'webrtc.offer', fromUid, fromName, sdp}`
  - Gửi tới target session

- **"webrtc.answer"**: Forward P2P chat answer
  - Tương tự offer

- **"webrtc.ice"**: Forward P2P chat ICE
  - Parse targetUid, candidate, sdpMid, sdpMLineIndex
  - Forward tới target

- **"chat"**: Server relay chat (ĐÃ TẮT trong P2P mode)
- **"chat.broadcast"**: Broadcast chat (ĐÃ TẮT)

**3. onClose(Session s, CloseReason cr)**
```java
@OnClose
public void onClose(Session s, CloseReason cr)
```
- Broadcast `{t: 'peer.left', uid}`
- Remove khỏi tất cả maps

**4. broadcast(String room, Map<String, Object> m, Session exclude)**
```java
private void broadcast(String room, Map<String, Object> m, Session exclude)
```
- Loop qua tất cả sessions trong room
- Gửi message (trừ session exclude)

**5. send(Session s, Object obj)**
```java
private void send(Session s, Object obj)
```
- Serialize object thành JSON
- Gửi qua WebSocket session

---

## V. TÓM TẮT LUỒNG HOẠT ĐỘNG

### A. JOIN PHÒNG
1. Client → WS: `{t: 'join', room, uid, name, userId, peerIp, peerPort}`
2. Server → Client: `{t: 'peers', peers: [...]}`
3. Client: 
   - Lưu peers vào `_roomPeers`
   - Init WebRTC P2P cho mỗi peer (web)
   - Add peer vào `_peers`
   - Create offer (call) cho mỗi peer
4. Server → Others: `{t: 'peer.joined', uid, name, ip, port}`
5. Others: Add peer, chờ offer từ người mới

### B. CHAT P2P
1. User gửi tin:
   - UI: `_onSendChat()` → lưu local → `_broadcastToPeersP2P()`
   - **Web:** `WebRTCP2PChat.broadcast()` → DataChannel.send()
   - **Mobile:** `P2PTcpServer.broadcastToPeers()` → TCP socket
2. Peer nhận:
   - **Web:** `onDataChannel.onMessage` → `_handleIncomingChat()`
   - **Mobile:** `P2PTcpServer.onMessageReceived` → `_handleIncomingChat()`
3. Lưu vào `LocalMessageStorage`

### C. VIDEO CALL
1. Offer/Answer/ICE qua signaling WS
2. PeerConnection thiết lập
3. `onTrack` → renderer.srcObject → hiển thị video

### D. CHIA SẺ MÀN HÌNH
1. `_startScreenSharing()` → getDisplayMedia()
2. Replace video track trong tất cả PC
3. Hiển thị label "Sharing Screen"
4. `_stopScreenSharing()` → quay về camera

---

## VI. SƠ ĐỒ QUAN HỆ GIỮA CÁC LỚP

```
┌─────────────────────────────────────────────────────────┐
│                    P2PCallPage                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │         _P2PCallPageState                           │ │
│ │                                                     │ │
│ │  ┌──────────────┐      ┌──────────────┐            │ │
│ │  │ WebSocket    │      │ WebRTC       │            │ │
│ │  │ Signaling    │◄────►│ Call (A/V)   │            │ │
│ │  └──────────────┘      └──────────────┘            │ │
│ │                                                     │ │
│ │  ┌──────────────┐      ┌──────────────┐            │ │
│ │  │ WebRTC P2P   │      │ P2P TCP      │            │ │
│ │  │ Chat (Web)   │      │ Server (Mob) │            │ │
│ │  └──────────────┘      └──────────────┘            │ │
│ │         │                      │                   │ │
│ │         └──────────┬───────────┘                   │ │
│ │                    │                               │ │
│ │              ┌─────▼─────┐                         │ │
│ │              │ Local     │                         │ │
│ │              │ Storage   │                         │ │
│ │              └───────────┘                         │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         ▲
                         │
                    Uses Models:
                ┌────────┼────────┐
                │        │        │
           ┌────▼───┐ ┌──▼──┐ ┌──▼────────┐
           │ Room   │ │Call │ │Chat       │
           │        │ │Sess │ │Message    │
           └────────┘ └─────┘ └───────────┘
```

---

## VII. CÁCH SỬ DỤNG TÀI LIỆU NÀY

**Khi trình bày với thầy:**
1. Giải thích từng lớp và vai trò
2. Vẽ sơ đồ luồng (join, chat, call, screen share)
3. Nhấn mạnh:
   - Pure P2P chat (không relay server)
   - WebRTC cho web, TCP cho mobile
   - Offline storage với LocalMessageStorage
   - Signaling chỉ dùng cho offer/answer/ice

**Tài liệu này bao gồm:**
- ✅ Tất cả lớp liên quan
- ✅ Tất cả phương thức quan trọng
- ✅ Luồng hoạt động chi tiết
- ✅ Sơ đồ quan hệ

**Copy vào Word:**
- Giữ nguyên format Markdown
- Hoặc convert sang Word bằng Pandoc
- Thêm hình minh họa nếu cần
