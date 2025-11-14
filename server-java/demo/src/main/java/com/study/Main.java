package com.study;

import org.glassfish.grizzly.http.server.HttpServer;
import org.glassfish.jersey.grizzly2.httpserver.GrizzlyHttpServerFactory;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.jackson.JacksonFeature;
import java.io.IOException;
import java.net.URI;

public class Main {
    public static final String BASE_URI = "http://0.0.0.0:8080/";

    public static void main(String[] args) throws IOException {
        final ResourceConfig rc = new ResourceConfig()
                .packages("com.study")
                .register(JacksonFeature.class) // JSON
                .register(CORSFilter.class)    // CORS
                .register(Db.class)         // Database
                .register(AuthController.class) // Auth
                .register(RoomsController.class)// Rooms
                ;


        HttpServer server = GrizzlyHttpServerFactory.createHttpServer(URI.create(BASE_URI), rc);
        System.out.println("Server chạy tại: " + BASE_URI);
        System.in.read();
        server.shutdownNow();
    }
}
