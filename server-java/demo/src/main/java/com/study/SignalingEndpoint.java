package com.study;

import com.google.gson.*;
import jakarta.websocket.*;
import jakarta.websocket.server.ServerEndpoint;
import java.io.IOException;
import java.sql.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

@ServerEndpoint(value = "/ws")
public class SignalingEndpoint {


  private static final Gson GSON = new Gson();

  // session -> context
  private static final Map<Session, ClientCtx> CLIENTS = new ConcurrentHashMap<>();
  // roomCode -> sessions
  private static final Map<String, Set<Session>> ROOM_SESS = new ConcurrentHashMap<>();
  // uid -> session
  private static final Map<String, Session> UID_INDEX = new ConcurrentHashMap<>();
  // Pending join requests: roomCode -> list of {uid, name, requestId}
  private static final Map<String, List<Map<String, String>>> PENDING_REQUESTS = new ConcurrentHashMap<>();

  static final class ClientCtx {
    String uid;
    String name;
    String room;     // roomCode dạng ROOM-0001
    Long userId;     // DB user ID nếu có
    String peerIp;   // Local IP của device (cho P2P)
    String peerPort; // Port TCP server (default 9999)
    Instant at = Instant.now();
  }

  /* ---------- Helpers ---------- */

  private void debugPrint(String msg) {
    System.out.println("[SignalingEndpoint] " + msg);
  }

  private void send(Session s, Object obj) {
    if (s == null || !s.isOpen()) return;
    try { s.getBasicRemote().sendText(GSON.toJson(obj)); } catch (IOException ignored) {}
  }

  private void broadcast(String room, Object obj, Session except) {
    var set = ROOM_SESS.getOrDefault(room, Set.of());
    String msg = GSON.toJson(obj);
    for (Session ss : set) {
      if (ss.isOpen() && (except == null || ss != except)) {
        try { ss.getBasicRemote().sendText(msg); } catch (IOException ignored) {}
      }
    }
  }

  private static Long parseRoomId(String roomCode) {
    // hỗ trợ "ROOM-0007" hoặc số thuần "7"
    if (roomCode == null || roomCode.isBlank()) return null;
    String digits = roomCode.replaceAll("\\D+", ""); // lấy phần số
    if (digits.isEmpty()) return null;
    try { return Long.parseLong(digits); } catch (NumberFormatException e) { return null; }
  }

  private static boolean roomExists(long roomId) {
    try (Connection cn = Db.get();
         PreparedStatement st = cn.prepareStatement("SELECT 1 FROM rooms WHERE id=? LIMIT 1")) {
      st.setLong(1, roomId);
      try (ResultSet rs = st.executeQuery()) { return rs.next(); }
    } catch (SQLException e) {
      // không cứng fail; cho qua để không chặn dev flow
      return true;
    }
  }

  /* ---------- WebSocket lifecycle ---------- */

  @OnOpen
  public void onOpen(Session s) {
    s.setMaxIdleTimeout(300_000); // 5 phút
    CLIENTS.put(s, new ClientCtx());
  }

