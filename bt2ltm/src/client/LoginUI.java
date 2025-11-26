package client;

import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTextField;

import server.Server;

import java.awt.*;
import java.net.ServerSocket;
import java.net.Socket;

import javax.swing.*;
import java.net.*;
import java.io.*;


public class LoginUI extends JFrame {
    private JTextField usernamField;
    private JButton loginButton;

    public LoginUI() {

        setTitle("Login");
            setSize(300, 150);
            setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
            setLocationRelativeTo(null);

            JPanel panel = new JPanel(new GridLayout(2, 2, 10, 10));
            panel.setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
            JLabel usernameLabel = new JLabel("Username:");
            usernamField = new JTextField(20);
            loginButton = new JButton("Login");
            panel.add(usernameLabel);
            panel.add(usernamField);
            panel.add(new JLabel()); // Empty cell
            panel.add(loginButton);
            add(panel);

            loginButton.addActionListener(e -> {
                String username = usernamField.getText().trim();
                try{
                    ServerSocket serverSocket = new ServerSocket(0);
                    int port = serverSocket.getLocalPort();
                    serverSocket.close();

                    Socket socket = new Socket("127.0.0.1", 12345);
                    PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
                    BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                    out.println(username);
                    out.println(port);
                    String response = in.readLine();

                

                if ("OK".equals(response)) {
                    // Handle login logic here
                    new ChatUI(username, port,socket).setVisible(true);
                    this.dispose();
                    // For example, you might want to open the chat UI here
                } else {
                    JOptionPane.showMessageDialog(this, "Username cannot be empty.", "Error", JOptionPane.ERROR_MESSAGE);
                }
                } catch (Exception ex) {
                    JOptionPane.showMessageDialog(this, "Error connecting to server: " + ex.getMessage(), "Error", JOptionPane.ERROR_MESSAGE);
                }
            });
        }
    }

            
            
       

