package com.study.chat;

import jakarta.ws.rs.core.Response;

// Chat summary feature đã bị gỡ bỏ; stub controller giữ chỗ để tránh đăng ký nhầm đường dẫn cũ.
public class ChatFeatureRemovedController {

    public Response featureRemoved() {
        return Response.status(Response.Status.GONE)
                .entity("Chat summary feature has been removed")
                .build();
    }
}