  @OnMessage
  public void onMessage(Session s, String raw) {
    JsonObject m = JsonParser.parseString(raw).getAsJsonObject();
    String t = m.has("t") ? m.get("t").getAsString() : "";

    switch (t) {
      case "join" -> {
        String roomCode = m.get("room").getAsString();
        String uid  = m.has("uid")  ? m.get("uid").getAsString()  : UUID.randomUUID().toString();
        String name = m.has("name") ? m.get("name").getAsString() : ("U-" + uid.substring(0, 6));
        Long userId = m.has("userId") ? m.get("userId").getAsLong() : null;
        String peerIp = m.has("peerIp") ? m.get("peerIp").getAsString() : "127.0.0.1";
        String peerPort = m.has("peerPort") ? m.get("peerPort").getAsString() : "9999";

        // Nếu có userId, ưu tiên lấy display_name từ DB để hiển thị đúng
        if (userId != null) {
          try (Connection cn = Db.get();
               PreparedStatement st = cn.prepareStatement("SELECT display_name FROM users WHERE id=? LIMIT 1")) {
            st.setLong(1, userId);
            try (ResultSet rs = st.executeQuery()) {
              if (rs.next()) {
                String dbName = rs.getString("display_name");
                if (dbName != null && !dbName.isBlank()) {
                  name = dbName;
                }
              }
            }
          } catch (SQLException e) {
            // bỏ qua lỗi để không chặn flow
          }
        }

        Long roomId = parseRoomId(roomCode);
        if (roomId == null || !roomExists(roomId)) {
          send(s, Map.of("t","error","code","ROOM_NOT_FOUND","room", roomCode));
          try { s.close(new CloseReason(CloseReason.CloseCodes.CANNOT_ACCEPT, "Room not found")); } catch (IOException ignored) {}
          return;
        }

        ClientCtx ctx = CLIENTS.get(s);
        ctx.uid = uid; ctx.name = name; ctx.room = roomCode; ctx.userId = userId; 
        ctx.peerIp = peerIp; ctx.peerPort = peerPort;

        UID_INDEX.put(uid, s);
        ROOM_SESS.computeIfAbsent(roomCode, k -> ConcurrentHashMap.newKeySet()).add(s);

        // Trả danh sách peers đang online (trừ mình) - bao gồm P2P info
        List<Map<String, Object>> peers = new ArrayList<>();
        for (Session ss : ROOM_SESS.get(roomCode)) {
          if (ss == s) continue;
          ClientCtx c = CLIENTS.get(ss);
          if (c != null) peers.add(Map.of(
            "uid", c.uid, 
            "name", c.name,
            "ip", c.peerIp,
            "port", c.peerPort
          ));
        }
        send(s, Map.of("t","peers","peers", peers));

        // Gửi lịch sử chat từ DB cho người mới (nếu có)
        Long rId = parseRoomId(roomCode);
        if (rId != null) {
          Long convId = getConversationId(rId);
          if (convId != null) {
            List<Map<String, Object>> history = loadChatHistory(convId);
            if (!history.isEmpty()) {
              send(s, Map.of("t","chat_history","messages", history));
            }
          }
        }

        // Thông báo mọi người có người mới (kèm P2P info)
        broadcast(roomCode, Map.of(
          "t","peer.joined",
          "uid", uid, 
          "name", name,
          "ip", peerIp,
          "port", peerPort
        ), s);
      }

      case "leave" -> {
        ClientCtx c = CLIENTS.get(s);
        if (c != null && c.room != null) {
          broadcast(c.room, Map.of("t","peer.left","uid", c.uid), s);
          ROOM_SESS.getOrDefault(c.room, Set.of()).remove(s);
          // Nếu phòng trống: không cần dọn lịch sử (đã ở DB)
        }
      }

      // Join request cho PROTECTED room
      case "join_request" -> {
        String roomCode = m.get("room").getAsString();
        String requestId = UUID.randomUUID().toString();
        ClientCtx requester = CLIENTS.get(s);
        if (requester == null) return;

        // Lưu request
        Map<String, String> req = Map.of(
          "requestId", requestId,
          "uid", requester.uid,
          "name", requester.name
        );
        PENDING_REQUESTS.computeIfAbsent(roomCode, k -> new CopyOnWriteArrayList<>()).add(req);

        // Tìm host (created_by)
        Long hostUserId = getHostUserId(roomCode);
        if (hostUserId != null) {
          // Tìm session của host trong room
          for (Session ss : ROOM_SESS.getOrDefault(roomCode, Set.of())) {
            ClientCtx c = CLIENTS.get(ss);
            if (c != null && hostUserId.equals(c.userId)) {
              send(ss, Map.of(
                "t", "join_request",
                "requestId", requestId,
                "uid", requester.uid,
                "name", requester.name,
                "room", roomCode
              ));
              break;
            }
          }
        }

        // Gửi confirm cho requester
        send(s, Map.of("t", "join_request_sent", "requestId", requestId));
      }

      case "join_approved" -> {
        String requestId = m.get("requestId").getAsString();
        String roomCode = m.get("room").getAsString();
        
        // Tìm requester
        List<Map<String, String>> pending = PENDING_REQUESTS.get(roomCode);
        if (pending != null) {
          for (Map<String, String> req : pending) {
            if (requestId.equals(req.get("requestId"))) {
              String uid = req.get("uid");
              Session requesterSess = UID_INDEX.get(uid);
              if (requesterSess != null) {
                send(requesterSess, Map.of("t", "join_approved", "room", roomCode));
              }
              pending.remove(req);
              break;
            }
          }
        }
      }

      case "join_rejected" -> {
        String requestId = m.get("requestId").getAsString();
        String roomCode = m.get("room").getAsString();
        
        List<Map<String, String>> pending = PENDING_REQUESTS.get(roomCode);
        if (pending != null) {
          for (Map<String, String> req : pending) {
            if (requestId.equals(req.get("requestId"))) {
              String uid = req.get("uid");
              Session requesterSess = UID_INDEX.get(uid);
              if (requesterSess != null) {
                send(requesterSess, Map.of("t", "join_rejected", "room", roomCode));
              }
              pending.remove(req);
              break;
            }
          }
        }
      }

      // Các event để dành bước sau (WebRTC)
      case "offer", "answer", "ice" -> {
        String to = m.get("to").getAsString();
        Session dst = UID_INDEX.get(to);
        if (dst != null && dst.isOpen()) send(dst, m);
      }

      // Kick a user by uid (host only in future, for now no auth check)
      case "kick" -> {
        String uid = m.get("uid").getAsString();
        String roomCode = m.get("room").getAsString();
        Session target = UID_INDEX.get(uid);
        if (target != null && target.isOpen()) {
          send(target, Map.of("t", "peer.kicked", "uid", uid));
          try { target.close(new CloseReason(CloseReason.CloseCodes.NORMAL_CLOSURE, "Kicked")); } catch (IOException ignored) {}
        }
        // broadcast to room that user was removed
        broadcast(roomCode, Map.of("t","peer.left","uid", uid), null);
      }

      case "chat" -> {
        // P2P mode: server KHÔNG relay chat
        // Chat đi trực tiếp peer-to-peer qua WebRTC DataChannel (web) hoặc TCP (mobile)
        debugPrint("⏭️ Skipping chat relay (pure P2P mode)");
      }

      case "chat.broadcast" -> {
        // P2P mode: server KHÔNG broadcast
        debugPrint("⏭️ Skipping chat broadcast (pure P2P mode)");
      }

      case "webrtc.offer" -> {
        // WebRTC P2P signaling: forward offer to specific peer
        String targetUid = m.has("targetUid") ? m.get("targetUid").getAsString() : null;
        String sdp = m.has("sdp") ? m.get("sdp").getAsString() : null;
        
        if (targetUid != null && sdp != null) {
          ClientCtx ctx = CLIENTS.get(s);
          Session targetSess = UID_INDEX.get(targetUid);
          
          if (targetSess != null && ctx != null) {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("t", "webrtc.offer");
            payload.put("fromUid", ctx.uid);
            payload.put("fromName", ctx.name);
            payload.put("sdp", sdp);
            send(targetSess, payload);
          }
        }
      }

      case "webrtc.answer" -> {
        // WebRTC P2P signaling: forward answer to specific peer
        String targetUid = m.has("targetUid") ? m.get("targetUid").getAsString() : null;
        String sdp = m.has("sdp") ? m.get("sdp").getAsString() : null;
        
        if (targetUid != null && sdp != null) {
          ClientCtx ctx = CLIENTS.get(s);
          Session targetSess = UID_INDEX.get(targetUid);
          
          if (targetSess != null && ctx != null) {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("t", "webrtc.answer");
            payload.put("fromUid", ctx.uid);
            payload.put("sdp", sdp);
            send(targetSess, payload);
          }
        }
      }

      case "webrtc.ice" -> {
        // WebRTC P2P signaling: forward ICE candidate to specific peer
        String targetUid = m.has("targetUid") ? m.get("targetUid").getAsString() : null;
        String candidate = m.has("candidate") ? m.get("candidate").getAsString() : null;
        String sdpMid = m.has("sdpMid") ? m.get("sdpMid").getAsString() : null;
        int sdpMLineIndex = m.has("sdpMLineIndex") ? m.get("sdpMLineIndex").getAsInt() : 0;
        
        if (targetUid != null && candidate != null) {
          ClientCtx ctx = CLIENTS.get(s);
          Session targetSess = UID_INDEX.get(targetUid);
          
          if (targetSess != null && ctx != null) {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("t", "webrtc.ice");
            payload.put("fromUid", ctx.uid);
            payload.put("candidate", candidate);
            payload.put("sdpMid", sdpMid);
            payload.put("sdpMLineIndex", sdpMLineIndex);
            send(targetSess, payload);
          }
        }
      }

      default -> { /* ignore */ }
    }
  }

