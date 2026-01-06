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

@ServerEndpoint(value = "/chat-relay/{userId}")
public class ChatRelayEndpoint {
    private static final Map<Long, Session> sessions = new ConcurrentHashMap<>();

    @OnOpen
    public void onOpen(Session session, @PathParam("userId") long userId) {
        sessions.put(userId, session);
        System.out.println("✅ [Relay] User " + userId + " connected to relay");

        // Register user as online in PeerRegistry (use "relay" as IP to indicate web
        // user)
        PeerRegistry.get().register(userId, "relay", 0);

        // Broadcast updated online list
        OnlineListEndpoint.broadcastList();
    }

    @OnClose
    public void onClose(Session session, @PathParam("userId") long userId) {
        sessions.remove(userId);
        System.out.println("🔌 [Relay] User " + userId + " disconnected from relay");

        // Unregister user from PeerRegistry
        PeerRegistry.get().unregister(userId);

        // Broadcast updated online list
        OnlineListEndpoint.broadcastList();
    }

    @OnMessage
    public void onMessage(String message, Session session, @PathParam("userId") long userId) throws IOException {
        // expect simple JSON: {"to":123, "content":"hi"}
        // naive parse to avoid dependencies
        Long toId = extractLong(message, "to");
        if (toId == null)
            return;

        System.out.println("📨 [Relay] Message from " + userId + " to " + toId);

        Session target = sessions.get(toId);
        if (target != null && target.isOpen()) {
            target.getBasicRemote().sendText(message);
        }

        // Heartbeat to keep user online
        PeerRegistry.get().heartbeat(userId);
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
