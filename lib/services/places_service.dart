import 'package:google_maps_webservice/places.dart';

class PlacesService {
  final String apiKey;

  PlacesService(this.apiKey);

  Future<List<PlacesSearchResult>> getNearbyGroceryStores(double lat, double lng) async {
    final GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: apiKey);

    PlacesSearchResponse response = await places.searchNearbyWithRadius(
      Location(lat: lat, lng: lng),
      5000, // 5km radius
      type: 'grocery_or_supermarket',
    );

    if (response.status == 'OK') {
      return response.results;
    } else {
      print('Places API error: ${response.status}');
      return [];
    }
  }
}