  @OnClose
  public void onClose(Session s, CloseReason r) {
    ClientCtx c = CLIENTS.remove(s);
    if (c != null) {
      UID_INDEX.remove(c.uid);
      if (c.room != null) {
        ROOM_SESS.getOrDefault(c.room, Set.of()).remove(s);
        broadcast(c.room, Map.of("t","peer.left","uid", c.uid), s);
        // không cần xóa lịch sử (đã lưu DB)
      }
    }
  }

  @OnError
  public void onError(Session s, Throwable t) {
    // log nếu cần
  }

  private static Long getHostUserId(String roomCode) {
    Long roomId = parseRoomId(roomCode);
    if (roomId == null) return null;
    try (Connection cn = Db.get();
         PreparedStatement st = cn.prepareStatement("SELECT created_by FROM rooms WHERE id=? LIMIT 1")) {
      st.setLong(1, roomId);
      try (ResultSet rs = st.executeQuery()) {
        if (rs.next()) return rs.getLong("created_by");
      }
    } catch (SQLException e) {
      e.printStackTrace();
    }
    return null;
  }

  private static Long getConversationId(Long roomId) {
    if (roomId == null) return null;
    try (Connection cn = Db.get();
         PreparedStatement st = cn.prepareStatement("SELECT conversation_id FROM rooms WHERE id=? LIMIT 1")) {
      st.setLong(1, roomId);
      try (ResultSet rs = st.executeQuery()) {
        if (rs.next()) return rs.getLong("conversation_id");
      }
    } catch (SQLException e) {
      e.printStackTrace();
    }
    return null;
  }

