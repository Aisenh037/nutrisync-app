/**
 * NutriSync Cloud Functions
 * Comprehensive backend for Voice-First AI Nutrition Assistant
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest, onCall} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Import seeding functions
export {
  seedIndianFoods,
  seedCookingEducation,
  initializeDatabase,
} from "./seedData";

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// Set global options for cost control (Firebase Free Plan: 125K invocations/month)
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1", // Free tier region
});

// ============================================================================
// USER MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Welcome new users and set up their profile
 * Triggered when a new user document is created
 */
export const onUserCreated = onDocumentCreated(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const userData = event.data?.data();

    logger.info(`New user created: ${userId}`, {userId, userData});

    try {
      // Initialize user's subcollections
      const batch = db.batch();

      // Create initial meal plan
      const mealPlanRef = db.collection("users").doc(userId)
        .collection("mealPlans").doc("current");
      batch.set(mealPlanRef, {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        days: {
          monday: [],
          tuesday: [],
          wednesday: [],
          thursday: [],
          friday: [],
          saturday: [],
          sunday: [],
        },
      });

      // Create initial grocery list
      const groceryRef = db.collection("users").doc(userId)
        .collection("groceries").doc("current");
      batch.set(groceryRef, {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        items: [],
        status: "active",
      });

      // Create user analytics document
      const analyticsRef = db.collection("analytics").doc(userId);
      batch.set(analyticsRef, {
        userId: userId,
        signupDate: admin.firestore.FieldValue.serverTimestamp(),
        totalMealsLogged: 0,
        totalVoiceInteractions: 0,
        subscriptionTier: userData?.subscriptionTier || "free",
        lastActiveDate: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();
      logger.info(`Successfully initialized user profile: ${userId}`);
    } catch (error) {
      logger.error(`Error initializing user profile: ${userId}`, error);
    }
  }
);

/**
 * Update user analytics when profile is updated
 */
export const onUserUpdated = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    try {
      // Update analytics if subscription tier changed
      if (beforeData?.subscriptionTier !== afterData?.subscriptionTier) {
        await db.collection("analytics").doc(userId).update({
          subscriptionTier: afterData?.subscriptionTier,
          subscriptionChangeDate: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info(`Subscription updated for user: ${userId}`, {
          from: beforeData?.subscriptionTier,
          to: afterData?.subscriptionTier,
        });
      }
    } catch (error) {
      logger.error(`Error updating user analytics: ${userId}`, error);
    }
  }
);

// ============================================================================
// NUTRITION & MEAL FUNCTIONS
// ============================================================================

/**
 * Process meal logging and update nutrition analytics
 */
export const onMealLogged = onDocumentCreated(
  "users/{userId}/meals/{mealId}",
  async (event) => {
    const userId = event.params.userId;
    const mealId = event.params.mealId;
    const mealData = event.data?.data();

    logger.info(`Meal logged for user: ${userId}`, {mealId, mealData});

    try {
      const batch = db.batch();

      // Update user analytics
      const analyticsRef = db.collection("analytics").doc(userId);
      batch.update(analyticsRef, {
        totalMealsLogged: admin.firestore.FieldValue.increment(1),
        lastMealDate: admin.firestore.FieldValue.serverTimestamp(),
        lastActiveDate: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update daily nutrition summary
      const today = new Date().toISOString().split("T")[0];
      const dailySummaryRef = db.collection("users").doc(userId)
        .collection("dailySummaries").doc(today);

      batch.set(dailySummaryRef, {
        date: today,
        totalCalories: admin.firestore.FieldValue
          .increment(mealData?.totalCalories || 0),
        totalProtein: admin.firestore.FieldValue
          .increment(mealData?.totalProtein || 0),
        totalCarbs: admin.firestore.FieldValue
          .increment(mealData?.totalCarbs || 0),
        totalFat: admin.firestore.FieldValue
          .increment(mealData?.totalFat || 0),
        mealCount: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      await batch.commit();
      logger.info(`Successfully processed meal logging for user: ${userId}`);
    } catch (error) {
      logger.error(`Error processing meal logging: ${userId}`, error);
    }
  }
);

/**
 * Generate personalized nutrition recommendations
 * Callable function for real-time recommendations
 */
export const generateRecommendations = onCall(async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new Error("Authentication required");
  }

  const {foodQuery, mealType} = request.data;

  logger.info(`Generating recommendations for user: ${userId}`, {
    foodQuery,
    mealType,
  });

  try {
    // Get user profile
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();

    if (!userData) {
      throw new Error("User profile not found");
    }

    // Get Indian foods matching the query
    const foodsQuery = await db.collection("indianFoods")
      .where("searchTerms", "array-contains-any",
        foodQuery.toLowerCase().split(" "))
      .limit(10)
      .get();

    const recommendations = [];

    for (const doc of foodsQuery.docs) {
      const food = doc.data();

      // Calculate recommendation score based on user profile
      let score = 0;

      // Health goals scoring
      if (userData.healthGoals?.includes("Weight loss") &&
          food.nutrition.calories < 200) {
        score += 20;
      }
      if (userData.healthGoals?.includes("Muscle building") &&
          food.nutrition.protein > 10) {
        score += 20;
      }

      // Medical conditions scoring
      if (userData.medicalConditions?.includes("Diabetes") &&
          food.nutrition.fiber > 5) {
        score += 15;
      }

      // Cultural preferences
      if (userData.culturalPreferences?.preferredRegion ===
          food.regions.primaryRegion) {
        score += 10;
      }

      recommendations.push({
        ...food,
        recommendationScore: score,
        reason: generateRecommendationReason(food, userData),
      });
    }

    // Sort by recommendation score
    recommendations.sort((a, b) => b.recommendationScore - a.recommendationScore);

    // Update analytics
    await db.collection("analytics").doc(userId).update({
      totalRecommendationRequests: admin.firestore.FieldValue.increment(1),
      lastActiveDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      recommendations: recommendations.slice(0, 5),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (error) {
    logger.error(`Error generating recommendations for user: ${userId}`, error);
    throw new Error("Failed to generate recommendations");
  }
});

/**
 * Process voice interactions and update analytics
 */
export const processVoiceInteraction = onCall(async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new Error("Authentication required");
  }

  const {interactionType, duration, success} = request.data;

  try {
    // Update user analytics
    await db.collection("analytics").doc(userId).update({
      totalVoiceInteractions: admin.firestore.FieldValue.increment(1),
      lastVoiceInteraction: admin.firestore.FieldValue.serverTimestamp(),
      lastActiveDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log interaction details
    await db.collection("users").doc(userId).collection("voiceInteractions").add({
      type: interactionType,
      duration: duration,
      success: success,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Voice interaction processed for user: ${userId}`, {
      interactionType,
      success,
    });

    return {success: true};
  } catch (error) {
    logger.error(`Error processing voice interaction: ${userId}`, error);
    throw new Error("Failed to process voice interaction");
  }
});

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

/**
 * Daily nutrition summary and recommendations
 * Runs every day at 8 PM IST (2:30 PM UTC)
 */
export const dailyNutritionSummary = onSchedule("30 14 * * *", async () => {
  logger.info("Running daily nutrition summary");

  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split("T")[0];

    // Get all users who logged meals yesterday
    const usersQuery = await db.collection("analytics")
      .where("lastMealDate", ">=", admin.firestore.Timestamp.fromDate(yesterday))
      .get();

    const batch = db.batch();

    for (const userDoc of usersQuery.docs) {
      const userId = userDoc.id;

      // Get daily summary
      const summaryDoc = await db.collection("users").doc(userId)
        .collection("dailySummaries").doc(dateStr).get();

      if (summaryDoc.exists) {
        const summary = summaryDoc.data();

        // Create notification for user
        const notificationRef = db.collection("users").doc(userId)
          .collection("notifications").doc();

        batch.set(notificationRef, {
          type: "daily_summary",
          title: "Your Daily Nutrition Summary",
          message: `Yesterday you consumed ${summary?.totalCalories || 0} ` +
            `calories across ${summary?.mealCount || 0} meals. ` +
            "Great job tracking your nutrition!",
          data: summary,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    logger.info(`Daily nutrition summary sent to ${usersQuery.docs.length} users`);
  } catch (error) {
    logger.error("Error in daily nutrition summary", error);
  }
});

/**
 * Weekly progress report
 * Runs every Sunday at 9 AM IST (3:30 AM UTC)
 */
export const weeklyProgressReport = onSchedule("30 3 * * 0", async () => {
  logger.info("Running weekly progress report");

  try {
    // Get active users from the last week
    const lastWeek = new Date();
    lastWeek.setDate(lastWeek.getDate() - 7);

    const activeUsersQuery = await db.collection("analytics")
      .where("lastActiveDate", ">=", admin.firestore.Timestamp.fromDate(lastWeek))
      .get();

    const batch = db.batch();

    for (const userDoc of activeUsersQuery.docs) {
      const userId = userDoc.id;
      const analytics = userDoc.data();

      // Create weekly report notification
      const notificationRef = db.collection("users").doc(userId)
        .collection("notifications").doc();

      batch.set(notificationRef, {
        type: "weekly_report",
        title: "Your Weekly Nutrition Progress",
        message: `This week you logged ${analytics.totalMealsLogged || 0} ` +
          `meals and had ${analytics.totalVoiceInteractions || 0} ` +
          "voice interactions. Keep up the great work!",
        data: {
          weeklyMeals: analytics.totalMealsLogged || 0,
          weeklyInteractions: analytics.totalVoiceInteractions || 0,
          subscriptionTier: analytics.subscriptionTier,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    logger.info(`Weekly progress report sent to ${activeUsersQuery.docs.length} users`);
  } catch (error) {
    logger.error("Error in weekly progress report", error);
  }
});

/**
 * Cleanup old data (runs monthly)
 * Runs on the 1st of every month at 2 AM IST (8:30 PM UTC previous day)
 */
export const monthlyCleanup = onSchedule("30 20 1 * *", async () => {
  logger.info("Running monthly cleanup");

  try {
    const threeMonthsAgo = new Date();
    threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

    // Clean up old voice interactions
    const oldInteractionsQuery = await db.collectionGroup("voiceInteractions")
      .where("timestamp", "<", admin.firestore.Timestamp.fromDate(threeMonthsAgo))
      .limit(500)
      .get();

    const batch = db.batch();
    oldInteractionsQuery.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    logger.info(`Cleaned up ${oldInteractionsQuery.docs.length} old voice interactions`);
  } catch (error) {
    logger.error("Error in monthly cleanup", error);
  }
});

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Generate recommendation reason based on user profile
 * @param {any} food - The food item data
 * @param {any} userData - The user profile data
 * @return {string} Recommendation reason text
 */
function generateRecommendationReason(food: any, userData: any): string {
  const reasons = [];

  if (userData.healthGoals?.includes("Weight loss") &&
      food.nutrition.calories < 200) {
    reasons.push("low in calories for weight management");
  }

  if (userData.healthGoals?.includes("Muscle building") &&
      food.nutrition.protein > 10) {
    reasons.push("high in protein for muscle building");
  }

  if (userData.medicalConditions?.includes("Diabetes") &&
      food.nutrition.fiber > 5) {
    reasons.push("high fiber content good for diabetes management");
  }

  if (food.nutrition.vitamins &&
      Object.keys(food.nutrition.vitamins).length > 0) {
    reasons.push("rich in essential vitamins");
  }

  return reasons.length > 0 ?
    `Recommended because it's ${reasons.join(", ")}` :
    "Good nutritional choice for your profile";
}

/**
 * Health check endpoint
 */
export const healthCheck = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
    services: {
      firestore: "connected",
      functions: "running",
    },
  });
});
