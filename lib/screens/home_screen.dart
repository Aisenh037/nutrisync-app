import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// MealPlanPage displays and manages the user's meal plan for the week.
class MealPlanPage extends ConsumerStatefulWidget {
  const MealPlanPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends ConsumerState<MealPlanPage> {
  String? _editingMeal;
  final TextEditingController _editMealController = TextEditingController();
  String? _editingMeal;
  final TextEditingController _editMealController = TextEditingController();
  @override
  void dispose() {
    _mealController.dispose();
    _editMealController.dispose();
    super.dispose();
  }
  late String _selectedDay;
  final TextEditingController _mealController = TextEditingController();
  bool _adding = false;
  String? _error;

  static const List<String> _days = [
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
    _selectedDay = _days[DateTime.now().weekday - 1];
  }

  @override
  void dispose() {
    _mealController.dispose();
    _editMealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanAsync = ref.watch(mealPlanProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final firestore = ref.read(firestoreServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Day:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedDay,
                  items: _days
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDay = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mealController,
                    decoration: InputDecoration(
                      labelText: 'Add meal',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _addMeal(user, firestore),
                  ),
                ),
                const SizedBox(width: 8),
                _adding
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _adding
                            ? null
                            : () {
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Not signed in'),
                                        backgroundColor: Colors.red),
                                  );
                                } else {
                                  _addMeal(user, firestore);
                                }
                              },
                        child: const Text('Add'),
                      ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: mealPlanAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (mealPlan) {
                  final meals = mealPlan[_selectedDay] ?? [];
                  if (meals.isEmpty) {
                    return const Center(
                        child: Text('No meals planned for this day.'));
                  }
                  return ListView.separated(
                    itemCount: meals.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final meal = meals[i];
                      final isEditing = _editingMeal == meal;
                      return ListView.separated(
                        itemCount: meals.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final meal = meals[i];
                          final isEditing = _editingMeal == meal;
                          return ListTile(
                            title: isEditing
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _editMealController,
                                          autofocus: true,
                                          onSubmitted: (newMeal) async {
                                            await _saveEditedMeal(user, firestore, meal, newMeal);
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        onPressed: () async {
                                          await _saveEditedMeal(user, firestore, meal, _editMealController.text.trim());
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _editingMeal = null;
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
                                              _editingMeal = meal;
                                              _editMealController.text = meal;
                                            });
                                          },
                                    child: Text(meal),
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
                                            _editingMeal = meal;
                                            _editMealController.text = meal;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final result = await firestore.removeMeal(
                                              user.uid, _selectedDay, meal);
                                          // ignore: unused_result
                                          ref.refresh(mealPlanProvider);
                                          if (result.error != null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Error removing meal: ${result.error}'),
                                                  backgroundColor: Colors.red),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text('Meal removed'),
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

      Future<void> _saveEditedMeal(User? user, dynamic firestore, String oldMeal, String newMeal) async {
        if (user == null) return;
        if (newMeal.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal cannot be empty'), backgroundColor: Colors.red),
          );
          return;
        }
        if (oldMeal == newMeal) {
          setState(() {
            _editingMeal = null;
          });
          return;
        }
        // Remove old meal, add new meal
        final removeResult = await firestore.removeMeal(user.uid, _selectedDay, oldMeal);
        if (removeResult.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing meal: ${removeResult.error}'), backgroundColor: Colors.red),
          );
          return;
        }
        final addResult = await firestore.addMeal(user.uid, _selectedDay, newMeal);
        if (addResult.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing meal: ${addResult.error}'), backgroundColor: Colors.red),
          );
          return;
        }
        // ignore: unused_result
        ref.refresh(mealPlanProvider);
        setState(() {
          _editingMeal = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal updated!'), backgroundColor: Colors.green),
        );
      }
                                child: Text(meal),
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
                                        _editingMeal = meal;
                                        _editMealController.text = meal;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final result = await firestore.removeMeal(
                                          user.uid, _selectedDay, meal);
                                      // ignore: unused_result
                                      ref.refresh(mealPlanProvider);
                                      if (result.error != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Error removing meal: ${result.error}'),
                                              backgroundColor: Colors.red),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Meal removed'),
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
@@ class _MealPlanPageState extends ConsumerState<MealPlanPage> {

  Future<void> _saveEditedMeal(User? user, dynamic firestore, String oldMeal, String newMeal) async {
    if (user == null) return;
    if (newMeal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }
    if (oldMeal == newMeal) {
      setState(() {
        _editingMeal = null;
      });
      return;
    }
    // Remove old meal, add new meal
    final removeResult = await firestore.removeMeal(user.uid, _selectedDay, oldMeal);
    if (removeResult.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing meal: ${removeResult.error}'), backgroundColor: Colors.red),
      );
      return;
    }
    final addResult = await firestore.addMeal(user.uid, _selectedDay, newMeal);
    if (addResult.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing meal: ${addResult.error}'), backgroundColor: Colors.red),
      );
      return;
    }
    // ignore: unused_result
    ref.refresh(mealPlanProvider);
    setState(() {
      _editingMeal = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal updated!'), backgroundColor: Colors.green),
    );
  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMeal(User? user, dynamic firestore) async {
    setState(() {
      _error = null;
      _adding = true;
    });
    final meal = _mealController.text.trim();
    if (meal.isEmpty) {
      setState(() {
        _error = 'Meal cannot be empty';
        _adding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Meal cannot be empty'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (user == null) {
      setState(() {
        _error = 'Not signed in';
        _adding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Not signed in'), backgroundColor: Colors.red),
      );
      return;
    }
    final result = await firestore.addMeal(user.uid, _selectedDay, meal);
    if (result.error != null) {
      setState(() {
        _error = result.error;
        _adding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error adding meal: ${result.error}'),
            backgroundColor: Colors.red),
      );
      return;
    }
    _mealController.clear();
    setState(() => _adding = false);
  // ignore: unused_result
  ref.refresh(mealPlanProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Meal added'), backgroundColor: Colors.green),
    );
  }
}

/// HomePage displays a personalized welcome and today's meal plan.
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null)
                  Text('Hello, ${user.name}!',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                if (user == null)
                  const Text('No user data found.'),
                const SizedBox(height: 24),
                Text("Today's Meal Plan:",
                    style: const TextStyle(
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
              ],
            ),
          );
        },
      ),
    );
  }
}

/// GroceriesPage displays and manages the user's grocery list.
class GroceriesPage extends ConsumerStatefulWidget {
  const GroceriesPage({super.key});

  @override
  ConsumerState<GroceriesPage> createState() => _GroceriesPageState();
}

class _GroceriesPageState extends ConsumerState<GroceriesPage> {
  final _itemController = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
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
                          // ignore: unused_result
                          // ignore: unused_result
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
                      return ListTile(
                        title: Text(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: user == null
                              ? null
                              : () async {
                                  final result = await firestore
                                      .removeGrocery(user.uid, item);
                                  // ignore: unused_result
                                  // ignore: unused_result
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
            final appUser = user; // Use the actual user model type if needed, e.g., 'as AppUser'
            _nameController.text = appUser.name;
            _dietaryController.text = appUser.dietaryNeeds.join(', ');
            _goalsController.text = appUser.healthGoals.join(', ');
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
                                  final result = await ref
                                      .read(firestoreServiceProvider)
                                      .setUser(updated);
                                  setState(() {
                                    _saving = false;
                                    _editing = false;
                                    _feedback = result.error ?? 'Profile updated!';
                                  });
                                  // ignore: unused_result
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