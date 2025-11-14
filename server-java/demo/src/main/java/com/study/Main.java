package com.study;

import org.glassfish.grizzly.http.server.HttpServer;
import org.glassfish.jersey.grizzly2.httpserver.GrizzlyHttpServerFactory;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.jackson.JacksonFeature;
import java.io.IOException;
import java.net.URI;
import org.glassfish.tyrus.server.Server;

public class Main {
   
    public static void main(String[] args) throws IOException {
        final ResourceConfig rc = new ResourceConfig()
                .packages("com.study")
                .register(JacksonFeature.class) // JSON
                .register(CORSFilter.class)    // CORS
                .register(Db.class)         // Database
                .register(AuthController.class) // Auth
                .register(RoomsController.class)// Rooms
                ;


        HttpServer server = GrizzlyHttpServerFactory.createHttpServer(URI.create("http://0.0.0.0:8080/"), rc,true);
        Server ws=new Server("")
        System.out.println("Server chạy tại: " + "http://0.0.0.0:8080/");
        System.in.read();
        server.shutdownNow();
    }
}
