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
    }

    @OnClose
    public void onClose(Session session, @PathParam("userId") long userId) {
        sessions.remove(userId);
    }

    @OnMessage
    public void onMessage(String message, Session session, @PathParam("userId") long userId) throws IOException {
        // expect simple JSON: {"to":123, "content":"hi"}
        // naive parse to avoid dependencies
        Long toId = extractLong(message, "to");
        if (toId == null) return;
        Session target = sessions.get(toId);
        if (target != null && target.isOpen()) {
            target.getBasicRemote().sendText(message);
        }
    }

    private Long extractLong(String json, String key) {
        try {
            int i = json.indexOf('"' + key + '"');
            if (i < 0) return null;
            int colon = json.indexOf(':', i);
            int comma = json.indexOf(',', colon);
            int end = comma > 0 ? comma : json.indexOf('}', colon);
            String num = json.substring(colon + 1, end).trim();
            return Long.parseLong(num);
        } catch (Exception e) { return null; }
    }
}
