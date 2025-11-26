package server;
import java.io.*;
import java.net.*;
import java.util.*;

public class Server {

    private static final int PORT = 12345;
    private static Map<String, ClientInfo> clients = new HashMap<>();

    public static void main(String[] args) {
        try (ServerSocket serverSocket = new ServerSocket(PORT)) {
            System.out.println("Server is listening on port " + PORT);
            while (true) {
                Socket socket = serverSocket.accept();
                System.out.println("New client connected");
                // Handle client connection in a new thread
                new Thread(new ClientHandler(socket)).start();
            }
        } catch (IOException e) {
            System.out.println("Error in server: " + e.getMessage());
        }
    }

    static class ClientInfo {
        String username;
        Socket socket;
        int port;
        boolean active;


        ClientInfo(String username, Socket socket, int port) {
            this.username = username;
            this.socket = socket;
            this.port = port;
            this.active = true;
        }
    }

    static class ClientHandler extends Thread {
        private Socket socket;

        public ClientHandler(Socket socket) {
            this.socket = socket;
        }

        public void run() {
            String username = null;
            int port = -1;
            try (BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                 PrintWriter out = new PrintWriter(socket.getOutputStream(), true)) {

                username = in.readLine();
                port = Integer.parseInt(in.readLine());

                synchronized (clients) {
                    if (clients.containsKey(username)) {
                        out.println("USERNAME_TAKEN");
                        socket.close();
                        return;
                    }
                    clients.put(username, new ClientInfo(username, socket, port));
                }

                System.out.println("User " + username + " connected on port " + port);
                out.println("OK");

                broadcastClientList();

                String line;
                while ((line = in.readLine()) != null) {
                    if (line.equalsIgnoreCase("LOGOUT")) {
                        synchronized (clients) {
                            ClientInfo info=clients.get(username);
                            if(info!=null) info.active=false;
                        }
                        break;
                    } else if (line.startsWith("MSG")) {
                        String message = line.substring(4);
                        System.out.println("Message from " + username + ": " + message);
                        // Optional: broadcast to all clients if needed
                    } else if (line.startsWith("GETPORT")) {
                        String targetUser = line.substring(8).trim();
                        ClientInfo targetClient = clients.get(targetUser);
                        if (targetClient != null) {
                            out.println("PORT " + targetClient.port);
                        } else {
                            out.println("PORT -1");
                        }
                    }
                }

            } catch (IOException e) {
                System.out.println("Error handling client: " + e.getMessage());
            } finally {
                if (username != null) {
                    synchronized (clients) {
                        clients.remove(username);
                    }
                    broadcastClientList();
                    System.out.println("User " + username + " disconnected.");
                }
                try {
                    socket.close();
                } catch (IOException e) {
                    System.out.println("Error closing socket: " + e.getMessage());
                }
            }
        }

       private void broadcastClientList() {
    StringBuilder clientList = new StringBuilder();
    synchronized (clients) {
        for (ClientInfo client : clients.values()) {
            clientList.append(client.username)
                      .append(":")
                      .append(client.port)
                      .append(":")
                      .append(client.active? "active":"inactive")
                      .append(","); // dùng ',' làm separator
        }
    }
    // Xóa dấu ',' cuối
    if (clientList.length() > 0) clientList.setLength(clientList.length() - 1);
    String clientListStr = clientList.toString();

    for (ClientInfo client : clients.values()) {
        try {
            PrintWriter clientOut = new PrintWriter(client.socket.getOutputStream(), true);
            clientOut.println("CLIENTLIST|" + clientListStr);
        } catch (IOException e) {
            System.out.println("Error sending client list to " + client.username + ": " + e.getMessage());
        }
    }
}
    }
}
