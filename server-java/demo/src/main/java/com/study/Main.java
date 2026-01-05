package com.study;

import org.glassfish.jersey.grizzly2.httpserver.GrizzlyHttpServerFactory;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.jackson.JacksonFeature;

import java.net.URI;

import org.glassfish.tyrus.server.Server; // WebSocket (Tyrus)

public class Main {

    public static void main(String[] args) throws Exception {
        // ================= REST (HTTP 8080) =================
        final ResourceConfig rc = new ResourceConfig()
                .packages("com.study")
                .register(JacksonFeature.class) // JSON
                .register(CORSFilter.class) // CORS
                .register(AuthController.class) // Auth
                .register(RoomsController.class) // Rooms
                .register(CallController.class) // Calls
                .register(com.study.friends.FriendsController.class)
                .register(com.study.friends.FriendRequestsController.class)
                .register(com.study.friends.BlockedUsersController.class)
                .register(com.study.friends.FindFriendsController.class)
                .register(com.study.tasks.TasksController.class)
                .register(com.study.chat.ChatPeerController.class);

        GrizzlyHttpServerFactory.createHttpServer(
                URI.create("http://0.0.0.0:8080/"), rc, true);

        // ================= WebRTC signaling WS (8081/ws) =================
        Server signalingWs = new Server(
                "0.0.0.0",
                8081,
                "/",
                null,
                SignalingEndpoint.class // /ws
        );
        signalingWs.start();

        // ================= Chat relay WS (8082/...) =================
        Server chatRelay = new Server(
                "0.0.0.0",
                8082,
                "/",
                null,
                com.study.chat.ChatRelayEndpoint.class,
                com.study.chat.OnlineListEndpoint.class);
        chatRelay.start();

        System.out.println("REST        : http://0.0.0.0:8080");
        System.out.println("Signaling WS: ws://0.0.0.0:8081/ws");
        System.out.println("Chat Relay  : ws://0.0.0.0:8082/chat-relay/{userId}");

        // Để server sống tới khi process bị kill
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                signalingWs.stop();
                chatRelay.stop();
            } catch (Exception ignored) {
            }
        }));

        Thread.currentThread().join();
    }
}
