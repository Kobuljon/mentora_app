import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MentoraTraining.db";
  static const _databaseVersion = 2;

  static const tableMaterials = 'materials';
  static const tableChunks = 'training_data_chunks';

  // materials columns
  static const columnId = 'id';
  static const columnFilename = 'filename';
  static const columnType = 'type';
  static const columnStatus = 'status';
  static const columnCreatedAt = 'created_at';

  // chunks columns
  static const columnChunkId = 'id';
  static const columnMaterialId = 'material_id';
  static const columnChunkIndex = 'chunk_index';
  static const columnContent = 'content';
  static const columnSourceType = 'source_type';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, 
        onCreate: _onCreate,
        onUpgrade: _onUpgrade);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableMaterials ADD COLUMN $columnStatus TEXT DEFAULT "processed"');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $tableMaterials (
            $columnId TEXT PRIMARY KEY,
            $columnFilename TEXT NOT NULL,
            $columnType TEXT NOT NULL,
            $columnStatus TEXT DEFAULT 'processing',
            $columnCreatedAt INTEGER NOT NULL
          )
          ''');
    
    await db.execute('''
          CREATE TABLE $tableChunks (
            $columnChunkId TEXT PRIMARY KEY,
            $columnMaterialId TEXT NOT NULL,
            $columnChunkIndex INTEGER NOT NULL,
            $columnContent TEXT NOT NULL,
            $columnSourceType TEXT NOT NULL,
            FOREIGN KEY($columnMaterialId) REFERENCES $tableMaterials($columnId) ON DELETE CASCADE
          )
          ''');
  }

  Future<void> insertMaterial(Map<String, dynamic> row) async {
    Database db = await instance.database;
    await db.insert(tableMaterials, row);
  }

  Future<void> insertChunk(Map<String, dynamic> row) async {
    Database db = await instance.database;
    await db.insert(tableChunks, row);
  }

  Future<void> updateMaterialStatus(String id, String status) async {
    Database db = await instance.database;
    await db.update(
      tableMaterials,
      {columnStatus: status},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllMaterials() async {
    Database db = await instance.database;
    return await db.query(tableMaterials, orderBy: '$columnCreatedAt DESC');
  }

  Future<List<Map<String, dynamic>>> getChunksForMaterial(String materialId) async {
    Database db = await instance.database;
    return await db.query(tableChunks,
        where: '$columnMaterialId = ?',
        whereArgs: [materialId],
        orderBy: '$columnChunkIndex ASC');
  }

  Future<void> deleteChunk(String chunkId) async {
    Database db = await instance.database;
    await db.delete(
      tableChunks,
      where: '$columnChunkId = ?',
      whereArgs: [chunkId],
    );
  }

  Future<void> deleteMaterial(String materialId) async {
    Database db = await instance.database;
    await db.delete(
      tableChunks,
      where: '$columnMaterialId = ?',
      whereArgs: [materialId],
    );
    await db.delete(
      tableMaterials,
      where: '$columnId = ?',
      whereArgs: [materialId],
    );
  }
}
