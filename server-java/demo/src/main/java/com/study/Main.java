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
                // Room messages, friends and chat endpoints removed
                .register(com.study.tasks.TasksController.class);

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

        System.out.println("REST        : http://0.0.0.0:8080");
        System.out.println("Signaling WS: ws://0.0.0.0:8081/ws");

        // Để server sống tới khi process bị kill
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                signalingWs.stop();
            } catch (Exception ignored) {
            }
        }));

        Thread.currentThread().join();
    }
}
