import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/network_helper.dart';
import '../../config/app_config.dart';
import 'get_started_screen.dart';

/// Màn hình config server TRƯỚC KHI login
/// Cho phép user set IP server trước khi vào app
class ServerConfigScreen extends StatefulWidget {
  final bool isFirstTime;

  const ServerConfigScreen({Key? key, this.isFirstTime = false})
      : super(key: key);

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final TextEditingController _serverIpController = TextEditingController();
  String _myIp = 'Detecting...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    setState(() => _isLoading = true);

    try {
      final myIp = await NetworkHelper.getLocalIpAddress();
      final currentServerIp = AppConfig.currentServerIp;

      setState(() {
        _myIp = myIp;
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

  Future<void> _proceedToLogin() async {
    final serverIp = _serverIpController.text.trim();

    if (serverIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter server IP')),
      );
      return;
    }

    // Update AppConfig
    AppConfig.setServerIp(serverIp);
    AppConfig.printConfig();

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', serverIp);
      print('💾 Saved server IP to SharedPreferences: $serverIp');
    } catch (e) {
      print('❌ Error saving server IP: $e');
    }

    if (!mounted) return;

    // Navigate based on context
    if (widget.isFirstTime) {
      // Lần đầu → vào GetStartedScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GetStartedScreen()),
      );
    } else {
      // Từ GetStartedScreen → quay lại
      Navigator.of(context).pop();
    }
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
        title: Text(
            widget.isFirstTime ? 'First Time Setup' : 'Server Configuration'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading:
            !widget.isFirstTime, // No back button if first time
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  const Center(
                    child: Icon(Icons.dns, size: 80, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Configure Server',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Set server IP before login',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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
                          _buildInfoRow(
                            'Current Server IP',
                            AppConfig.currentServerIp,
                            canCopy: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Server IP Input
                  const Text(
                    'Server IP Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serverIpController,
                    decoration: InputDecoration(
                      hintText: '172.16.0.158 or 127.0.0.1',
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
                        label: const Text('Localhost'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade900,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _useMyIp,
                        icon: const Icon(Icons.wifi, size: 18),
                        label: const Text('My IP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Help
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Quick Guide',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Same Machine: Use 127.0.0.1\n'
                          '• Server on This Machine: Use your IP above\n'
                          '• Connect to Another Machine: Enter their IP',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _proceedToLogin,
                      icon: const Icon(Icons.login),
                      label: const Text(
                        'Continue to Login',
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

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }
}
