package com.study.chat;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.HashMap;
import java.util.Map;

@Path("/api/chat")
@Produces(MediaType.APPLICATION_JSON)
public class ChatPeerController {

    @POST
    @Path("/register")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response register(Map<String, Object> body) {
        try {
            long userId = Long.parseLong(body.get("userId").toString());
            String ip = body.get("ip").toString();
            int port = Integer.parseInt(body.get("port").toString());
            PeerRegistry.get().register(userId, ip, port);
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            return Response.ok(resp).build();
        } catch (Exception e) {
            return Response.status(400).entity(Map.of("error", e.getMessage())).build();
        }
    }

    @POST
    @Path("/heartbeat")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response heartbeat(Map<String, Object> body) {
        try {
            long userId = Long.parseLong(body.get("userId").toString());
            PeerRegistry.get().heartbeat(userId);
            return Response.ok(Map.of("success", true)).build();
        } catch (Exception e) {
            return Response.status(400).entity(Map.of("error", e.getMessage())).build();
        }
    }

    @GET
    @Path("/peer/{friendId}")
    public Response getPeer(@PathParam("friendId") long friendId) {
        PeerInfo p = PeerRegistry.get().getPeer(friendId);
        Map<String, Object> resp = new HashMap<>();
        if (p == null) {
            resp.put("online", false);
        } else {
            resp.put("online", true);
            resp.put("ip", p.ip);
            resp.put("port", p.port);
        }
        return Response.ok(resp).build();
    }
}
