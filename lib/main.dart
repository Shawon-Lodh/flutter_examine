import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SortNumbersScreen(),
    );
  }
}

class SortNumbersScreen extends StatefulWidget {
  @override
  _SortNumbersScreenState createState() => _SortNumbersScreenState();
}

class _SortNumbersScreenState extends State<SortNumbersScreen> with TickerProviderStateMixin {
  List<int> _numbersBubble = [];
  List<int> _numbersQuick = [];
  bool _isSorting = false;

  //These are declarations for the ReceivePort objects which will be used for communication between the main isolate and the sorting isolates.
  late ReceivePort _receivePortBubble, _receivePortQuick;
  final GlobalKey<AnimatedListState> _listKeyBubble = GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _listKeyQuick = GlobalKey<AnimatedListState>();
  Duration? _bubbleSortDuration;
  Duration? _quickSortDuration;

  @override
  void initState() {
    super.initState();
    _generateRandomNumbers();
  }

  void _generateRandomNumbers() {
    _numbersBubble = List.generate(20, (index) => index + 1)..shuffle();
    _numbersQuick = List<int>.from(_numbersBubble);
    for (int i = 0; i < _numbersBubble.length; i++) {
      _listKeyBubble.currentState?.insertItem(i);
      _listKeyQuick.currentState?.insertItem(i);
    }
  }

  void _sortNumbers() async {
    //ReceivePort().first or ReceivePort().sendPort data types are send port
    // but ReceivePort().sendPort handles where to communicate & ReceivePort().first  handles after communicating what will be get


    setState(() {
      _isSorting = true;
    });

    //ReceivePort(); : This creates a new ReceivePort, which listens for incoming messages from the main isolate.

    //Two ReceivePort objects are created to handle communication with the bubble sort and quick sort isolates.
    _receivePortBubble = ReceivePort();
    _receivePortQuick = ReceivePort();

    //Two new isolates are spawned for bubble sort and quick sort, each receiving a SendPort for communication.
    await Isolate.spawn(_bubbleSortInIsolate, _receivePortBubble.sendPort);
    await Isolate.spawn(_quickSortInIsolate, _receivePortQuick.sendPort);

    //The main isolate waits for each sorting isolate to send back their SendPort, which will be used to send sorting data to the isolates.
    final SendPort sendPortBubble = await _receivePortBubble.first;
    final SendPort sendPortQuick = await _receivePortQuick.first;

    //Two more ReceivePort objects are created to receive the sorted lists from the sorting isolates.
    final responsePortBubble = ReceivePort();
    final responsePortQuick = ReceivePort();

    DateTime bubbleStartTime = DateTime.now();
    DateTime quickStartTime = DateTime.now();

    //The main isolate sends the lists to be sorted and the SendPort of the response ports to the sorting isolates.
    sendPortBubble.send([_numbersBubble, responsePortBubble.sendPort]);
    sendPortQuick.send([_numbersQuick, responsePortQuick.sendPort]);

    //The main isolate waits for the sorting isolates to send back the sorted lists.
    final sortedNumbersBubble = await responsePortBubble.first;
    final sortedNumbersQuick = await responsePortQuick.first;

    print("sortedNumbersBubble.first is  : $sortedNumbersBubble");
    print("sortedNumbersQuick.first is  : $sortedNumbersQuick");

    //The sorted lists are animated using the _animateSort function.
    _animateSort(sortedNumbersBubble, _listKeyBubble, _numbersBubble);

    DateTime bubbleEndTime = DateTime.now();
    _bubbleSortDuration = bubbleEndTime.difference(bubbleStartTime);

    //The sorted lists are animated using the _animateSort function.
    _animateSort(sortedNumbersQuick, _listKeyQuick, _numbersQuick);

    DateTime quickEndTime = DateTime.now();
    _quickSortDuration = quickEndTime.difference(quickStartTime);

    setState(() {
      _isSorting = false;
    });

    // Close the receive  port
    _receivePortBubble.close();
    _receivePortQuick.close();

    responsePortBubble.close();
    responsePortQuick.close();

    //why sendPortBubble, sendPortQuick ,sortedNumbersBubble & sortedNumbersQuick are not closed?
    //Once the ReceivePort is closed, any associated SendPort will also effectively become non-functional.

    //sendPortBubble and sendPortQuick return the value that initiate the method of _bubbleSortInIsolate & _quickSortInIsolate,
    //but the SendPort is not closed, so the same sendport can be used to send integer list for sorting,
    //after completing sorting these are handled by Dart's garbage and do not need to be closed explicitly.

    //sortedNumbersBubble and sortedNumbersQuick return a list of sorted integers,
    //but the SendPort is not closed, so the list can be used to store integers,
    //after storing these are handled by Dart's garbage collector and do not need to be closed explicitly.
  }

