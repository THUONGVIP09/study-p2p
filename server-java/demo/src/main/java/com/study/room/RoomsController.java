package com.study.room;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.*;
import java.sql.*;
import java.util.*;
import com.google.gson.Gson;
import com.study.Db;

@Path("/api/rooms")
@Produces(MediaType.APPLICATION_JSON)
public class RoomsController {

     // giống AuthController
    private static final Gson GSON = new Gson();

    record Room(long id, String room_code, String title, String description,
                String visibility, boolean is_group) {}

    @GET
    public Response list(@QueryParam("q") @DefaultValue("") String q,
                         @QueryParam("limit") @DefaultValue("50") int limit,
                         @QueryParam("offset") @DefaultValue("0") int offset) {
        String base = """
  SELECT 
      id,
      CONCAT('ROOM-', LPAD(id, 4, '0')) AS room_code,   -- tạo code từ id
      name AS title,                                    -- alias name -> title
      COALESCE(description,'') AS description,
      LOWER(COALESCE(visibility,'public')) AS visibility,
      CASE WHEN COALESCE(max_participants,0) > 2 THEN 1 ELSE 0 END AS is_group
  FROM rooms
  """;

// search theo name
String where = q.isBlank() ? "" : " WHERE name LIKE ? ";
String tail  = " ORDER BY created_at DESC LIMIT ? OFFSET ?";

        List<Room> rooms = new ArrayList<>();

        try (Connection cn = Db.get();
             PreparedStatement st = cn.prepareStatement(base + where + tail)) {

      int idx = 1;
if (!q.isBlank()) {
  String like = "%" + q + "%";
  st.setString(idx++, like);
}
st.setInt(idx++, limit);
st.setInt(idx,   offset);


            try (ResultSet rs = st.executeQuery()) {
                while (rs.next()) {
                    rooms.add(new Room(
                        rs.getLong("id"),
                        rs.getString("room_code"),
                        rs.getString("title"),
                        rs.getString("description"),
                        rs.getString("visibility"),
                        rs.getBoolean("is_group")
                    ));
                }
            }
        } catch (SQLException e) {
            // trả lỗi JSON gọn
            return Response.status(500)
                .entity(GSON.toJson(Map.of("success", false, "error", e.getMessage())))
                .build();
        }

        return Response.ok(GSON.toJson(Map.of(
            "success", true,
            "data", rooms,
            "count", rooms.size()
        ))).build();
    }
}
