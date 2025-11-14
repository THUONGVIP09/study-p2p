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

  static final class ClientCtx {
    String uid;
    String name;
    String room;     // roomCode dạng ROOM-0001
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

        Long roomId = parseRoomId(roomCode);
        if (roomId == null || !roomExists(roomId)) {
          send(s, Map.of("t","error","code","ROOM_NOT_FOUND","room", roomCode));
          try { s.close(new CloseReason(CloseReason.CloseCodes.CANNOT_ACCEPT, "Room not found")); } catch (IOException ignored) {}
          return;
        }

        ClientCtx ctx = CLIENTS.get(s);
        ctx.uid = uid; ctx.name = name; ctx.room = roomCode;

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

        // Thông báo mọi người có người mới
        broadcast(roomCode, Map.of("t","peer.joined","uid", uid, "name", name), s);
      }

      case "leave" -> {
        ClientCtx c = CLIENTS.get(s);
        if (c != null && c.room != null) {
          broadcast(c.room, Map.of("t","peer.left","uid", c.uid), s);
          ROOM_SESS.getOrDefault(c.room, Set.of()).remove(s);
        }
      }

      // Các event để dành bước sau (WebRTC)
      case "offer", "answer", "ice" -> {
        String to = m.get("to").getAsString();
        Session dst = UID_INDEX.get(to);
        if (dst != null && dst.isOpen()) send(dst, m);
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
      }
    }
  }

  @OnError
  public void onError(Session s, Throwable t) {
    // log nếu cần
  }
}
