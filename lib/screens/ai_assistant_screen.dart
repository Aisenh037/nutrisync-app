import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/eleven_labs_agent_service.dart';
import '../providers/providers.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';

class Message {
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}

const googlePlacesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY'; // Replace with your actual Google Places API key

final elevenLabsServiceProvider = Provider<ElevenLabsAgentService>((ref) {
  const apiKey = 'sk_8b912284e3bb7ee8a1d07041dcece48038550ccaa9b19007';
  const agentId = 'agent_1801k5krxvqkedbvzrt30mjsxnf1';
  return ElevenLabsAgentService(apiKey: apiKey, agentId: agentId);
});

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final placesServiceProvider = Provider<PlacesService>((ref) => PlacesService(googlePlacesApiKey));

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  Position? _currentPosition;
  List<PlacesSearchResult> _nearbyStores = [];
  bool _locationEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enableLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = position;
        _locationEnabled = true;
      });
      // Fetch stores
      final placesService = ref.read(placesServiceProvider);
      final stores = await placesService.getNearbyGroceryStores(position.latitude, position.longitude);
      setState(() {
        _nearbyStores = stores;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to get location')));
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });

    final user = ref.read(userProvider).asData?.value;
    final service = ref.read(elevenLabsServiceProvider);

    final response = await service.sendMessage(text, user, _currentPosition);

    setState(() {
      _isLoading = false;
    });

    if (response != null) {
      final responseText = response['text'] ?? 'No response text';
      setState(() {
        _messages.add(Message(text: responseText, isUser: false));
      });

      final audioUrl = response['audio_url'];
      if (audioUrl != null) {
        await service.playAudio(audioUrl);
      }
    } else {
      setState(() {
        _messages.add(Message(text: 'Sorry, I couldn\'t get a response.', isUser: false));
      });
    }

    _controller.clear();
  }

  Future<void> _handleVoiceInput() async {
    final service = ref.read(elevenLabsServiceProvider);
    final transcribedText = await service.listenAndTranscribe();
    if (transcribedText != null && transcribedText.isNotEmpty) {
      await _sendMessage(transcribedText);
    }
  }

  Future<void> _openStore(PlacesSearchResult store) async {
    final lat = store.geometry?.location.lat;
    final lng = store.geometry?.location.lng;
    if (lat != null && lng != null) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent'),
      ),
      body: Column(
        children: [
          if (!_locationEnabled)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _enableLocation,
                child: const Text('Enable Location'),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final message = _messages[index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.green[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (_nearbyStores.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _nearbyStores.length,
                itemBuilder: (context, index) {
                  final store = _nearbyStores[index];
                  return ListTile(
                    title: Text(store.name),
                    subtitle: Text(store.formattedAddress ?? ''),
                    trailing: const Icon(Icons.shopping_cart),
                    onTap: () => _openStore(store),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask for meal suggestions...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                ),
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: _handleVoiceInput,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
