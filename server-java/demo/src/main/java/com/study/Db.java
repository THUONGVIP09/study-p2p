package com.study;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public final class Db {
  // Default trong code, có thể override bằng System properties hoặc ENV
  // Ưu tiên: -DDB_URL/-DDB_USER/-DDB_PASS → ENV DB_URL/DB_USER/DB_PASS → default
  private static final String URL = System.getProperty("DB_URL",
      System.getenv().getOrDefault("DB_URL",
          "jdbc:mysql://127.0.0.1:3306/study_p2p?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"));
  private static final String USER = System.getProperty("DB_USER",
      System.getenv().getOrDefault("DB_USER", "root"));
  private static final String PASS = System.getProperty("DB_PASS",
      System.getenv().getOrDefault("DB_PASS", "thuongle0910"));

  private Db() {
  }

  static {
    // Load driver 1 lần (an toàn cho môi trường cũ)
    try {
      Class.forName("com.mysql.cj.jdbc.Driver");
    } catch (ClassNotFoundException e) {
      throw new RuntimeException("Thiếu MySQL JDBC driver (com.mysql.cj.jdbc.Driver)", e);
    }
  }

  /** Lấy connection mới. Nhớ dùng try-with-resources ở nơi gọi. */
  public static Connection get() throws SQLException {
    return DriverManager.getConnection(URL, USER, PASS);
  }

  /** Ping nhanh để test DB up chưa (optional). */
  public static boolean ping() {
    try (Connection c = get()) {
      return c.isValid(2);
    } catch (SQLException e) {
      return false;
    }
  }

  /** Đóng yên lặng, khỏi try/catch ở caller. */
  public static void closeQuietly(AutoCloseable c) {
    if (c != null)
      try {
        c.close();
      } catch (Exception ignore) {
      }
  }

}
