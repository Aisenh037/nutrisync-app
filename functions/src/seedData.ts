/**
 * Data seeding functions for NutriSync
 * Populates Firestore with Indian food database and educational content
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onCall} from "firebase-functions/v2/https";

const db = admin.firestore();

/**
 * Seed Indian foods database
 * Callable function to populate the database with comprehensive Indian food data
 */
export const seedIndianFoods = onCall(async (request) => {
  // Only allow admin users to seed data
  if (!request.auth?.token?.admin) {
    throw new Error("Admin access required");
  }

  logger.info("Starting Indian foods database seeding");

  try {
    const batch = db.batch();

    // Comprehensive Indian food data
    const indianFoods = [
      // Dal varieties
      {
        id: "dal_tadka",
        name: "Dal Tadka",
        aliases: ["dal", "lentils", "arhar dal", "toor dal"],
        nutrition: {
          calories: 150.0,
          protein: 12.0,
          carbs: 20.0,
          fat: 4.0,
          fiber: 8.0,
          vitamins: {"B1": 0.3, "C": 15.0, "B6": 0.2, "folate": 45.0},
          minerals: {
            "iron": 3.5,
            "potassium": 350.0,
            "magnesium": 45.0,
            "zinc": 1.2,
          },
        },
        cookingMethods: {
          defaultMethod: {
            name: "tadka",
            description: "Tempered with spices in hot oil",
            nutritionMultiplier: 1.0,
            commonIngredients: [
              "lentils", "oil", "cumin", "turmeric", "onion", "tomato",
            ],
          },
          alternatives: [],
          nutritionAdjustments: {},
        },
        portionSizes: {
          standardPortions: {"katori": 150.0},
          visualReference: "1 katori (small bowl)",
          gramsPerPortion: 150.0,
        },
        regions: {
          primaryRegion: "North Indian",
          availableRegions: ["North Indian", "Central Indian", "West Indian"],
          regionalNames: {"Hindi": "दाल तड़का", "Punjabi": "ਦਾਲ ਤੜਕਾ"},
        },
        category: "dal",
        commonCombinations: ["rice", "roti", "pickle", "papad"],
        searchTerms: ["dal", "lentils", "protein", "tadka", "arhar", "toor"],
        baseDish: "dal",
        regionalVariations: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    // Add each food item to the batch
    for (const food of indianFoods) {
      const docRef = db.collection("indianFoods").doc(food.id);
      batch.set(docRef, food);
    }

    await batch.commit();
    logger.info(`Successfully seeded ${indianFoods.length} Indian food items`);

    return {
      success: true,
      message: `Successfully seeded ${indianFoods.length} Indian food items`,
      count: indianFoods.length,
    };
  } catch (error) {
    logger.error("Error seeding Indian foods database", error);
    throw new Error("Failed to seed Indian foods database");
  }
});

/**
 * Seed cooking education content
 */
export const seedCookingEducation = onCall(async (request) => {
  // Only allow admin users to seed data
  if (!request.auth?.token?.admin) {
    throw new Error("Admin access required");
  }

  logger.info("Starting cooking education content seeding");

  try {
    const batch = db.batch();

    const educationContent = [
      {
        id: "healthy_cooking_tips",
        title: "Healthy Indian Cooking Tips",
        category: "General",
        tips: [
          {
            tip: "Use minimal oil and prefer steaming or grilling",
            benefit: "Reduces calories while maintaining nutrition",
            hinglishTip: "Kam oil use karo aur steam ya grill karo!",
          },
        ],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    for (const content of educationContent) {
      const docRef = db.collection("cookingEducation").doc(content.id);
      batch.set(docRef, content);
    }

    await batch.commit();
    logger.info(`Successfully seeded ${educationContent.length} items`);

    return {
      success: true,
      message: `Successfully seeded ${educationContent.length} items`,
      count: educationContent.length,
    };
  } catch (error) {
    logger.error("Error seeding cooking education content", error);
    throw new Error("Failed to seed cooking education content");
  }
});

/**
 * Initialize complete database with all seed data
 */
export const initializeDatabase = onCall(async (request) => {
  // Only allow admin users to initialize database
  if (!request.auth?.token?.admin) {
    throw new Error("Admin access required");
  }

  logger.info("Starting complete database initialization");

  try {
    // Seed Indian foods
    await seedIndianFoods.run(request);

    // Seed cooking education
    await seedCookingEducation.run(request);

    logger.info("Successfully initialized complete database");

    return {
      success: true,
      message: "Successfully initialized complete database",
    };
  } catch (error) {
    logger.error("Error initializing database", error);
    throw new Error("Failed to initialize database");
  }
});