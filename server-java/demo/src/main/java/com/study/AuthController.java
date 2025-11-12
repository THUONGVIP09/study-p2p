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
    private static final String DB_PASS = "password"; // đổi theo MySQL

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
    @POST
    @Path("/login")
    public Response login(UserLogin user) {
        if(user.email == null || user.password == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ResponseMessage(false, "Missing fields")).build();
        }

        String sql = "SELECT id, password_hash, display_name FROM users WHERE email = ?";
        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setString(1, user.email);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                String hash = rs.getString("password_hash");
                if (BCrypt.checkpw(user.password, hash)) {
                    long id = rs.getLong("id");
                    String token = "jwt_fake_" + id; // token giả
                    UserInfo userInfo = new UserInfo(id, rs.getString("display_name"));
                    return Response.ok(new LoginResponse(true, token, userInfo)).build();
                }
            }

            return Response.status(401)
                    .entity(new ResponseMessage(false, "Sai email hoặc mật khẩu")).build();
        } catch (SQLException e) {
            return Response.status(500)
                    .entity(new ResponseMessage(false, "Lỗi server")).build();
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
}
