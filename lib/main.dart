import 'dart:async';

import 'package:flutter/material.dart';
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:localstore/localstore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final BehaviorSubject<String> selectNotificationSubject =
BehaviorSubject<String>();


class Entry{
  final String id;
  String keyword;
  String description;
  List<int> channelIds;
  Entry(this.id, this.keyword, this.description, this.channelIds);

  Map<String, dynamic> toMap() {
    return{
      "id": id,
      "keyword": keyword,
      "description": description,
      "channelIds": channelIds,
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map){
    return Entry(
        map["id"],
        map["keyword"],
        map["description"],
        map["channelIds"].cast<int>()
    );
  }
}

extension ExtEntry on Entry{
  Future save() async{
    final _db = Localstore.instance;
    return _db.collection("entries").doc(id).set(toMap());
  }
  Future delete() async{
    final _db = Localstore.instance;
    return _db.collection("entries").doc(id).delete();
  }
}

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  var androidInitilize = new AndroidInitializationSettings('app_icon');
  var iOSinitilize = new IOSInitializationSettings();
  var initilizationsSettings = new InitializationSettings(
      android: androidInitilize, iOS: iOSinitilize);
  flutterLocalNotificationsPlugin.initialize(initilizationsSettings, onSelectNotification: notificationSelected);
  runApp(MyApp());
}

Future notificationSelected(String payload) async {
  selectNotificationSubject.add(payload);
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memorizer',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Memorizer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _entries = <String, Entry>{};
  final db = Localstore.instance;
  StreamSubscription<Map<String, dynamic>> _subscription;
  @override
  void initState(){
    super.initState();

    selectNotificationSubject.stream.listen((String payload) async {
      Route route = MaterialPageRoute(builder: (context) => AnswerPage(payload));
      await Navigator.push(context, route);
    });

    //save mock entry
    /*
    final id = Localstore.instance.collection("entries").doc().id;
    final entry = Entry(id, "mock", "mock", [1, 2, 3, 4]);
    entry.save();

     */


    final stream = db.collection("entries").stream;
    _subscription = stream.listen((event) {
      setState(() {
        final item = Entry.fromMap(event);
        _entries.putIfAbsent(item.id, () => item);
      });
    });
  }

  @override
  void dispose() {
    selectNotificationSubject.close();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: _entries.keys.length,
          itemBuilder: (context, index) {
            final key = _entries.keys.elementAt(index);
            final item = _entries[key];
            return _row(item);
          },),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Route route = MaterialPageRoute(builder: (context) => CreateEntryPage());
          await Navigator.push(context, route);
          setState((){});
        },
        tooltip: 'Add new entry',
        child: Icon(Icons.add),
      ),
    );
  }


  Widget _row(Entry e){
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.keyword, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(e.description, style: TextStyle(color: Colors.black54)),
                      ),
                    ],
                  ),
                  InkWell(child: Icon(Icons.delete, color: Colors.deepOrange),
                    onTap: (){
                      setState(() {
                        e.delete();
                        _entries.remove(e.id);
                        for(var i = 0; i < 15; i++){
                          flutterLocalNotificationsPlugin.cancel(e.channelIds[i]);
                        }
                      });
                    },)
                ],
              ),
            )
        )
    );
  }
}

class CreateEntryPage extends StatefulWidget{
  @override
  _CreateEntryPageState createState() => _CreateEntryPageState();
}

class _CreateEntryPageState extends State<CreateEntryPage>{
  var keywordController = TextEditingController();
  var descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    keywordController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Entry"),
      ),
      body: Center(
          child: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 30, right: 30),
              child: Form(
                  key: _formKey,
                  child: Column(
                    children: [_keywordField(), _descriptionField(), _createButton()],
                  )
              )
          )
      ),
    );
  }

  _keywordField(){
    return TextFormField(
      validator: (value){
        if(value.isEmpty){
          return "Keyword is necessary";
        }
        return null;
      },
      controller: keywordController,
      decoration: InputDecoration(hintText: "Keyword"),
    );
  }

  _descriptionField(){
    return TextFormField(
      validator: (value){
        if(value.isEmpty){
          return "Description is necessary";
        }
        return null;
      },
      controller: descriptionController,
      decoration: InputDecoration(hintText: "Description"),
    );
  }

  _createButton(){
    return TextButton(onPressed: () async {
      //save entry to db
      final id = Localstore.instance.collection("entries").doc().id;
      final channelList = await createIdList();
      final entry = Entry(id, keywordController.text, descriptionController.text, channelList);
      entry.save();
      //create schedule
      await _showNotification(channelList[0],Duration(seconds: 1), entry.keyword, entry.description, );
      await _showNotification(channelList[1],Duration(minutes: 1), entry.keyword, entry.description, );
      await _showNotification(channelList[2],Duration(minutes: 15), entry.keyword, entry.description, );
      await _showNotification(channelList[3],Duration(hours: 1), entry.keyword, entry.description, );
      await _showNotification(channelList[4],Duration(hours: 4), entry.keyword, entry.description, );
      await _showNotification(channelList[5],Duration(hours: 12), entry.keyword, entry.description, );
      await _showNotification(channelList[6],Duration(days: 1), entry.keyword, entry.description, );
      await _showNotification(channelList[7],Duration(days: 2), entry.keyword, entry.description, );
      await _showNotification(channelList[8],Duration(days: 4), entry.keyword, entry.description, );
      await _showNotification(channelList[9],Duration(days: 7), entry.keyword, entry.description, );
      await _showNotification(channelList[10],Duration(days: 14), entry.keyword, entry.description, );
      await _showNotification(channelList[11],Duration(days: 30), entry.keyword, entry.description, );
      await _showNotification(channelList[12],Duration(days: 90), entry.keyword, entry.description, );
      await _showNotification(channelList[13],Duration(days: 180), entry.keyword, entry.description, );
      await _showNotification(channelList[14],Duration(seconds: 360), entry.keyword, entry.description, );
      //navigator pop
      Navigator.pop(context);
    }, child: Text("Create"));
  }

  Future<List<int>> createIdList() async{
    final prefs = await SharedPreferences.getInstance();
    final key = "channelcount";
    final length = prefs.getInt(key) ?? 0;
    prefs.setInt(key, length + 15);
    List<int> lst = <int>[];
    for(var i = 0; i < 15; i++){
      lst.add(length + i);
    }
    return lst;
  }

  Future _showNotification(int id, Duration duration, String keyword, String payload) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        "remember",
        keyword,
        tz.TZDateTime.now(tz.local).add(duration),
        const NotificationDetails(
            android: AndroidNotificationDetails('your channel id',
                'your channel name', 'your channel description',
                importance: Importance.max, priority: Priority.high)),
        androidAllowWhileIdle: true,
        payload: payload,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime);
  }

}


class AnswerPage extends StatelessWidget {
  AnswerPage(this.payload);
  final String payload;
  @override
  Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Answer'),
        ),
        body: Center(
          child: Text(payload),
        ),
      );
  }
}