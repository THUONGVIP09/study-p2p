import 'package:flutter/material.dart';
import '../../services/p2p_chat_service.dart';
import '../../services/peer_discovery_service.dart';
import 'p2p_chat_screen.dart';

class P2PPeersListScreen extends StatefulWidget {
  const P2PPeersListScreen({Key? key}) : super(key: key);

  @override
  State<P2PPeersListScreen> createState() => _P2PPeersListScreenState();
}

class _P2PPeersListScreenState extends State<P2PPeersListScreen> {
  final P2PChatService _chatService = P2PChatService();
  final PeerDiscoveryService _discoveryService = PeerDiscoveryService();

  final Map<String, Map<String, dynamic>> _discoveredPeers = {};
  final TextEditingController _manualIpController = TextEditingController();
  final TextEditingController _manualPortController =
      TextEditingController(text: '9001');

  bool _isListening = false;
  bool _isDiscovering = false;
  String? _myPeerId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Bắt đầu lắng nghe
    final started = await _chatService.startListening();
    setState(() {
      _isListening = started;
      _myPeerId = _chatService.myPeerId;
    });

    // Bắt đầu discovery
    final discovered = await _discoveryService.startDiscovery(
      myDisplayName: 'User_${DateTime.now().millisecondsSinceEpoch % 1000}',
      myPort: P2PChatService.DEFAULT_PORT,
    );

    setState(() => _isDiscovering = discovered);

    // Lắng nghe peers mới
    _discoveryService.peerStream.listen((peer) {
      setState(() {
        _discoveredPeers[peer['peerId']] = peer;
      });
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    _discoveryService.dispose();
    _manualIpController.dispose();
    _manualPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Chat - Peers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('My Peer Info'),
                  content: Text(
                    'IP:Port: $_myPeerId\n\n'
                    'Share this with friends to connect!',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(
                  _isListening
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _isListening ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isListening ? 'Listening on $_myPeerId' : 'Not listening',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (_isDiscovering)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Manual connect
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual Connect',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _manualIpController,
                            decoration: const InputDecoration(
                              labelText: 'IP Address',
                              hintText: '192.168.1.100',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _manualPortController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _manualConnect,
                          child: const Text('Connect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Discovered peers list
          Expanded(
            child: _discoveredPeers.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No peers discovered yet.\n\n'
                        'Make sure other devices are on the same network\n'
                        'or use Manual Connect above.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _discoveredPeers.length,
                    itemBuilder: (context, index) {
                      final peerId = _discoveredPeers.keys.elementAt(index);
                      final peer = _discoveredPeers[peerId]!;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(peer['name'][0].toUpperCase()),
                        ),
                        title: Text(peer['name']),
                        subtitle: Text(peerId),
                        trailing: const Icon(Icons.chat),
                        onTap: () => _openChat(peerId, peer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualConnect() async {
    final ip = _manualIpController.text.trim();
    final portStr = _manualPortController.text.trim();

    if (ip.isEmpty || portStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter IP and Port')),
      );
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid port number')),
      );
      return;
    }

    final connected = await _chatService.connectToPeer(ip, port);

    if (connected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to $ip:$port')),
      );

      // Open chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => P2PChatScreen(
            peerId: '$ip:$port',
            peerName: 'Peer',
            chatService: _chatService,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to $ip:$port')),
      );
    }
  }

  Future<void> _openChat(String peerId, Map<String, dynamic> peer) async {
    // Kết nối nếu chưa
    final connected =
        await _chatService.connectToPeer(peer['ip'], peer['port']);

    if (!connected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to $peerId')),
      );
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => P2PChatScreen(
            peerId: peerId,
            peerName: peer['name'],
            chatService: _chatService,
          ),
        ),
      );
    }
  }
}
