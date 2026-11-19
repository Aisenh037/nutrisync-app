import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/maps_integration_service.dart';
import '../services/navigation_service.dart';

/// Screen for displaying detailed store information
class StoreDetailsScreen extends StatefulWidget {
  final StoreInfo store;
  
  const StoreDetailsScreen({
    super.key,
    required this.store,
  });

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  final MapsIntegrationService _mapsService = MapsIntegrationService.instance;
  final NavigationService _navigationService = NavigationService.instance;
  
  StoreDetails? _storeDetails;
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadStoreDetails();
  }
  
  Future<void> _loadStoreDetails() async {
    try {
      setState(() => _isLoading = true);
      
      final details = await _mapsService.getStoreDetails(widget.store.id);
      
      setState(() {
        _storeDetails = details;
        _error = details.error;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load store details: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareStore,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  Widget _buildBody() {
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
              onPressed: _loadStoreDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStoreHeader(),
          const SizedBox(height: 24),
          _buildContactInfo(),
          const SizedBox(height: 24),
          _buildOpeningHours(),
          const SizedBox(height: 24),
          _buildDietaryInfo(),
          const SizedBox(height: 24),
          _buildPhotos(),
          const SizedBox(height: 24),
          _buildReviews(),
          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }
  
  Widget _buildStoreHeader() {
    final store = _storeDetails ?? widget.store;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    store.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (store.rating > 0) ...[
                  Icon(
                    Icons.star,
                    color: Colors.amber[600],
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    store.rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (store.userRatingsTotal > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${store.userRatingsTotal})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    store.address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(widget.store.distance / 1000).toStringAsFixed(1)}km away',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (_storeDetails?.priceLevel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getPriceLevelText(_storeDetails!.priceLevel!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildContactInfo() {
    final details = _storeDetails;
    if (details == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (details.phoneNumber != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone),
                title: Text(details.phoneNumber!),
                onTap: () => _makePhoneCall(details.phoneNumber!),
              ),
            ],
            if (details.website != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language),
                title: const Text('Visit Website'),
                subtitle: Text(details.website!),
                onTap: () => _openWebsite(details.website!),
              ),
            ],
            if (details.phoneNumber == null && details.website == null)
              const Text('No contact information available'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOpeningHours() {
    final hours = _storeDetails?.openingHours ?? widget.store.openingHours;
    if (hours == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Opening Hours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hours.openNow ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hours.openNow ? 'Open' : 'Closed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hours.weekdayText != null) ...[
              ...hours.weekdayText!.map((dayHours) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  dayHours,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )),
            ] else
              const Text('Hours information not available'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDietaryInfo() {
    final compatibility = widget.store.dietaryCompatibility;
    if (compatibility.reasons.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dietary Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: compatibility.reasons.map((reason) => Chip(
                label: Text(reason),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: compatibility.score,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dietary compatibility: ${(compatibility.score * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhotos() {
    final photos = _storeDetails?.photos ?? widget.store.photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _getPhotoUrl(photo.reference),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image_not_supported,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReviews() {
    final reviews = _storeDetails?.reviews ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Reviews',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...reviews.take(3).map((review) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        review.authorName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) => Icon(
                          index < review.rating ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber[600],
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.text,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (review != reviews.last) ...[
                    const SizedBox(height: 8),
                    Divider(color: Theme.of(context).colorScheme.outline),
                  ],
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _callStore,
              icon: const Icon(Icons.phone),
              label: const Text('Call'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _navigateToStore,
              icon: const Icon(Icons.directions),
              label: const Text('Get Directions'),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPriceLevelText(int priceLevel) {
    switch (priceLevel) {
      case 0:
        return 'Free';
      case 1:
        return 'Inexpensive (\$)';
      case 2:
        return 'Moderate (\$\$)';
      case 3:
        return 'Expensive (\$\$\$)';
      case 4:
        return 'Very Expensive (\$\$\$\$)';
      default:
        return 'Price not available';
    }
  }
  
  String _getPhotoUrl(String photoReference) {
    // This would need to be implemented with proper Google Places Photo API
    // For now, return a placeholder
    return 'https://via.placeholder.com/120x120?text=Store+Photo';
  }
  
  Future<void> _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackBar('Could not make phone call');
    }
  }
  
  Future<void> _openWebsite(String website) async {
    if (await canLaunchUrl(Uri.parse(website))) {
      await launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open website');
    }
  }
  
  void _callStore() {
    final phoneNumber = _storeDetails?.phoneNumber ?? widget.store.phoneNumber;
    if (phoneNumber != null) {
      _makePhoneCall(phoneNumber);
    } else {
      _showErrorSnackBar('Phone number not available');
    }
  }
  
  void _navigateToStore() async {
    try {
      // Get available navigation apps
      final availableApps = await _navigationService.getAvailableApps();
      
      if (availableApps.isEmpty) {
        _showErrorSnackBar('No navigation apps available');
        return;
      }
      
      // Show navigation app selection dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Navigate to ${widget.store.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose your preferred navigation app:'),
              const SizedBox(height: 16),
              ...availableApps.map((app) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_getAppIcon(app)),
                title: Text(app.displayName),
                onTap: () {
                  Navigator.pop(context);
                  _launchNavigation(app);
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
    } catch (e) {
      _showErrorSnackBar('Failed to get navigation options: $e');
    }
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
  
  Future<void> _launchNavigation(NavigationApp app) async {
    final success = await _navigationService.navigateToLocation(
      latitude: widget.store.location.latitude,
      longitude: widget.store.location.longitude,
      destinationName: widget.store.name,
      placeId: widget.store.id,
      preferredApp: app,
    );
    
    if (!success) {
      _showErrorSnackBar('Failed to open ${app.displayName}');
    }
  }
  
  void _shareStore() {
    final store = widget.store;
    final text = '${store.name}\n${store.address}\nRating: ${store.rating}/5\nhttps://www.google.com/maps/place/?q=place_id:${store.id}';
    
    // This would use the share package in a real implementation
    _showErrorSnackBar('Share functionality would be implemented here');
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}