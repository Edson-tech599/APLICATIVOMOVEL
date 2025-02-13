import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// --- Database Helper ---
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('planets.db');
    return _database!;
  }

  Future<Database> _initDB(String path) async {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, path);
    return await openDatabase(fullPath, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE planets (
        id $idType,
        name $textType,
        distance_from_sun $realType,
        size $realType,
        nickname $textType
      )
    ''');
  }

  Future<int> createPlanet(Map<String, dynamic> planet) async {
    final db = await instance.database;
    return await db.insert('planets', planet);
  }

  Future<List<Map<String, dynamic>>> getPlanets() async {
    final db = await instance.database;
    return await db.query('planets');
  }

  Future<int> updatePlanet(Map<String, dynamic> planet) async {
    final db = await instance.database;
    return await db.update(
      'planets',
      planet,
      where: 'id = ?',
      whereArgs: [planet['id']],
    );
  }

  Future<int> deletePlanet(int id) async {
    final db = await instance.database;
    return await db.delete(
      'planets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> planets;

  @override
  void initState() {
    super.initState();
    planets = DatabaseHelper.instance.getPlanets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Planets CRUD')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: planets,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No planets found'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                var planet = snapshot.data![index];
                return ListTile(
                  title: Text(planet['name']),
                  subtitle: Text(planet['nickname'] ?? 'No nickname'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanetDetailScreen(planet: planet),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PlanetDetailScreen()),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}

// --- Planet Detail Screen ---
class PlanetDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? planet;

  PlanetDetailScreen({this.planet});

  @override
  _PlanetDetailScreenState createState() => _PlanetDetailScreenState();
}

class _PlanetDetailScreenState extends State<PlanetDetailScreen> {
  final _nameController = TextEditingController();
  final _distanceController = TextEditingController();
  final _sizeController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.planet != null) {
      _nameController.text = widget.planet!['name'];
      _distanceController.text = widget.planet!['distance_from_sun'].toString();
      _sizeController.text = widget.planet!['size'].toString();
      _nicknameController.text = widget.planet!['nickname'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.planet == null ? 'Add Planet' : 'Edit Planet')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Planet Name'),
            ),
            TextField(
              controller: _distanceController,
              decoration: InputDecoration(labelText: 'Distance from Sun (AU)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _sizeController,
              decoration: InputDecoration(labelText: 'Size (km)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(labelText: 'Nickname'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isEmpty || _distanceController.text.isEmpty || _sizeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all required fields')));
                  return;
                }

                final planet = {
                  'name': _nameController.text,
                  'distance_from_sun': double.parse(_distanceController.text),
                  'size': double.parse(_sizeController.text),
                  'nickname': _nicknameController.text,
                };

                if (widget.planet == null) {
                  await DatabaseHelper.instance.createPlanet(planet);
                } else {
                  planet['id'] = widget.planet!['id'];
                  await DatabaseHelper.instance.updatePlanet(planet);
                }

                Navigator.pop(context);
              },
              child: Text(widget.planet == null ? 'Add Planet' : 'Update Planet'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Main ---
void main() {
  runApp(MaterialApp(home: HomeScreen()));
}