  private static List<Map<String, Object>> loadChatHistory(Long conversationId) {
    List<Map<String, Object>> out = new ArrayList<>();
    if (conversationId == null) return out;
    String sql = "SELECT m.id, m.sender_id, u.display_name, m.content, m.created_at " +
                 "FROM messages m JOIN users u ON u.id = m.sender_id " +
                 "WHERE m.conversation_id = ? ORDER BY m.created_at ASC LIMIT 200";
    try (Connection cn = Db.get();
         PreparedStatement st = cn.prepareStatement(sql)) {
      st.setLong(1, conversationId);
      try (ResultSet rs = st.executeQuery()) {
        while (rs.next()) {
          long mid = rs.getLong("id");
          long senderId = rs.getLong("sender_id");
          String name = rs.getString("display_name");
          String content = rs.getString("content");
          Timestamp created = rs.getTimestamp("created_at");
          String ts = created != null ? created.toInstant().toString() : Instant.now().toString();
          out.add(Map.of(
            "messageId", mid,
            "fromUserId", (int) senderId,
            "fromName", name != null ? name : ("U-" + senderId),
            "text", content != null ? content : "",
            "ts", ts
          ));
        }
      }
    } catch (SQLException e) {
      e.printStackTrace();
    }
    return out;
  }
}
