package com.study.chat;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class PeerRegistry {
    private static final PeerRegistry INSTANCE = new PeerRegistry();
    private final Map<Long, PeerInfo> peers = new ConcurrentHashMap<>();
    private static final long EXPIRY_MS = 60_000; // 60s

    public static PeerRegistry get() { return INSTANCE; }

    public void register(long userId, String ip, int port) {
        peers.put(userId, new PeerInfo(userId, ip, port));
    }

    public void heartbeat(long userId) {
        PeerInfo p = peers.get(userId);
        if (p != null) {
            p.lastSeen = System.currentTimeMillis();
        }
    }

    public PeerInfo getPeer(long userId) {
        PeerInfo p = peers.get(userId);
        if (p == null) return null;
        if (System.currentTimeMillis() - p.lastSeen > EXPIRY_MS) {
            peers.remove(userId);
            return null;
        }
        return p;
    }
}
