package model;

import java.net.Socket;

public class ClientInfo {
    String username;
    String address;
    int port;
    private Socket socket;

    public ClientInfo(String username, String address, int port) {
        this.username = username;
        this.address = address;
        this.port = port;
        this.socket = socket;}

        public String getUsername() {
            return username;
        }
        public void setUsername(String username) {
            this.username = username;
        }
        public String getAddress() {
            return address;
        }
        public void setAddress(String address) {
            this.address = address;
        }
        public int getPort() {
            return port;
        }
        public void setPort(int port) {
            this.port = port;
        }


        public Socket getSocket() {
            return socket;
        }
        public void setSocket(Socket socket) {
            this.socket = socket;
        }
@Override
        public String toString() {
            return username + " (" + address + ":" + port + ")";
        }

    }
    

