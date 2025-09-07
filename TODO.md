# NutriSync App - Feature Enhancements

## ✅ Completed Features
- [x] Google Sign-In functionality implemented
- [x] Firebase configuration fixed

## 🚀 New Features to Implement

### 1. Enhanced Registration Process
- [ ] Create a dedicated signup screen that collects:
  - [ ] Name
  - [ ] Dietary needs (multi-select or text input)
  - [ ] Health goals (multi-select or text input)
- [ ] Update AuthService to handle user profile creation during signup
- [ ] Integrate new signup screen into the app flow

### 2. Profile Editing (Already Partially Implemented)
- [ ] Verify existing profile editing functionality works correctly
- [ ] Test that changes are saved to Firestore and reflected in UI

### 3. Grocery Item Editing
- [ ] Add edit functionality to grocery items in GroceriesPage
- [ ] Implement inline editing or dialog-based editing
- [ ] Update FirestoreService with edit grocery method
- [ ] Add edit button to each grocery item

### 4. UI/UX Improvements
- [ ] Improve dietary needs and health goals input (consider chips or multi-select)
- [ ] Add validation for all form fields
- [ ] Improve error handling and user feedback

## 📋 Implementation Plan

### Phase 1: Enhanced Registration
1. Create `lib/screens/signup_screen.dart`
2. Update `lib/api/auth_service.dart` to create user profile during signup
3. Update navigation flow to use new signup screen

### Phase 2: Grocery Editing
1. Add edit functionality to `lib/screens/home_screen.dart` (GroceriesPage)
2. Update `lib/api/firestore_service.dart` with edit grocery method
3. Test edit functionality

### Phase 3: Testing & Polish
1. Test complete user flow from signup to profile editing
2. Test grocery CRUD operations
3. Polish UI and add proper validation

## 🔍 Current Status
- UserModel already supports name, dietaryNeeds, healthGoals
- ProfilePage already has editing functionality
- GroceriesPage needs edit functionality added
- AuthService needs profile creation during signup
