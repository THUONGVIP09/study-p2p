package com.study;

import org.glassfish.grizzly.http.server.HttpServer;
import org.glassfish.jersey.grizzly2.httpserver.GrizzlyHttpServerFactory;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.jackson.JacksonFeature;
import java.io.IOException;
import java.net.URI;
import org.glassfish.tyrus.server.Server; // giờ sẽ nhận ra class

public class Main {

    public static void main(String[] args) throws Exception {
        final ResourceConfig rc = new ResourceConfig()
            .packages("com.study", "com.study.friends")
                .register(JacksonFeature.class) // JSON
                .register(CORSFilter.class) // CORS
                .register(Db.class) // Database
                .register(AuthController.class) // Auth
                .register(RoomsController.class) // Room
                .register(CallController.class) // Call
        ;

        HttpServer server = GrizzlyHttpServerFactory.createHttpServer(URI.create("http://0.0.0.0:8080/"), rc, true);
        Server ws = new Server("0.0.0.0", 8081, "/", null, SignalingEndpoint.class);
        ws.start();
        System.out.println("REST: http://127.0.0.1:8080");
        System.out.println("WS  : ws://127.0.0.1:8081/ws");

        Thread.currentThread().join();
    }

}
