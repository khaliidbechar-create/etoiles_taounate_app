import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EtoilesTaounateApp());
}

class EtoilesTaounateApp extends StatelessWidget {
  const EtoilesTaounateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Les Étoiles de Taounate',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', ''),
      supportedLocales: const [Locale('ar', '')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Database? _db;
  List<Map<String, dynamic>> _joueurs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'etoiles_taounate.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE joueurs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT,
            prenom TEXT,
            date_naissance TEXT,
            tuteur TEXT,
            telephone TEXT,
            montant REAL,
            pack_recu INTEGER,
            taille_pack TEXT
          )
        ''');
      },
    );
    _loadJoueurs();
  }

  Future<void> _loadJoueurs() async {
    if (_db == null) return;
    final list = await _db!.query('joueurs', orderBy: 'id DESC');
    setState(() {
      _joueurs = list;
      _isLoading = false;
    });
  }

  Future<void> _importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = excel_lib.Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        for (int i = 2; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.isEmpty || row[0]?.value == null) continue;

          String prenom = row[0]?.value?.toString() ?? '';
          String nom = row[1]?.value?.toString() ?? '';
          String dateNaissance = row[2]?.value?.toString() ?? '';
          String tuteur = row[5]?.value?.toString() ?? '';
          String phone = row[6]?.value?.toString() ?? '';
          double montant = double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;
          String pack = row[8]?.value?.toString() ?? 'لا';
          String taille = row[9]?.value?.toString() ?? '';

          await _db?.insert('joueurs', {
            'nom': nom,
            'prenom': prenom,
            'date_naissance': dateNaissance,
            'tuteur': tuteur,
            'telephone': phone,
            'montant': montant,
            'pack_recu': pack.contains('نعم') ? 1 : 0,
            'taille_pack': taille,
          });
        }
      }
      _loadJoueurs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer)),
            const SizedBox(width: 10),
            const Text('مدرسة النجوم الرياضية تاونات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'استيراد ملف Excel',
            onPressed: _importExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _joueurs.isEmpty
              ? const Center(child: Text('لا يوجد لاعبين مسجلين. قم باستيراد ملف Excel.'))
              : ListView.builder(
                  itemCount: _joueurs.length,
                  itemBuilder: (context, index) {
                    final j = _joueurs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${j['id']}'),
                        ),
                        title: Text('${j['prenom']} ${j['nom']}'),
                        subtitle: Text('ولي الأمر: ${j['tuteur']} | الهاتف: ${j['telephone']}'),
                        trailing: Column(
                          mainCenter: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${j['montant']} DH', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('Pack: ${j['pack_recu'] == 1 ? "نعم (${j['taille_pack']})" : "لا"}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
