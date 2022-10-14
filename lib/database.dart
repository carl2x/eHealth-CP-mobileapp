/*
 * This class handles database operations.
 */
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_config/flutter_config.dart';
import 'package:crypt/crypt.dart';
import 'dart:math';
import 'dart:convert';

class MongoDB {
  // Global static database and collection objects.
  static var db, userCollection, patientCollection;

  static Future cleanupDatabase() async {
    await db.close();
  }

  /*
   * @Parameters: integer for the length of the random string.
   * @Return: a random string (salt).
   */
  static String getSalt(int len) {
    var random = Random.secure();
    var values = List<int>.generate(len, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  /*
   * @Parameters: string for password, string for salt.
   * @Return: a hashed and salted password. 
   * Each user's password should have its unique salt.
   */
  static String hashPassWithSalt(String password, String salt) {
    final secure = Crypt.sha256(password, salt: salt, rounds: 1000);
    return secure.toString();
  }

  static connect() async {
    print(FlutterConfig.get('MONGO_CONN_URL'));
    db = await Db.create(FlutterConfig.get('MONGO_CONN_URL'));
    await db.open();
    userCollection = db.collection(FlutterConfig.get('USER_COLLECTION'));
    patientCollection = db.collection(FlutterConfig.get('PATIENT_COLLECTION'));

    if (!db.masterConnection.serverCapabilities.supportsOpMsg) {
      return;
    }
  }

  static Future<bool> existUser(String name) async {
    if (await userCollection.findOne(where.eq('name', name)) != null) {
      return true;
    }
    return false;
  }

  static Future<Map<String, dynamic>> findUser(String name) async {
    var res = await userCollection.findOne(where.eq('name', name));
    return res;
  }

  static updateUser(String name, String password, String salt) async {
    var user = await findUser(name);
    user['password'] = password;
    user['salt'] = salt;
    await userCollection.save(user);
  }

  static createUser(String name, String password, String salt) async {
    await userCollection.insertOne({
      '_id': ObjectId(),
      'name': name,
      'password': password,
      'salt': salt,
    });
  }

  static createPatient(String name, String age, String dob) async {
    await patientCollection.insertOne({
      '_id': ObjectId(),
      'name': name,
      'address': '',
      'age': age,
      'dob': dob,
      'appointment_day': '',
      'chest': '',
      'contact_1': '',
      'contact_2': '',
      'coords': [0, 0],
      //FieldValue.arrayUnion([0, 0]),
      'gender_id': '',
      'medical_history': '',
      'overall': '',
      'priority': 3,
      'program': '',
      'race': '',
      'start_date': '',
      'stomach': '',
      'zone': 0,
    });
  }

  static deletePatient(String name) async {
    await patientCollection.deleteOne({'name': name});
  }

  static deleteUser(String name) async {
    await userCollection.deleteOne({'name': name});
  }

  static test() async {
    await db.dropCollection('patients');
    await db.dropCollection('users');
    patientCollection = db.collection('patients');
    userCollection = db.collection('users');

    var ret = await patientCollection.insertMany(<Map<String, dynamic>>[
      {'_id': 1, 'name': 'JACK', 'state': 'active', 'rating': 100, 'score': 5},
      {'_id': 2, 'name': 'William', 'state': 'busy', 'rating': 80, 'score': 4},
      {'_id': 3, 'name': 'Liz', 'state': 'on hold', 'rating': 70, 'score': 8},
      {'_id': 4, 'name': 'George', 'state': 'active', 'rating': 95, 'score': 8},
      {'_id': 5, 'name': 'Jim', 'state': 'idle', 'rating': 40, 'score': 3},
      {'_id': 6, 'name': 'Laureen', 'state': 'busy', 'rating': 87, 'score': 8},
      {'_id': 7, 'name': 'John', 'state': 'idle', 'rating': 72, 'score': 7}
    ]);

    await createPatient('JAMIE', '19', '03/07/2001');
    String salt = getSalt(10);
    String password = hashPassWithSalt("password", salt);
    await createUser('BOB', password, salt);
    await updateUser('BOB', 'testpass', 'salty');
    if (!ret.isSuccess) {
      print('Error detected in record insertion');
    }

    var res = await patientCollection
        .findOne(where.eq('name', 'Liz').gt('rating', 7));

    print('First document fetched: ${res['name']} - ${res['state']}');
    await cleanupDatabase();
  }
}