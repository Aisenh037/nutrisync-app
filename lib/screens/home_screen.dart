import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const MealPlanPage(),
    const GroceriesPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Groceries'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2D5B42),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/// GroceriesPage displays and manages the user's grocery list with edit functionality.
class GroceriesPage extends ConsumerStatefulWidget {
  const GroceriesPage({super.key});

  @override
  ConsumerState<GroceriesPage> createState() => _GroceriesPageState();
}

class _GroceriesPageState extends ConsumerState<GroceriesPage> {
  final _itemController = TextEditingController();
  bool _adding = false;
  String? _error;
  String? _editingItem;
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _editGroceryItem(String oldItem, String newItem) async {
    if (newItem.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }

    if (oldItem == newItem.trim()) {
      setState(() {
        _editingItem = null;
        _editController.clear();
      });
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    final firestore = ref.read(firestoreServiceProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in'), backgroundColor: Colors.red),
      );
      return;
    }

    // Remove old item and add new item
    final removeResult = await firestore.removeGrocery(user.uid, oldItem);
    if (removeResult.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing item: ${removeResult.error}'), backgroundColor: Colors.red),
      );
      return;
    }

    final addResult = await firestore.addGrocery(user.uid, newItem.trim());
    if (addResult.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing item: ${addResult.error}'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _editingItem = null;
      _editController.clear();
    });

    // Refresh the list
    ref.refresh(groceriesProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item updated successfully!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groceriesAsync = ref.watch(groceriesProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final firestore = ref.read(firestoreServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groceries'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(labelText: 'Add item'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _adding
                      ? null
                      : () async {
                          final item = _itemController.text.trim();
                          if (item.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Item cannot be empty'),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Not signed in'),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setState(() {
                            _adding = true;
                            _error = null;
                          });
                          final result =
                              await firestore.addGrocery(user.uid, item);
                          setState(() {
                            _adding = false;
                            _itemController.clear();
                            _error = result.error;
                          });
                          ref.refresh(groceriesProvider);
                          if (result.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error adding item: ${result.error}'),
                                  backgroundColor: Colors.red),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Item added'),
                                  backgroundColor: Colors.green),
                            );
                          }
                        },
                  child: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: groceriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (groceries) {
                  if (groceries.isEmpty) {
                    return const Center(child: Text('No grocery items.'));
                  }
                  return ListView.separated(
                    itemCount: groceries.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final item = groceries[i];
                      final isEditing = _editingItem == item;

                      return ListTile(
                        title: isEditing
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _editController,
                                      autofocus: true,
                                      onSubmitted: (newItem) async {
                                        await _editGroceryItem(item, newItem);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () async {
                                      await _editGroceryItem(item, _editController.text.trim());
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _editingItem = null;
                                        _editController.clear();
                                      });
                                    },
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: user == null
                                    ? null
                                    : () {
                                        setState(() {
                                          _editingItem = item;
                                          _editController.text = item;
                                        });
                                      },
                                child: Text(item),
                              ),
                        trailing: user == null
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      setState(() {
                                        _editingItem = item;
                                        _editController.text = item;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final result = await firestore
                                          .removeGrocery(user.uid, item);
                                      ref.refresh(groceriesProvider);
                                      if (result.error != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Error removing item: ${result.error}'),
                                              backgroundColor: Colors.red),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Item removed'),
                                              backgroundColor: Colors.green),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HomePage displays a personalized welcome and today's meal plan and grocery summary.
class HomePage extends ConsumerWidget {
  String _todayName() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    // DateTime.weekday: 1=Monday, ..., 7=Sunday
    return days[now.weekday - 1];
  }

  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final mealPlanAsync = ref.watch(mealPlanProvider);
    final groceriesAsync = ref.watch(groceriesProvider);
    final today = _todayName();
    return Scaffold(
      appBar: AppBar(
        title: userAsync.when(
          data: (user) => Text('Welcome, ${user?.name ?? 'User'}'),
          loading: () => const Text('Loading...'),
          error: (e, _) => const Text('Welcome'),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user != null)
                    Text('Hello, ${user.name}!',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  if (user == null) const Text('No user data found.'),
                  const SizedBox(height: 24),
                  const Text("Today's Meal Plan:",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: mealPlanAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                        data: (mealPlan) {
                          final meals = mealPlan[today] ?? [];
                          if (meals.isEmpty) {
                            return const Text('No meals planned for today.');
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final meal in meals)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(meal,
                                      style: const TextStyle(fontSize: 16)),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("Your Grocery List:",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: groceriesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                        data: (groceries) {
                          if (groceries.isEmpty) {
                            return const Text('No grocery items.');
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in groceries)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(item,
                                      style: const TextStyle(fontSize: 16)),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/ai-assistant'),
                      icon: const Icon(Icons.smart_toy),
                      label: const Text('Ask AI Assistant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5B42),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// MealPlanPage displays and manages the full weekly meal plan with add/delete functionality.
class MealPlanPage extends ConsumerStatefulWidget {
  const MealPlanPage({super.key});

  @override
  ConsumerState<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends ConsumerState<MealPlanPage> {
  final _mealController = TextEditingController();
  String? _selectedDay;
  bool _adding = false;
  String? _error;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _days[0]; // Default to Monday
  }

  @override
  void dispose() {
    _mealController.dispose();
    super.dispose();
  }

  Future<void> _addMeal() async {
    final meal = _mealController.text.trim();
    if (meal.isEmpty || _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meal and select a day'), backgroundColor: Colors.red),
      );
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    final firestore = ref.read(firestoreServiceProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _adding = true;
      _error = null;
    });

    final result = await firestore.addMeal(user.uid, _selectedDay!, meal);
    setState(() {
      _adding = false;
      _mealController.clear();
      _error = result.error;
    });

    ref.refresh(mealPlanProvider);

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding meal: ${result.error}'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal added successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _removeMeal(String day, String meal) async {
    final user = ref.read(authStateProvider).asData?.value;
    final firestore = ref.read(firestoreServiceProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in'), backgroundColor: Colors.red),
      );
      return;
    }

    final result = await firestore.removeMeal(user.uid, day, meal);
    ref.refresh(mealPlanProvider);

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing meal: ${result.error}'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal removed successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanAsync = ref.watch(mealPlanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Add meal section
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDay,
                    decoration: const InputDecoration(labelText: 'Select Day'),
                    items: _days.map((day) {
                      return DropdownMenuItem<String>(
                        value: day,
                        child: Text(day),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDay = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _mealController,
                    decoration: const InputDecoration(labelText: 'Add meal'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _adding ? null : _addMeal,
                  child: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            // Meal plan list
            Expanded(
              child: mealPlanAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (mealPlan) {
                  if (mealPlan.isEmpty) {
                    return const Center(child: Text('No meal plan available.'));
                  }
                  return ListView(
                    children: [
                      const Text('Weekly Meal Plan',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      for (final entry in mealPlan.entries)
                        Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                if (entry.value.isEmpty)
                                  const Text('No meals planned.')
                                else
                                  for (final meal in entry.value)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(meal, style: const TextStyle(fontSize: 16)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _removeMeal(entry.key, meal),
                                          ),
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ProfilePage displays and allows editing of user info, and allows logout.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _dietaryController = TextEditingController();
  final _goalsController = TextEditingController();
  bool _editing = false;
  String? _feedback;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dietaryController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data found.'));
          }
          if (!_editing) {
            final appUser = user;
            _nameController.text = appUser.name;
            _dietaryController.text = appUser.dietaryNeeds.length >= 3
                ? appUser.dietaryNeeds.sublist(0, 3).join(', ')
                : appUser.dietaryNeeds.join(', ');
            _goalsController.text = appUser.healthGoals.length >= 3
                ? appUser.healthGoals.sublist(0, 3).join(', ')
                : appUser.healthGoals.join(', ');
          }
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              children: [
                const Text('Profile Details',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  enabled: _editing,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _dietaryController,
                  enabled: _editing,
                  decoration: const InputDecoration(
                    labelText: 'Dietary Needs (comma separated)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _goalsController,
                  enabled: _editing,
                  decoration: const InputDecoration(
                    labelText: 'Health Goals (comma separated)',
                  ),
                ),
                const SizedBox(height: 24),
                if (_feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(_feedback!,
                        style: const TextStyle(color: Colors.green)),
                  ),
                if (_editing)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  setState(() {
                                    _saving = true;
                                    _feedback = null;
                                  });
                                  final updated = user.copyWith(
                                    name: _nameController.text.trim(),
                                    dietaryNeeds: _dietaryController.text
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList(),
                                    healthGoals: _goalsController.text
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList(),
                                  );
                                  // Ensure uid is set correctly
                                  if (user.uid.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('User ID is empty. Cannot save profile.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    setState(() {
                                      _saving = false;
                                    });
                                    return;
                                  }
                                  final result = await ref
                                      .read(firestoreServiceProvider)
                                      .setUser(updated);
                                  setState(() {
                                    _saving = false;
                                    _editing = false;
                                    _feedback = result.error ?? 'Profile updated!';
                                  });
                                  ref.refresh(userProvider);
                                  if (result.error != null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error updating profile: ${result.error}'),
                                          backgroundColor: Colors.red),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text('Profile updated!'),
                                          backgroundColor: Colors.green),
                                    );
                                  }
                                },
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _editing = false;
                                    _feedback = null;
                                  });
                                },
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _editing = true;
                        _feedback = null;
                        _nameController.text = user.name;
                        _dietaryController.text = user.dietaryNeeds.join(', ');
                        _goalsController.text = user.healthGoals.join(', ');
                      });
                    },
                    child: const Text('Edit Profile'),
                  ),
                const SizedBox(height: 32),
                // Settings Section
                const Divider(),
                const Text('Settings',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Dark Theme'),
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state =
                        val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
                SwitchListTile(
                  title: const Text('Notifications'),
                  value: ref.watch(notificationsEnabledProvider),
                  onChanged: (val) {
                    ref.read(notificationsEnabledProvider.notifier).state = val;
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
