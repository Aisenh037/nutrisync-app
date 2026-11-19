const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const { Client } = require('@googlemaps/google-maps-services-js');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Google Maps client
const mapsClient = new Client({});

// Get Google Maps API key from environment
const GOOGLE_MAPS_API_KEY = functions.config().google?.maps_api_key || process.env.GOOGLE_MAPS_API_KEY;

/**
 * Find nearby grocery stores using Google Places API
 */
exports.findNearbyStores = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      // Validate request method
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      // Extract parameters
      const {
        latitude,
        longitude,
        radius = 5000, // Default 5km radius
        storeTypes = ['grocery_or_supermarket', 'health', 'store'],
        dietaryPreferences = [],
        maxResults = 20
      } = req.body;

      // Validate required parameters
      if (!latitude || !longitude) {
        return res.status(400).json({ 
          error: 'Missing required parameters: latitude and longitude' 
        });
      }

      if (!GOOGLE_MAPS_API_KEY) {
        return res.status(500).json({ 
          error: 'Google Maps API key not configured' 
        });
      }

      console.log(`Finding stores near ${latitude}, ${longitude} within ${radius}m`);

      // Search for stores using Google Places API
      const storeResults = [];
      
      for (const storeType of storeTypes) {
        try {
          const response = await mapsClient.placesNearby({
            params: {
              location: { lat: latitude, lng: longitude },
              radius: radius,
              type: storeType,
              key: GOOGLE_MAPS_API_KEY,
            },
          });

          if (response.data.results) {
            storeResults.push(...response.data.results);
          }
        } catch (error) {
          console.error(`Error searching for ${storeType}:`, error.message);
        }
      }

      // Remove duplicates based on place_id
      const uniqueStores = storeResults.filter((store, index, self) =>
        index === self.findIndex(s => s.place_id === store.place_id)
      );

      // Process and enhance store data
      const processedStores = await Promise.all(
        uniqueStores.slice(0, maxResults).map(async (store) => {
          try {
            // Get additional details for each store
            const detailsResponse = await mapsClient.placeDetails({
              params: {
                place_id: store.place_id,
                fields: [
                  'name', 'formatted_address', 'formatted_phone_number',
                  'opening_hours', 'rating', 'user_ratings_total',
                  'website', 'price_level', 'types'
                ].join(','),
                key: GOOGLE_MAPS_API_KEY,
              },
            });

            const details = detailsResponse.data.result;
            
            // Calculate distance
            const distance = calculateDistance(
              latitude, longitude,
              store.geometry.location.lat, store.geometry.location.lng
            );

            // Determine dietary compatibility
            const dietaryCompatibility = calculateDietaryCompatibility(
              store, details, dietaryPreferences
            );

            return {
              id: store.place_id,
              name: details.name || store.name,
              address: details.formatted_address || store.vicinity,
              location: {
                latitude: store.geometry.location.lat,
                longitude: store.geometry.location.lng
              },
              distance: Math.round(distance),
              rating: store.rating || 0,
              userRatingsTotal: details.user_ratings_total || 0,
              priceLevel: details.price_level,
              phoneNumber: details.formatted_phone_number,
              website: details.website,
              openingHours: details.opening_hours ? {
                openNow: details.opening_hours.open_now,
                weekdayText: details.opening_hours.weekday_text
              } : null,
              storeTypes: details.types || store.types,
              dietaryCompatibility,
              photos: store.photos ? store.photos.slice(0, 3).map(photo => ({
                reference: photo.photo_reference,
                width: photo.width,
                height: photo.height
              })) : []
            };
          } catch (error) {
            console.error(`Error getting details for store ${store.place_id}:`, error.message);
            
            // Return basic store info if details fail
            const distance = calculateDistance(
              latitude, longitude,
              store.geometry.location.lat, store.geometry.location.lng
            );

            return {
              id: store.place_id,
              name: store.name,
              address: store.vicinity,
              location: {
                latitude: store.geometry.location.lat,
                longitude: store.geometry.location.lng
              },
              distance: Math.round(distance),
              rating: store.rating || 0,
              userRatingsTotal: 0,
              storeTypes: store.types,
              dietaryCompatibility: calculateDietaryCompatibility(store, null, dietaryPreferences)
            };
          }
        })
      );

      // Sort by dietary compatibility and distance
      processedStores.sort((a, b) => {
        // First sort by dietary compatibility score
        if (b.dietaryCompatibility.score !== a.dietaryCompatibility.score) {
          return b.dietaryCompatibility.score - a.dietaryCompatibility.score;
        }
        // Then by distance
        return a.distance - b.distance;
      });

      res.json({
        stores: processedStores,
        searchParams: {
          location: { latitude, longitude },
          radius,
          storeTypes,
          dietaryPreferences,
          maxResults
        },
        totalFound: processedStores.length,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Error in findNearbyStores:', error);
      res.status(500).json({ 
        error: 'Internal server error',
        message: error.message 
      });
    }
  });
});

/**
 * Get store details by place ID
 */
