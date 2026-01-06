package com.study.chat;

import jakarta.websocket.OnClose;
import jakarta.websocket.OnError;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;

import java.io.IOException;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;

@ServerEndpoint(value = "/chat-online-list")
public class OnlineListEndpoint {
    private static final Set<Session> sessions = new CopyOnWriteArraySet<>();
    private static final ObjectMapper mapper = new ObjectMapper();

    @OnOpen
    public void onOpen(Session session) {
        sessions.add(session);
        System.out.println("✅ Client subscribed to online list (total: " + sessions.size() + ")");
        // Send current list immediately to new subscriber
        sendListToSession(session);
    }

    @OnClose
    public void onClose(Session session) {
        sessions.remove(session);
        System.out.println("🔌 Client unsubscribed from online list (remaining: " + sessions.size() + ")");
    }

    @OnError
    public void onError(Session session, Throwable error) {
        System.err.println("❌ WebSocket error: " + error.getMessage());
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        // Handle ping/refresh request from client
        System.out.println("📨 Online list message: " + message);
        // Any message triggers a refresh for that client
        sendListToSession(session);
    }

    private static void sendListToSession(Session session) {
        try {
            if (session.isOpen()) {
                String json = buildOnlineListJson();
                session.getBasicRemote().sendText(json);
            }
        } catch (IOException e) {
            System.err.println("Error sending list to session: " + e.getMessage());
        }
    }

    private static String buildOnlineListJson() {
        try {
            // Get all online peers from registry
            Map<Long, PeerInfo> peers = PeerRegistry.get().getAllPeers();

            // Build JSON array: [{"userId":1,"ip":"127.0.0.1","port":9001}]
            List<Map<String, Object>> peerList = new ArrayList<>();
            for (PeerInfo peer : peers.values()) {
                Map<String, Object> p = new HashMap<>();
                p.put("userId", peer.userId);
                p.put("ip", peer.ip);
                p.put("port", peer.port);
                p.put("lastSeen", peer.lastSeen);
                peerList.add(p);
            }

            Map<String, Object> result = new HashMap<>();
            result.put("type", "ONLINE_LIST");
            result.put("peers", peerList);

            return mapper.writeValueAsString(result);
        } catch (Exception e) {
            System.err.println("Error building JSON: " + e.getMessage());
            return "{\"type\":\"ONLINE_LIST\",\"peers\":[]}";
        }
    }

    /**
     * Broadcast online peers list to all subscribed clients
     * Called by ChatPeerController when register/heartbeat/logout
     */
    public static void broadcastList() {
        try {
            String json = buildOnlineListJson();
            for (Session session : sessions) {
                if (session.isOpen()) {
                    session.getBasicRemote().sendText(json);
                }
            }
            System.out.println("📡 Broadcast online list to " + sessions.size() + " clients");
        } catch (IOException e) {
            System.err.println("Error broadcasting list: " + e.getMessage());
        }
    }
}
