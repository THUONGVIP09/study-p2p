package com.study.chat;

import jakarta.websocket.OnClose;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.PathParam;
import jakarta.websocket.server.ServerEndpoint;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@ServerEndpoint(value = "/chat-relay/{userId}")
public class ChatRelayEndpoint {
    private static final Map<Long, Session> sessions = new ConcurrentHashMap<>();

    // ✅ Heartbeat để keep WebSocket alive
    private static final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    private static boolean heartbeatStarted = false;

    static {
        startHeartbeat();
    }

    private static synchronized void startHeartbeat() {
        if (heartbeatStarted)
            return;
        heartbeatStarted = true;

        // Gửi ping (text message với "type":"ping") mỗi 30 giây
        scheduler.scheduleAtFixedRate(() -> {
            for (Session session : sessions.values()) {
                if (session.isOpen()) {
                    try {
                        session.getBasicRemote().sendText("{\"type\":\"ping\"}");
                    } catch (IOException e) {
                        // Ignore
                    }
                }
            }
            System.out.println("💓 Relay heartbeat sent to " + sessions.size() + " clients");
        }, 30, 30, TimeUnit.SECONDS); // Heartbeat mỗi 30 giây

        System.out.println("✅ Relay heartbeat started (every 30s)");
    }

    @OnOpen
    public void onOpen(Session session, @PathParam("userId") long userId) {
        sessions.put(userId, session);
        System.out.println("✅ Relay connected: user " + userId + ". Total: " + sessions.size());
    }

    @OnClose
    public void onClose(Session session, @PathParam("userId") long userId) {
        sessions.remove(userId);
        System.out.println("🔌 Relay disconnected: user " + userId + ". Remaining: " + sessions.size());
    }

    @OnMessage
    public void onMessage(String message, Session session, @PathParam("userId") long userId) throws IOException {
        // Skip ping messages
        if (message.contains("\"type\":\"ping\"")) {
            return; // App gửi ping, server không cần relay nó
        }

        // expect simple JSON: {"to":123, "content":"hi"}
        // naive parse to avoid dependencies
        Long toId = extractLong(message, "to");
        if (toId == null)
            return;
        Session target = sessions.get(toId);
        if (target != null && target.isOpen()) {
            try {
                target.getBasicRemote().sendText(message);
                System.out.println("📤 Relay message from user " + userId + " to user " + toId);
            } catch (IOException e) {
                System.err.println("Error relaying message: " + e.getMessage());
            }
        } else {
            System.out.println("⚠️ Target user " + toId + " not online for relay");
        }
    }

    private Long extractLong(String json, String key) {
        try {
            int i = json.indexOf('"' + key + '"');
            if (i < 0)
                return null;
            int colon = json.indexOf(':', i);
            int comma = json.indexOf(',', colon);
            int end = comma > 0 ? comma : json.indexOf('}', colon);
            String num = json.substring(colon + 1, end).trim();
            return Long.parseLong(num);
        } catch (Exception e) {
            return null;
        }
    }
}
