package com.study.chat;

public class PeerInfo {
    public long userId;
    public String ip;
    public int port;
    public long lastSeen;

    public PeerInfo() {}

    public PeerInfo(long userId, String ip, int port) {
        this.userId = userId;
        this.ip = ip;
        this.port = port;
        this.lastSeen = System.currentTimeMillis();
    }
}
