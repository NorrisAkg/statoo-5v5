import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

Map<String,dynamic> snapshot() => {
  'name':'Audit','members':[{'id':'a','name':'Alice','is_active':1}],
  'documents':<String,dynamic>{},'account':{'id':'admin','roles':['ADMIN'],'shared':false},
};
class RejectedFirstService extends SharedService {
  RejectedFirstService(super.database) {
    identity={'group_id':'audit','account':{'id':'admin','roles':['ADMIN'],'shared':false}};
  }
  final sent=<String>[];
  @override
  Future<Map<String,dynamic>> request(String method,String path,[Object? body]) async {
    if(method=='GET')return snapshot();
    final event=body! as Map;
    sent.add(event['operation_id'] as String);
    if(event['operation_id']=='first')throw const SharedApiException(403,'Droit retiré');
    return {'status':'accepted','revision':1};
  }
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll((){sqfliteFfiInit();databaseFactory=databaseFactoryFfi;});
  late Database db;
  late AppDatabase app;
  setUp(()async{
    db=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    app=AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
  });
  tearDown(()async{await db.close();});
  test('AUD-15 local member edits survive automatic snapshot until explicit publication',()async{
    final service=SharedService(app)..identity={'group_id':'audit'};
    await service.importSnapshot(snapshot());
    await db.update('players',{'name':'Alice corrigée','is_active':0},where:'id=?',whereArgs:['a']);
    await service.importSnapshot(snapshot());
    final row=(await db.query('players')).single;
    expect(row['name'],'Alice corrigée');
    expect(row['is_active'],0);
  });
  test('AUD-16 refused first operation does not silently block independent next operation',()async{
    final service=RejectedFirstService(app);
    for(final id in ['first','second']){
      await db.insert('meta',{'key':'outbox_$id','value':jsonEncode({
        'operation_id':id,'occurrence_id':id,'domain':'sport','group_id':'audit',
        'actor':'admin','status':'pending','local_session_id':id,'base_revision':0,
        'generation':0,'payload':<String,dynamic>{},'reason':'audit',
      })});
    }
    try{await service.synchronize();}catch(_){}
    expect(service.sent,contains('second'));
    expect(service.syncWarning,isNotNull);
  });
}