exports.getStoreDetails = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      const { placeId } = req.query;

      if (!placeId) {
        return res.status(400).json({ error: 'Missing required parameter: placeId' });
      }

      if (!GOOGLE_MAPS_API_KEY) {
        return res.status(500).json({ error: 'Google Maps API key not configured' });
      }

      console.log(`Getting details for place: ${placeId}`);

      const response = await mapsClient.placeDetails({
        params: {
          place_id: placeId,
          fields: [
            'name', 'formatted_address', 'formatted_phone_number',
            'opening_hours', 'rating', 'user_ratings_total',
            'website', 'price_level', 'types', 'geometry',
            'photos', 'reviews'
          ].join(','),
          key: GOOGLE_MAPS_API_KEY,
        },
      });

      const details = response.data.result;

      const storeDetails = {
        id: placeId,
        name: details.name,
        address: details.formatted_address,
        location: {
          latitude: details.geometry.location.lat,
          longitude: details.geometry.location.lng
        },
        rating: details.rating || 0,
        userRatingsTotal: details.user_ratings_total || 0,
        priceLevel: details.price_level,
        phoneNumber: details.formatted_phone_number,
        website: details.website,
        openingHours: details.opening_hours ? {
          openNow: details.opening_hours.open_now,
          weekdayText: details.opening_hours.weekday_text,
          periods: details.opening_hours.periods
        } : null,
        storeTypes: details.types,
        photos: details.photos ? details.photos.slice(0, 5).map(photo => ({
          reference: photo.photo_reference,
          width: photo.width,
          height: photo.height
        })) : [],
        reviews: details.reviews ? details.reviews.slice(0, 5).map(review => ({
          authorName: review.author_name,
          rating: review.rating,
          text: review.text,
          time: review.time
        })) : []
      };

      res.json(storeDetails);

    } catch (error) {
      console.error('Error in getStoreDetails:', error);
      res.status(500).json({ 
        error: 'Internal server error',
        message: error.message 
      });
    }
  });
});

/**
 * Get navigation directions to a store
 */
exports.getDirections = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      const {
        originLat,
        originLng,
        destinationLat,
        destinationLng,
        travelMode = 'driving'
      } = req.body;

      if (!originLat || !originLng || !destinationLat || !destinationLng) {
        return res.status(400).json({ 
          error: 'Missing required parameters: origin and destination coordinates' 
        });
      }

      if (!GOOGLE_MAPS_API_KEY) {
        return res.status(500).json({ error: 'Google Maps API key not configured' });
      }

      console.log(`Getting directions from ${originLat},${originLng} to ${destinationLat},${destinationLng}`);

      const response = await mapsClient.directions({
        params: {
          origin: { lat: originLat, lng: originLng },
          destination: { lat: destinationLat, lng: destinationLng },
          mode: travelMode,
          key: GOOGLE_MAPS_API_KEY,
        },
      });

      if (response.data.routes.length === 0) {
        return res.status(404).json({ error: 'No routes found' });
      }

      const route = response.data.routes[0];
      const leg = route.legs[0];

      const directions = {
        distance: {
          text: leg.distance.text,
          value: leg.distance.value
        },
        duration: {
          text: leg.duration.text,
          value: leg.duration.value
        },
        startAddress: leg.start_address,
        endAddress: leg.end_address,
        steps: leg.steps.map(step => ({
          instruction: step.html_instructions.replace(/<[^>]*>/g, ''), // Remove HTML tags
          distance: step.distance.text,
          duration: step.duration.text,
          startLocation: step.start_location,
          endLocation: step.end_location
        })),
        polyline: route.overview_polyline.points,
        travelMode
      };

      res.json(directions);

    } catch (error) {
      console.error('Error in getDirections:', error);
      res.status(500).json({ 
        error: 'Internal server error',
        message: error.message 
      });
    }
  });
});

/**
 * Calculate distance between two points using Haversine formula
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

/**
 * Calculate dietary compatibility score for a store
 */
function calculateDietaryCompatibility(store, details, dietaryPreferences) {
  if (!dietaryPreferences || dietaryPreferences.length === 0) {
    return { score: 1.0, reasons: ['No specific dietary preferences'] };
  }

  let score = 0.5; // Base score
  const reasons = [];
  const storeTypes = details?.types || store.types || [];
  const storeName = (details?.name || store.name || '').toLowerCase();

  // Check for specific dietary preference matches
  for (const preference of dietaryPreferences) {
    const pref = preference.toLowerCase();
    
    switch (pref) {
      case 'organic':
        if (storeName.includes('organic') || storeName.includes('whole foods') || 
            storeName.includes('natural') || storeTypes.includes('health')) {
          score += 0.3;
          reasons.push('Offers organic products');
        }
        break;
        
      case 'vegan':
      case 'vegetarian':
        if (storeName.includes('vegan') || storeName.includes('vegetarian') ||
            storeName.includes('plant') || storeTypes.includes('health')) {
          score += 0.3;
          reasons.push('Caters to plant-based diets');
        }
        break;
        
      case 'gluten-free':
        if (storeName.includes('gluten') || storeName.includes('celiac') ||
            storeTypes.includes('health')) {
          score += 0.3;
          reasons.push('Offers gluten-free options');
        }
        break;
        
      case 'halal':
        if (storeName.includes('halal') || storeName.includes('islamic')) {
          score += 0.4;
          reasons.push('Certified halal products');
        }
        break;
        
      case 'kosher':
        if (storeName.includes('kosher') || storeName.includes('jewish')) {
          score += 0.4;
          reasons.push('Certified kosher products');
        }
        break;
        
      case 'local':
      case 'farmers-market':
        if (storeTypes.includes('farmer') || storeName.includes('farmer') ||
            storeName.includes('local') || storeName.includes('co-op')) {
          score += 0.2;
          reasons.push('Supports local farmers');
        }
        break;
    }
  }

  // Bonus for health food stores
  if (storeTypes.includes('health') || storeName.includes('health')) {
    score += 0.1;
    reasons.push('Health food store');
  }

  // Cap the score at 1.0
  score = Math.min(score, 1.0);

  if (reasons.length === 0) {
    reasons.push('General grocery store');
  }

  return { score, reasons };
}