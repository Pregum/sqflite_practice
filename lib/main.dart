import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_stetho/flutter_stetho.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/foundation.dart';

/// DB操作
class DbProvider {
  Database db;
  final _lock = Lock();

  Future<Database> getDb() async {
    db ??= await _lock.synchronized(() async =>
        db ??
        await _openDatabase(join(
            await getApplicationDocumentsDirectory()
                .then((onValue) => onValue.parent.path),
            "databases/foodCalendar.db.sqlite")));
    return db;
  }

  Future<Database> _openDatabase(String path) {
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database newDb, int version) {
        newDb.execute("""
      CREATE TABLE Food
        (
          id INTEGER PRIMARY KEY NOT NULL,
          name TEXT,
          limitDate TEXT,
          usedDate TEXT,
          T_kindType_ID INTEGER
        );
      """);
      },
    );
  }

  Future<int> delete(int index) async {
    var id = await db.delete('Food', where: 'id = ?', whereArgs: [index]);
    print(id);
    return id;
  }

  Future<int> insertNewFood(FoodRecord record) async {
    int id = await db.rawInsert(
      'INSERT INTO Food(name, limitDate, usedDate, T_kindType_ID) VALUES(?, ?, ?, ?)',
      [
        record.name,
        DateFormat('yyyy-MM-dd').format(record.limitDate),
        DateFormat('yyyy-MM-dd').format(record.usedDate),
        record.kindTypeId
      ],
    );
    return id;
  }

  Future<int> update(FoodRecord updateRecord) async {
    int id = await db.update('Food', updateRecord.toMap(),
        where: 'id = ?', whereArgs: [updateRecord.id]);
    print('update to : $id');
    return id;
  }

  Future<List<Map<String, dynamic>>> getQuery() async {
    Database d = await this.getDb();
    Future<List<Map<String, dynamic>>> list = d.rawQuery('SELECT * FROM Food');
    return list;
  }
}

class FoodRecord {
  int id;
  String name;
  DateTime limitDate;
  DateTime usedDate;
  int kindTypeId;

  FoodRecord(
      {this.id, this.name, this.limitDate, this.usedDate, this.kindTypeId});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'limitDate': DateFormat('yyyy-MM-dd').format(limitDate),
      'usedDate': DateFormat('yyyy-MM-dd').format(usedDate),
      'T_kindType_ID': kindTypeId,
    };
  }
}

