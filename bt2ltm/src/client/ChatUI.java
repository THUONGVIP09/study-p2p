package client;

import javax.swing.*;
import javax.swing.border.Border;
import java.awt.*;
import java.io.PrintWriter;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ChatUI extends JFrame {

    private JList<String> clientList;
    private DefaultListModel<String> clientListModel;

    private JTextArea chatArea;
    private JTextField inputField;
    private JButton sendButton;
    private JButton logoutButton;
    private String username;
    private int port;
    private Socket socket;
    private PrintWriter out;
    
    private ServerSocket peerListener;
    private Map<String, Integer> clientPorts = new HashMap<>();

    private Map<String, List<String>> chatHistory = new HashMap<>();
    private String currentTarget; // client đang chọn

    public ChatUI(String username, int port, Socket socket) {
        this.username = username;
        this.port = port;
        this.socket = socket;
        try {
            // Initialize input and output streams
            out = new PrintWriter(socket.getOutputStream(), true);
            
        } catch (Exception e) {
            e.printStackTrace();
        }
           
        setTitle("Chat Application");
        setSize(500, 400);
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setLocationRelativeTo(null);

        logoutButton = new JButton("Logout");
        logoutButton.addActionListener(e -> {
            try {
                out.println("LOGOUT");
                socket.close();
                if (peerListener != null && !peerListener.isClosed()) {
                    peerListener.close();
                }
            } catch (Exception ex) {
                ex.printStackTrace();
            }
            // Handle logout logic here
            new LoginUI().setVisible(true);
            this.dispose();
        });

        JPanel topPanel = new JPanel(new BorderLayout());
        topPanel.add(new JLabel("Logged in as: " + username), BorderLayout.WEST);
        topPanel.add(logoutButton, BorderLayout.EAST);
        add(topPanel, BorderLayout.EAST);

        clientListModel = new DefaultListModel<>();
        clientList = new JList<>(clientListModel);
        JScrollPane clientScrollPane = new JScrollPane(clientList);
        clientScrollPane.setBorder(BorderFactory.createTitledBorder("Connected Clients"));
       

        JPanel chatJPanel = new JPanel(new BorderLayout());
        chatArea = new JTextArea();
        chatArea.setEditable(false);
         
        JScrollPane chatScrollPane = new JScrollPane(chatArea);

        JPanel inputPanel = new JPanel(new BorderLayout());
        inputField = new JTextField();
        sendButton = new JButton("Send");
        inputPanel.add(inputField, BorderLayout.CENTER);
        inputPanel.add(sendButton, BorderLayout.EAST);
        chatJPanel.add(chatScrollPane, BorderLayout.CENTER);
        chatJPanel.add(inputPanel, BorderLayout.SOUTH);

        JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, clientScrollPane, chatJPanel);
        splitPane.setLeftComponent(clientScrollPane);
        splitPane.setRightComponent(chatJPanel);
        splitPane.setDividerLocation(150);
        setLayout(new BorderLayout());
        add(topPanel, BorderLayout.NORTH);
        add(splitPane, BorderLayout.CENTER);
        sendButton.addActionListener(e -> sendMessage());
        inputField.addActionListener(e -> sendMessage());

        // Start listening to server updates
        listenServer();

        // Start P2P listener
        startPeerListener();
        clientList.addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                String selected = clientList.getSelectedValue();
                if (selected != null) {
                    currentTarget = selected.split(" \\(")[0]; // chỉ lấy username
                    showChat(currentTarget);
                }
            }
        });
    }

    private void addMessage(String sender, String receiver, String message) {
        // Sử dụng key là sender (đối với người nhận) để nhất quán với cách lưu khi gửi
        chatHistory.computeIfAbsent(sender, k -> new ArrayList<>()).add(sender + ": " + message);
    }

    private void showChat(String target) {
        chatArea.setText(""); // xóa chatArea trước
        if (target == null) return;
        List<String> history = chatHistory.getOrDefault(target, new ArrayList<>());
        for (String msg : history) {
            chatArea.append(msg + "\n");
        }
    }

    private void listenServer() {
        new Thread(() -> {
            try {
                BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                String line;
                while ((line = in.readLine()) != null) {
                    if (line.startsWith("CLIENTLIST|")) {
                        String listStr = line.substring(11);
                        SwingUtilities.invokeLater(() -> updateClientList(listStr));
                    } else if (line.startsWith("MSG")) {
                        String message = line.substring(4);
                        SwingUtilities.invokeLater(() -> {
                            chatArea.append(message + "\n");
                        });
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }

    // Trong sendMessage(), lấy port từ map thay vì gọi server nhiều lần
    private void sendMessage() {
        String message = inputField.getText().trim();
        String selectedValue = clientList.getSelectedValue();
        if (message.isEmpty() || selectedValue == null) return;
        String user = selectedValue.split(" \\(")[0].trim();

        try {
            Integer targetPort = clientPorts.get(user);
            if (targetPort == null) {
                JOptionPane.showMessageDialog(this, "Cannot find target port for user " + user);
                return;
            }

            String targetIP = "127.0.0.1"; // hoặc lấy IP từ server nếu LAN
            Socket peerSocket = new Socket(targetIP, targetPort);
            PrintWriter outPeer = new PrintWriter(peerSocket.getOutputStream(), true);
            outPeer.println(username + ": " + message);
            peerSocket.close();

            // Lưu tin nhắn vào lịch sử chat (key là user - người nhận)
            chatHistory.computeIfAbsent(user, k -> new ArrayList<>()).add(username + ": " + message);
            // Hiển thị tin nhắn nếu đang chat với người nhận
            if (currentTarget != null && currentTarget.equals(user)) {
                showChat(user);
            }
            inputField.setText("");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private int getPortFromServer(String targetUser) {
        try {
            out.println("GETPORT " + targetUser);
            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            String response = in.readLine();
            if (response.startsWith("PORT")) {
                return Integer.parseInt(response.substring(5).trim());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return -1; // Indicate error
    }

    private void startPeerListener() {
        new Thread(() -> {
            try {
                peerListener = new ServerSocket(port);
                while (true) {
                    Socket peerSocket = peerListener.accept();

                    new Thread(() -> {
                        try (BufferedReader in = new BufferedReader(new InputStreamReader(peerSocket.getInputStream()))) {
                            String msg;
                            while ((msg = in.readLine()) != null) {
                                int idx = msg.indexOf(":");
                                if (idx != -1) {
                                    String sender = msg.substring(0, idx).trim();
                                    String message = msg.substring(idx + 1).trim();

                                    // Lưu lịch sử theo cặp 2 người
                                    addMessage(sender, username, message);

                                    // Hiển thị ngay nếu đang chat với sender
                                    SwingUtilities.invokeLater(() -> {
                                        if (currentTarget != null && currentTarget.equals(sender)) {
                                            chatArea.append(sender + ": " + message + "\n");
                                        }
                                    });
                                }
                            }
                        } catch (Exception e) {
                            e.printStackTrace();
                        } finally {
                            try { peerSocket.close(); } catch (Exception ex) { ex.printStackTrace(); }
                        }
                    }).start();
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }

    private void updateClientList(String clientListStr) {
        clientListModel.clear();
        clientPorts.clear();
        String[] clients = clientListStr.split(",");
        for (String entry : clients) {
            String[] parts = entry.split(":");
            if (parts.length == 3) {
                String name = parts[0].trim();
                int port = Integer.parseInt(parts[1].trim());
                String status = parts[2].trim();

                if (!name.equals(username)) { // bỏ chính mình
                    clientPorts.put(name, port);
                    String displayName = name + " (" + (status.equalsIgnoreCase("active") ? "Đang hoạt động" : "Ngoại tuyến") + ")";
                    clientListModel.addElement(displayName);
                }
            }
        }
    }
}