import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MentoraTraining.db";
  static const _databaseVersion = 3;

  static const tableMaterials = 'materials';
  static const tableChunks = 'training_data_chunks';
  static const tableQuestionBundles = 'question_bundles';
  static const tableStudySessions = 'study_sessions';

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
  static const columnPageNumber = 'page_number';
  static const columnContent = 'content';
  static const columnSourceType = 'source_type';

  // question bundles columns
  static const columnBundleId = 'id';
  static const columnBundleMaterialId = 'material_id';
  static const columnBundleCreatedAt = 'created_at';
  static const columnBundleParams = 'params';
  static const columnBundleQuestions = 'questions';

  // study sessions columns
  static const columnSessionId = 'id';
  static const columnSessionBundleId = 'bundle_id';
  static const columnSessionCreatedAt = 'created_at';
  static const columnSessionAnswers = 'answers';
  static const columnSessionEvaluation = 'evaluation';

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
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tableChunks ADD COLUMN $columnPageNumber INTEGER DEFAULT 1');
      await db.execute('''
          CREATE TABLE $tableQuestionBundles (
            $columnBundleId TEXT PRIMARY KEY,
            $columnBundleMaterialId TEXT NOT NULL,
            $columnBundleCreatedAt INTEGER NOT NULL,
            $columnBundleParams TEXT NOT NULL,
            $columnBundleQuestions TEXT NOT NULL,
            FOREIGN KEY($columnBundleMaterialId) REFERENCES $tableMaterials($columnId) ON DELETE CASCADE
          )
          ''');
      await db.execute('''
          CREATE TABLE $tableStudySessions (
            $columnSessionId TEXT PRIMARY KEY,
            $columnSessionBundleId TEXT NOT NULL,
            $columnSessionCreatedAt INTEGER NOT NULL,
            $columnSessionAnswers TEXT NOT NULL,
            $columnSessionEvaluation TEXT NOT NULL,
            FOREIGN KEY($columnSessionBundleId) REFERENCES $tableQuestionBundles($columnBundleId) ON DELETE CASCADE
          )
          ''');
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
            $columnPageNumber INTEGER DEFAULT 1,
            $columnContent TEXT NOT NULL,
            $columnSourceType TEXT NOT NULL,
            FOREIGN KEY($columnMaterialId) REFERENCES $tableMaterials($columnId) ON DELETE CASCADE
          )
          ''');
          
    await db.execute('''
          CREATE TABLE $tableQuestionBundles (
            $columnBundleId TEXT PRIMARY KEY,
            $columnBundleMaterialId TEXT NOT NULL,
            $columnBundleCreatedAt INTEGER NOT NULL,
            $columnBundleParams TEXT NOT NULL,
            $columnBundleQuestions TEXT NOT NULL,
            FOREIGN KEY($columnBundleMaterialId) REFERENCES $tableMaterials($columnId) ON DELETE CASCADE
          )
          ''');
          
    await db.execute('''
          CREATE TABLE $tableStudySessions (
            $columnSessionId TEXT PRIMARY KEY,
            $columnSessionBundleId TEXT NOT NULL,
            $columnSessionCreatedAt INTEGER NOT NULL,
            $columnSessionAnswers TEXT NOT NULL,
            $columnSessionEvaluation TEXT NOT NULL,
            FOREIGN KEY($columnSessionBundleId) REFERENCES $tableQuestionBundles($columnBundleId) ON DELETE CASCADE
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

  Future<void> insertQuestionBundle(Map<String, dynamic> row) async {
    Database db = await instance.database;
    await db.insert(tableQuestionBundles, row);
  }

  Future<void> updateQuestionBundle(String bundleId, Map<String, dynamic> row) async {
    Database db = await instance.database;
    await db.update(
      tableQuestionBundles,
      row,
      where: '$columnBundleId = ?',
      whereArgs: [bundleId],
    );
  }

  Future<List<Map<String, dynamic>>> getQuestionBundlesForMaterial(String materialId) async {
    Database db = await instance.database;
    return await db.query(tableQuestionBundles,
        where: '$columnBundleMaterialId = ?',
        whereArgs: [materialId],
        orderBy: '$columnBundleCreatedAt DESC');
  }

  Future<void> insertStudySession(Map<String, dynamic> row) async {
    Database db = await instance.database;
    await db.insert(tableStudySessions, row);
  }

  Future<List<Map<String, dynamic>>> getStudySessionsForBundle(String bundleId) async {
    Database db = await instance.database;
    return await db.query(tableStudySessions,
        where: '$columnSessionBundleId = ?',
        whereArgs: [bundleId],
        orderBy: '$columnSessionCreatedAt DESC');
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

  Future<void> deleteQuestionBundle(String bundleId) async {
    Database db = await instance.database;
    await db.delete(
      tableQuestionBundles,
      where: '$columnBundleId = ?',
      whereArgs: [bundleId],
    );
  }
}