void main() {

  // その１
  // assert()はDebug実行時のみ有効される事を利用
  // bool isDebug = false;
  // assert(isDebug = true);
  // if (isDebug) {
  //   print('debug mode');
  //   Stetho.initialize();
  // }

  // その２
  // isReleaseにはRelease実行時はtrueで、Debug実行時はfalseが格納されます。
  var isRelease = const bool.fromEnvironment('dart.vm.product');
  if(isRelease){
    print('Relase mode.');
  }
  else {
    print('Debug mode.');
    // Stetho.initialize();
  }

  // その3
  // debug実行時のみprofile()内を実行します。
  // profile(() {
  //   print('debug mode.');
  //   Stetho.initialize();
  // });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Database Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter DataBase Demo'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale("en"),
        const Locale("ja"),
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  DbProvider _dbProvider = DbProvider();

  Widget createGrid() {
    return FutureBuilder(
      future: _dbProvider.getQuery(),
      builder: (BuildContext context, AsyncSnapshot<List<Map>> snapshot) {
        // FloatingActionButtonを押すと、データが表示される。
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.data.isEmpty) {
          return Center(
            child: Text('右下の追加ボタンから新しいデータを追加して下さい。'),
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          children: List.generate(snapshot.data.length, (index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            DetailsPage(snapshot.data[index]))).then((result) {
                  // resultに遷移後のぺージから値を取得します。
                  if (result != null) {
                    setState(() {
                      print('変更後のname : ${result.name.toString()}');
                      _dbProvider.update(result);
                      print('更新しました!, id: ${result.id}');
                    });
                  } else
                    print('キャンセルされました');
                });
              },
              child: Card(
                color:
                    DateTime.parse(snapshot.data[index]['limitDate'].toString())
                            .isBefore(DateTime.now())
                        ? Colors.red
                        : Colors.lightGreen[200],
                child: Center(
                  child: Container(
                    margin: EdgeInsets.only(left: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${snapshot.data[index]['name'].toString()}',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              alignment: Alignment.center,
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                int id = snapshot.data[index]['id'];
                                setState(() {
                                  _dbProvider.delete(id);
                                });
                              },
                            ),
                          ],
                        ),
                        // データベース内のデータを表示
                        Divider(),
                        Text(' No : ${index + 1}'),
                        Text(
                            ' 期限日 : ${snapshot.data[index]['limitDate'].toString()}'),
                        Text(
                            ' 使用日 : ${snapshot.data[index]['usedDate'].toString()}'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var now = DateTime.now();
    var today = DateTime(now.year, now.month, now.day);
    var limiltDate =
        DateTime(now.year, now.month, now.add(Duration(days: 7)).day);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      // GridViewを作成
      body: createGrid(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CreatingItemPage(FoodRecord(
                      name: "steak",
                      limitDate: limiltDate,
                      usedDate: today,
                      kindTypeId: 1)))).then((result) async {
            if (result != null) {
              print('追加されました.');
              int id = await _dbProvider.insertNewFood(result);
              print("追加されたId: $id");
            }
          });
        },
        tooltip: '追加',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

/// 新規作成用ページです。
class CreatingItemPage extends StatefulWidget {
  FoodRecord foodRecord;
  CreatingItemPage(this.foodRecord);

  @override
  State<StatefulWidget> createState() => CreatingItemPageState(this.foodRecord);
}

class CreatingItemPageState extends State<CreatingItemPage> {
  CreatingItemPageState(this.foodRecord);
  FoodRecord foodRecord;
  String tmp;
  bool isNameEmpty;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  TextEditingController _textEditingController;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: this.foodRecord.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新規作成画面'),
      ),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('食材名'),
              TextField(
                controller: _textEditingController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '食材名を入力してください。',
                ),
                textAlign: TextAlign.start,
                onChanged: (text) {
                  setState(() {
                    this.foodRecord.name = text;
                    this.isNameEmpty = text.isEmpty;
                  });
                  print('name: ${this.foodRecord.name}');
                },
              ),
              Text(
                '期限日',
                textAlign: TextAlign.left,
              ),
              FlatButton(
                color: Color.fromARGB(255, 200, 200, 200),
                child: Text('${_dateFormat.format(this.foodRecord.limitDate)}'),
                onPressed: () async {
                  var selectedDate = await showDatePicker(
                    context: context,
                    locale: const Locale("ja"),
                    initialDate: this.foodRecord.limitDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    builder: (BuildContext context, Widget widget) => widget,
                  );
                  print('limitDate: ${this.foodRecord.limitDate}');
                  if (selectedDate != null) {
                    setState(() {
                      this.foodRecord.limitDate = selectedDate;
                    });
                  }
                  print('selectedDate: $selectedDate');
                },
              ),
              Text('使用日'),
              FlatButton(
                color: Color.fromARGB(255, 200, 200, 200),
                child: Text('${_dateFormat.format(this.foodRecord.usedDate)}'),
                onPressed: () async {
                  var selectedDate = await showDatePicker(
                    context: context,
                    locale: const Locale("ja"),
                    initialDate: this.foodRecord.usedDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    builder: (BuildContext context, Widget widget) => widget,
                  );

                  if (selectedDate != null) {
                    setState(() {
                      this.foodRecord.usedDate = selectedDate;
                    });
                  }
                  print('${this.foodRecord.usedDate}');
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    RaisedButton(
                      child: Text('キャンセル'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    RaisedButton(
                      child: Text('追加'),
                      onPressed: (this.foodRecord.name.trim().isNotEmpty)
                          ? () {
                              Navigator.pop(context, this.foodRecord);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 遷移先のページです。
/// 選択した項目の詳細を表示します。
class DetailsPage extends StatefulWidget {
  /// コンストラクタです。
  DetailsPage(this._dynamicContent);
  final dynamic _dynamicContent;
  @override
  State<StatefulWidget> createState() => new DetailsPageState(_dynamicContent);
}

class DetailsPageState extends State<DetailsPage> {
  /// コンストラクタです。
  DetailsPageState(dynamic dynamicContent) {
    _foodRecord = FoodRecord(
        id: dynamicContent['id'],
        name: dynamicContent['name'],
        limitDate: DateTime.parse(dynamicContent['limitDate'].toString()),
        usedDate: DateTime.parse(dynamicContent['usedDate'].toString()),
        kindTypeId: dynamicContent['T_kindType_ID']);

    _textEditingController = TextEditingController(text: _foodRecord.name);
  }

  /// 食材データを遷移元と受け渡しを行うオブジェクトです。
  FoodRecord _foodRecord;
  TextEditingController _textEditingController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('詳細画面'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            margin: EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('食材名'),
                TextField(
                  controller: _textEditingController,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(), hintText: '食材名を入力してください。'),
                  textAlign: TextAlign.start,
                  onChanged: (text) {
                    setState(() {
                      print('text : $text');
                      this._foodRecord.name = text;
                      // this._isNameEmpty = text.isEmpty;
                    });
                  },
                ),
                Text('期限日'),
                FlatButton(
                  color: Color.fromARGB(255, 200, 200, 200),
                  child: Text(
                      '${DateFormat("yyyy-MM-dd").format(_foodRecord.limitDate)}'),
                  onPressed: () async {
                    var selectedDate = await showDatePicker(
                      context: context,
                      locale: const Locale("ja"),
                      firstDate: DateTime(1900),
                      initialDate: _foodRecord.limitDate,
                      lastDate: DateTime(2100),
                      builder: (BuildContext build, Widget widget) => widget,
                    );
                    if (selectedDate != null) {
                      setState(() {
                        _foodRecord.limitDate = selectedDate;
                      });
                    }
                  },
                ),
                Text('使用日'),
                FlatButton(
                  color: Color.fromARGB(255, 200, 200, 200),
                  child: Text(
                      '${DateFormat("yyyy-MM-dd").format(_foodRecord.usedDate)}'),
                  onPressed: () async {
                    var selectedDate = await showDatePicker(
                      context: context,
                      locale: const Locale("ja"),
                      firstDate: DateTime(1900),
                      initialDate: _foodRecord.usedDate,
                      lastDate: DateTime(2100),
                      builder: (BuildContext build, Widget widget) => widget,
                    );
                    if (selectedDate != null) {
                      _foodRecord.usedDate = selectedDate;
                    }
                  },
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              RaisedButton(
                child: Text('キャンセル'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              RaisedButton(
                child: Text(' 変更 '),
                onPressed: _foodRecord.name.isEmpty
                    ? null // RaisedButton.onPressedにnullを入れることでボタンを操作不可にします。
                    : () {
                        Navigator.pop<FoodRecord>(context, this._foodRecord);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
