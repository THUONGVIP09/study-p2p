import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/network_helper.dart';
import '../../config/app_config.dart';
import 'hybrid_chat_screen.dart';

/// Màn hình setup connection trước khi vào chat
/// Cho phép user config server IP nếu chạy trên máy khác
class ChatConnectionSetupScreen extends StatefulWidget {
  final int friendId;
  final String friendName;
  final int currentUserId;

  const ChatConnectionSetupScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ChatConnectionSetupScreen> createState() =>
      _ChatConnectionSetupScreenState();
}

class _ChatConnectionSetupScreenState extends State<ChatConnectionSetupScreen> {
  final TextEditingController _serverIpController = TextEditingController();
  String _myIp = 'Detecting...';
  bool _isLoading = true;
  bool _isLocalhostMode = true;
  String _detectedServerIp = '127.0.0.1';

  @override
  void initState() {
    super.initState();
    _detectNetworkInfo();
  }

  Future<void> _detectNetworkInfo() async {
    setState(() => _isLoading = true);

    try {
      // Detect local IP
      final myIp = await NetworkHelper.getLocalIpAddress();

      // Check current server IP config
      final currentServerIp = AppConfig.currentServerIp;
      final isLocalhost = AppConfig.isLocalhostMode;

      setState(() {
        _myIp = myIp;
        _isLocalhostMode = isLocalhost;
        _detectedServerIp = currentServerIp;
        _serverIpController.text = currentServerIp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _myIp = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _proceedToChat() {
    final serverIp = _serverIpController.text.trim();

    if (serverIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter server IP')),
      );
      return;
    }

    // Update AppConfig with new server IP
    AppConfig.setServerIp(serverIp);

    // Navigate to chat
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HybridChatScreen(
          friendId: widget.friendId,
          friendName: widget.friendName,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  void _useLocalhost() {
    setState(() {
      _serverIpController.text = '127.0.0.1';
    });
  }

  void _useMyIp() {
    if (_myIp != 'Detecting...' && !_myIp.startsWith('Error')) {
      setState(() {
        _serverIpController.text = _myIp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect to ${widget.friendName}'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Network Info Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Your Network Info',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildInfoRow('Your IP Address', _myIp,
                              canCopy: true),
                          _buildInfoRow('Current Server IP', _detectedServerIp,
                              canCopy: true),
                          _buildInfoRow(
                            'Mode',
                            _isLocalhostMode
                                ? '🖥️ Same Machine'
                                : '🌐 Network (LAN)',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  Text(
                    'Server IP Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the IP address where the chat server is running:',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),

                  const SizedBox(height: 16),

                  // Server IP Input
                  TextField(
                    controller: _serverIpController,
                    decoration: InputDecoration(
                      labelText: 'Server IP Address',
                      hintText: '192.168.1.100',
                      prefixIcon: const Icon(Icons.dns),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _serverIpController.clear(),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),

                  // Quick Actions
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _useLocalhost,
                        icon: const Icon(Icons.computer, size: 18),
                        label: const Text('Same Machine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade900,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _useMyIp,
                        icon: const Icon(Icons.wifi, size: 18),
                        label: const Text('This Machine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Help Section
                  ExpansionTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Need help?'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHelpItem(
                              '🖥️ Same Machine (Testing)',
                              'Use: 127.0.0.1\nBoth apps running on this computer',
                            ),
                            const Divider(),
                            _buildHelpItem(
                              '🌐 Different Machines (LAN)',
                              'Use: Server\'s LAN IP (e.g., 192.168.1.100)\nFind it on the server machine\'s app',
                            ),
                            const Divider(),
                            _buildHelpItem(
                              '📡 Server on This Machine',
                              'Use: $_myIp\nYour IP address shown above',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Connect Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _proceedToChat,
                      icon: const Icon(Icons.chat),
                      label: const Text(
                        'Connect & Start Chat',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontFamily: 'monospace',
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied: $value')),
                    );
                  },
                  child:
                      Icon(Icons.copy, size: 16, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }
}