  static void _bubbleSortInIsolate(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (var message in port) {
      final numbers = List<int>.from(message[0] as List<int>);
      final replyTo = message[1] as SendPort;

      for (int i = 0; i < numbers.length; i++) {
        for (int j = 0; j < numbers.length - i - 1; j++) {
          if (numbers[j] > numbers[j + 1]) {
            final temp = numbers[j];
            numbers[j] = numbers[j + 1];
            numbers[j + 1] = temp;
          }
        }
      }

      replyTo.send(numbers);
    }
  }

  static void _quickSortInIsolate(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (var message in port) {
      final numbers = List<int>.from(message[0] as List<int>);
      final replyTo = message[1] as SendPort;

      _quickSort(numbers, 0, numbers.length - 1);

      replyTo.send(numbers);
    }
  }

  static void _quickSort(List<int> list, int left, int right) {
    if (left < right) {
      int pivotIndex = _partition(list, left, right);
      _quickSort(list, left, pivotIndex - 1);
      _quickSort(list, pivotIndex + 1, right);
    }
  }

  static int _partition(List<int> list, int left, int right) {
    int pivot = list[right];
    int i = left - 1;
    for (int j = left; j < right; j++) {
      if (list[j] <= pivot) {
        i++;
        int temp = list[i];
        list[i] = list[j];
        list[j] = temp;
      }
    }
    int temp = list[i + 1];
    list[i + 1] = list[right];
    list[right] = temp;
    return i + 1;
  }

  void _animateSort(List<int> sortedNumbers, GlobalKey<AnimatedListState> listKey, List<int> numbers) async {
    final currentNumbers = List<int>.from(numbers);
    for (int i = 0; i < sortedNumbers.length; i++) {
      final currentIndex = currentNumbers.indexOf(sortedNumbers[i]);
      if (currentIndex != i) {
        setState(() {
          final number = currentNumbers.removeAt(currentIndex);
          currentNumbers.insert(i, number);
          if (listKey == _listKeyBubble) {
            _numbersBubble = currentNumbers;
          } else {
            _numbersQuick = currentNumbers;
          }
        });
        listKey.currentState?.removeItem(
          currentIndex,
              (context, animation) => _buildItem(sortedNumbers[currentIndex], animation),
        );
        listKey.currentState?.insertItem(i, duration: Duration(milliseconds: 300));
        await Future.delayed(Duration(milliseconds: 300));
      }
    }
  }

  Widget _buildItem(int item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        child: ListTile(
          title: Text(item.toString()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sort Numbers with Animation'),
      ),
      body: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: [
                Text(
                  'Bubble Sort',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_bubbleSortDuration != null)
                  Text(
                    'Time: ${_bubbleSortDuration!.inMilliseconds} ms',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                Expanded(
                  child: AnimatedList(
                    key: _listKeyBubble,
                    initialItemCount: _numbersBubble.length,
                    itemBuilder: (context, index, animation) {
                      return _buildItem(_numbersBubble[index], animation);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Quick Sort',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_quickSortDuration != null)
                  Text(
                    'Time: ${_quickSortDuration!.inMilliseconds} ms',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                Expanded(
                  child: AnimatedList(
                    key: _listKeyQuick,
                    initialItemCount: _numbersQuick.length,
                    itemBuilder: (context, index, animation) {
                      return _buildItem(_numbersQuick[index], animation);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSorting ? null : _sortNumbers,
        child: Icon(Icons.sort),
      ),
    );
  }
}
