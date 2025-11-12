package com.study;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import org.mindrot.jbcrypt.BCrypt;

// DTO trả về JSON
record ResponseMessage(boolean success, String message) {}
record LoginResponse(boolean success, String token, UserInfo user) {}
record UserInfo(long id, String name) {}

@Path("/api/auth")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AuthController {

    private static final String DB_URL = "jdbc:mysql://localhost:3306/study_p2p";
    private static final String DB_USER = "root";
    private static final String DB_PASS = "thuongle0910"; // đổi theo MySQL
    

    // --- REGISTER ---
    @POST
    @Path("/register")
    public Response register(UserRegister user) {
        if(user.email == null || user.password == null || user.displayName == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ResponseMessage(false, "Missing fields")).build();
        }

        String sql = "INSERT INTO users (email, password_hash, display_name) VALUES (?, ?, ?)";
        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             PreparedStatement ps = conn.prepareStatement(sql)) {

            String hashed = BCrypt.hashpw(user.password, BCrypt.gensalt());
            ps.setString(1, user.email);
            ps.setString(2, hashed);
            ps.setString(3, user.displayName);
            ps.executeUpdate();

            return Response.status(201)
                    .entity(new ResponseMessage(true, "Đăng ký thành công")).build();
        } catch (SQLException e) {
            return Response.status(400)
                    .entity(new ResponseMessage(false, "Email đã tồn tại")).build();
        }
    }

    // --- LOGIN ---
   private static String normBCrypt(String h) {
    if (h == null) return null;
    // Cho phép $2y$/$2b$ chạy qua jBCrypt bằng cách map về $2a$
    return h.replaceFirst("^\\$2y\\$", "\\$2a\\$")
            .replaceFirst("^\\$2b\\$", "\\$2a\\$");
}

@POST @Path("/login")
public Response login(LoginRequest in) {
  if (in == null || in.email() == null || in.password() == null) {
    return Response.status(Response.Status.BAD_REQUEST)
      .entity(new ResponseMessage(false, "Thiếu email/password")).build();
  }
  try (Connection cn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS.trim());
       PreparedStatement ps = cn.prepareStatement(
         "SELECT id,display_name,password_hash FROM users WHERE email=? LIMIT 1")) {
    ps.setString(1, in.email());
    try (ResultSet rs = ps.executeQuery()) {
      if (!rs.next()) {
        return Response.status(Response.Status.UNAUTHORIZED)
          .entity(new ResponseMessage(false, "Email hoặc mật khẩu không đúng")).build();
      }
      String hash = rs.getString("password_hash");
      if (hash != null && hash.startsWith("$2y$")) {
        hash = hash.replaceFirst("^\\$2y\\$", "\\$2a\\$");
      }
      boolean ok;
      try {
        ok = BCrypt.checkpw(in.password(), hash);
      } catch (IllegalArgumentException e) {
        return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
          .entity(new ResponseMessage(false, "Hash bcrypt không hợp lệ")).build();
      }
      if (!ok) {
        return Response.status(Response.Status.UNAUTHORIZED)
          .entity(new ResponseMessage(false, "Email hoặc mật khẩu không đúng")).build();
      }
      String token = java.util.UUID.randomUUID().toString(); // TODO: JWT thật
      return Response.ok(new LoginResponse(true, token,
              new UserInfo(rs.getLong("id"), rs.getString("display_name")))).build();
    }
  } catch (SQLException e) {
    e.printStackTrace(); // log
    return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
      .entity(new ResponseMessage(false, "DB lỗi: " + e.getMessage())).build();
  }
}



    // --- DTO ---
    public static class UserRegister {
        public String email;
        public String password;
        public String displayName;
    }

    public static class UserLogin {
        public String email;
        public String password;
    }

    // Request record used by login endpoint (provides in.email() and in.password())
    public static record LoginRequest(String email, String password) {}
}
