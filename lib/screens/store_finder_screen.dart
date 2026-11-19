import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/maps_integration_service.dart';
import '../services/navigation_service.dart';
import 'store_details_screen.dart';

/// Screen for finding and displaying nearby stores
class StoreFinderScreen extends StatefulWidget {
  const StoreFinderScreen({super.key});

  @override
  State<StoreFinderScreen> createState() => _StoreFinderScreenState();
}

class _StoreFinderScreenState extends State<StoreFinderScreen> {
  final MapsIntegrationService _mapsService = MapsIntegrationService.instance;
  final NavigationService _navigationService = NavigationService.instance;
  
  List<StoreInfo> _stores = [];
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  
  final List<String> _dietaryPreferences = [];
  final List<String> _availableDietaryOptions = [
    'organic',
    'vegan',
    'vegetarian',
    'gluten-free',
    'halal',
    'kosher',
    'local',
  ];
  
  double _searchRadius = 5000; // 5km default
  
  @override
  void initState() {
    super.initState();
    _initializeAndSearch();
  }
  
  Future<void> _initializeAndSearch() async {
    await _mapsService.initialize();
    await _getCurrentLocation();
    if (_currentPosition != null) {
      await _searchStores();
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions are permanently denied';
          _isLoading = false;
        });
        return;
      }
      
      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() => _error = null);
      
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _searchStores() async {
    if (_currentPosition == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      final result = await _mapsService.findNearbyStores(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: _searchRadius,
        dietaryPreferences: _dietaryPreferences,
      );
      
      setState(() {
        _stores = result.stores;
        _error = result.error;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Failed to search stores: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Stores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _searchStores,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _buildStoreList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found ${_stores.length} stores within ${(_searchRadius / 1000).toStringAsFixed(1)}km',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_dietaryPreferences.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _dietaryPreferences.map((pref) => Chip(
                label: Text(pref),
                onDeleted: () {
                  setState(() => _dietaryPreferences.remove(pref));
                  _searchStores();
                },
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStoreList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchStores,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_stores.isEmpty) {
      return const Center(
        child: Text('No stores found in your area'),
      );
    }
    
    return ListView.builder(
      itemCount: _stores.length,
      itemBuilder: (context, index) {
        final store = _stores[index];
        return StoreCard(
          store: store,
          currentPosition: _currentPosition,
          onNavigate: () => _navigateToStore(store),
          onViewDetails: () => _viewStoreDetails(store),
        );
      },
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Stores'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Radius slider
            Text('Search Radius: ${(_searchRadius / 1000).toStringAsFixed(1)}km'),
            Slider(
              value: _searchRadius,
              min: 1000,
              max: 20000,
              divisions: 19,
              onChanged: (value) {
                setState(() => _searchRadius = value);
              },
            ),
            const SizedBox(height: 16),
            
            // Dietary preferences
            const Text('Dietary Preferences:'),
            ..._availableDietaryOptions.map((option) => CheckboxListTile(
              title: Text(option.toUpperCase()),
              value: _dietaryPreferences.contains(option),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _dietaryPreferences.add(option);
                  } else {
                    _dietaryPreferences.remove(option);
                  }
                });
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchStores();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _navigateToStore(StoreInfo store) async {
    if (_currentPosition == null) return;
    
    try {
      // Get available navigation apps
      final availableApps = await _navigationService.getAvailableApps();
      
      if (availableApps.isEmpty) {
        _showErrorSnackBar('No navigation apps available');
        return;
      }
      
      // Get directions first for display
      final directions = await _mapsService.getDirections(
        originLat: _currentPosition!.latitude,
        originLng: _currentPosition!.longitude,
        destinationLat: store.location.latitude,
        destinationLng: store.location.longitude,
      );
      
      if (directions.error != null) {
        _showErrorSnackBar('Failed to get directions: ${directions.error}');
        return;
      }
      
      // Show enhanced navigation options dialog
      _showEnhancedNavigationDialog(store, directions, availableApps);
      
    } catch (e) {
      _showErrorSnackBar('Failed to get directions: $e');
    }
  }
  
  void _showEnhancedNavigationDialog(
    StoreInfo store, 
    NavigationDirections directions, 
    List<NavigationApp> availableApps
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Navigate to ${store.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, size: 16),
                      const SizedBox(width: 8),
                      Text('Distance: ${directions.distance.text}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 8),
                      Text('Duration: ${directions.duration.text}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose navigation app:'),
            const SizedBox(height: 8),
            
            // Navigation app options
            ...availableApps.map((app) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_getAppIcon(app)),
              title: Text(app.displayName),
              onTap: () {
                Navigator.pop(context);
                _launchNavigation(store, app);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  IconData _getAppIcon(NavigationApp app) {
    switch (app) {
      case NavigationApp.googleMaps:
        return Icons.map;
      case NavigationApp.appleMaps:
        return Icons.map_outlined;
      case NavigationApp.waze:
        return Icons.navigation;
      case NavigationApp.mapbox:
        return Icons.explore;
    }
  }
  
  Future<void> _launchNavigation(StoreInfo store, NavigationApp app) async {
    if (_currentPosition == null) return;
    
    final success = await _navigationService.getDirections(
      originLat: _currentPosition!.latitude,
      originLng: _currentPosition!.longitude,
      destinationLat: store.location.latitude,
      destinationLng: store.location.longitude,
      destinationName: store.name,
      placeId: store.id,
      preferredApp: app,
    );
    
    if (!success) {
      _showErrorSnackBar('Failed to open ${app.displayName}');
    }
  }
  
  void _viewStoreDetails(StoreInfo store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreDetailsScreen(store: store),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Card widget for displaying store information
class StoreCard extends StatelessWidget {
  final StoreInfo store;
  final Position? currentPosition;
  final VoidCallback onNavigate;
  final VoidCallback onViewDetails;
  
  const StoreCard({
    super.key,
    required this.store,
    this.currentPosition,
    required this.onNavigate,
    required this.onViewDetails,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(store.distance / 1000).toStringAsFixed(1)}km',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (store.openingHours != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    store.openingHours!.openNow ? Icons.access_time : Icons.access_time_filled,
                    size: 16,
                    color: store.openingHours!.openNow ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    store.openingHours!.openNow ? 'Open now' : 'Closed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: store.openingHours!.openNow ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
            
            if (store.dietaryCompatibility.score > 0.6) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: store.dietaryCompatibility.reasons.take(2).map((reason) => 
                  Chip(
                    label: Text(
                      reason,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ).toList(),
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Navigate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}