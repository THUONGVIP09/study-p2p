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
    Instant at = Instant.now();
  }

  /* ---------- Helpers ---------- */

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

        UID_INDEX.put(uid, s);
        ROOM_SESS.computeIfAbsent(roomCode, k -> ConcurrentHashMap.newKeySet()).add(s);

        // Trả danh sách peers đang online (trừ mình)
        List<Map<String, Object>> peers = new ArrayList<>();
        for (Session ss : ROOM_SESS.get(roomCode)) {
          if (ss == s) continue;
          ClientCtx c = CLIENTS.get(ss);
          if (c != null) peers.add(Map.of("uid", c.uid, "name", c.name));
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

        // Thông báo mọi người có người mới
        broadcast(roomCode, Map.of("t","peer.joined","uid", uid, "name", name), s);
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
        ClientCtx ctx = CLIENTS.get(s);
        if (ctx != null && ctx.room != null) {
          Integer fromUserId = m.has("fromUserId") ? m.get("fromUserId").getAsInt() : null;
          String fromName = m.has("fromName") ? m.get("fromName").getAsString() : ctx.name;
          String text = m.has("text") ? m.get("text").getAsString() : "";
          // Thời điểm server
          Instant now = Instant.now();
          String ts = now.toString();

          Long roomId = parseRoomId(ctx.room);
          Long convId = (roomId != null) ? getConversationId(roomId) : null;
          Long senderId = (fromUserId != null) ? fromUserId.longValue() : ctx.userId;

          Long messageId = null;
          if (convId != null && senderId != null && text != null && !text.isBlank()) {
            try (Connection cn = Db.get();
                 PreparedStatement st = cn.prepareStatement(
                   "INSERT INTO messages(conversation_id, sender_id, msg_type, content, metadata, created_at) VALUES(?,?,?,?,?,NOW())",
                   Statement.RETURN_GENERATED_KEYS)) {
              st.setLong(1, convId);
              st.setLong(2, senderId);
              st.setString(3, "TEXT");
              st.setString(4, text);
              st.setNull(5, Types.VARCHAR); // metadata NULL
              st.executeUpdate();
              try (ResultSet rs = st.getGeneratedKeys()) {
                if (rs.next()) messageId = rs.getLong(1);
              }
            } catch (SQLException e) {
              e.printStackTrace();
            }
          }

          Map<String, Object> payload = new LinkedHashMap<>();
          payload.put("t", "chat");
          payload.put("fromUserId", senderId != null ? senderId.intValue() : 0);
          payload.put("fromName", fromName);
          payload.put("text", text);
          payload.put("ts", ts);
          if (messageId != null) payload.put("messageId", messageId);
          broadcast(ctx.room, payload, null);
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
