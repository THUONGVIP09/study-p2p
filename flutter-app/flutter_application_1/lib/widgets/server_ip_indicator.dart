import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_helper.dart';

/// Widget hiển thị IP của máy ở góc dưới màn hình
/// Giúp user biết IP của server để share cho máy khác
class ServerIpIndicator extends StatefulWidget {
  const ServerIpIndicator({Key? key}) : super(key: key);

  @override
  State<ServerIpIndicator> createState() => _ServerIpIndicatorState();
}

class _ServerIpIndicatorState extends State<ServerIpIndicator> {
  String _myIp = 'Detecting...';
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    try {
      final ip = await NetworkHelper.getLocalIpAddress();
      if (mounted) {
        setState(() => _myIp = ip);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _myIp = 'Error');
      }
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _myIp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Copied IP: $_myIp'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade700.withOpacity(0.9),
            borderRadius: BorderRadius.circular(_isExpanded ? 12 : 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isExpanded ? _buildExpanded() : _buildCollapsed(),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi, color: Colors.white, size: 16),
        SizedBox(width: 4),
        Text(
          'IP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.computer, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text(
              'My Server IP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _myIp,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _copyToClipboard,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.copy,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to collapse',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
