package com.study;

import org.glassfish.jersey.grizzly2.httpserver.GrizzlyHttpServerFactory;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.jackson.JacksonFeature;
import java.net.URI;
import org.glassfish.tyrus.server.Server; // giờ sẽ nhận ra class

public class Main {

    public static void main(String[] args) throws Exception {
        final ResourceConfig rc = new ResourceConfig()
                .packages("com.study")
                .register(JacksonFeature.class) // JSON
                .register(CORSFilter.class) // CORS
                .register(AuthController.class) // Auth
                .register(RoomsController.class) // Room
                .register(CallController.class) // Call
                .register(com.study.friends.FriendsController.class) // Friends
                .register(com.study.friends.FriendRequestsController.class) // Friend Requests
                .register(com.study.friends.BlockedUsersController.class) // Blocked Users
                .register(com.study.friends.FindFriendsController.class) // Find Friends
                .register(com.study.tasks.TasksController.class) // Tasks
                .register(com.study.chat.ChatPeerController.class) // Chat Peer Registry
        ;

        GrizzlyHttpServerFactory.createHttpServer(URI.create("http://0.0.0.0:8080/"), rc, true);
        Server ws = new Server("0.0.0.0", 8081, "/", null, SignalingEndpoint.class);
        ws.start();

        // Chat relay WS on 8082
        Server chatRelay = new Server("0.0.0.0", 8082, "/", null,
                com.study.chat.ChatRelayEndpoint.class,
                com.study.chat.OnlineListEndpoint.class);
        chatRelay.start();
        System.out.println("REST: http://127.0.0.1:8080");
        System.out.println("WS  : ws://127.0.0.1:8081/ws");
        System.out.println("Chat Relay: ws://127.0.0.1:8082/chat-relay/{userId}");

        Thread.currentThread().join();
    }

}
