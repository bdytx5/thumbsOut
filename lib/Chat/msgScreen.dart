import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'msgStream.dart';
import '../globals.dart' as globals;
import '../homePage/feedStream.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'snap.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'viewPicScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'addUser.dart';
import 'groupMsgScreen.dart';
import 'package:flutter/services.dart';
import '../pageTransitions.dart';

typedef glimpseLoadedCB = void Function(File glimpseKey);

class ChatScreen extends StatefulWidget {
     final String convoId;
     final bool newConvo;
     ///critical info
     final String recipFullName;
     final String recipID;
     final String recipImgURL;

     final String senderFullName;
     final String senderImgURL;
     

  ChatScreen({this.recipID,this.convoId, this.newConvo, this.recipImgURL, this.recipFullName, this.senderFullName, this.senderImgURL});

     _chatScreenState createState() => new _chatScreenState();


}
class _chatScreenState extends State<ChatScreen> with RouteAware{
  //final List<Msg> _messages = <Msg>[];
  final TextEditingController _textController = new TextEditingController();
  bool _isWriting = false;
  bool newConvo;
  FocusNode txtInputFocusNode = new FocusNode();
  Query chatQuery;
  ScrollController listController = new ScrollController();

  /// critical info
  String recipFullName;
  String recipId;
  String recipImgURL;
  String senderId;
  String senderFullName;
  String senderImgURL;
  bool allInfoIsAvailable = false;
  bool sendingPicture = false;
  File pictureBeingSent;
  bool glimpseLoading = false;
  bool userHasSentAtLeastOneMsg = false;
  Map glimpseLoadLog = new Map();
  bool scrolled = false;
  static const platform = const MethodChannel('thumbsOutChannel');
  Map recentMsgTimeAndSender = new Map();
  bool updatedReadReciepts = false;
  bool showingRibbon = false;
  bool recipHasRead;
  double keyboardOffset = 0.0;
  var readRecieptsListener;
  var recipRecieptsListener;
  bool allBtnsDisabled = false;
  bool textfieldDisabled = false;


   void initState() {
    super.initState();
    newConvo = widget.newConvo;
    makeSureAllMsgScreenInfoIsAvailable();
    addDismissKeyboardListener();
    setupStreamQuery();
   // listenToRecipNewFlag();
   // updateAndListenToReadReciepts();
    DatabaseReference ref = FirebaseDatabase.instance.reference();

    if(widget.convoId != globals.id){
      readRecieptsListener =  ref.child('convoLists').child(globals.id).child(widget.recipID).child('new').onValue.listen((Event New) => updateAndListenToOurReadReciepts(New));
      recipRecieptsListener = ref.child('convoLists').child(widget.recipID).child(globals.id).child('new').onValue.listen((Event New) => listenToRecipNewFlagForRecip(New));
    }

   }

  @override
  void dispose() {
    // Clean up the controller when the Widget is removed from the Widget tree
    if(widget.convoId != globals.id){
      readRecieptsListener.cancel();
      recipRecieptsListener.cancel();
    }
    super.dispose();
  }


   // used for previous read reciepts system
//    @override
//  void didPop() {
//    updateReadReceipts();
//    super.didPop();
//  }
//
//
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context));
  }
  @override
  void didPopNext() {
    debugPrint("didPopNext ${runtimeType}");
  }



  @override 
  Widget build(BuildContext context){
    return new Scaffold(
      appBar: new AppBar(
        backgroundColor: Colors.yellowAccent,
        actions: <Widget>[

          (widget.convoId != globals.id && senderImgURL != null) ?  new FlatButton.icon(onPressed: (!allBtnsDisabled) ? (){
    Navigator.push(context, new MaterialPageRoute(builder: (context) => new AddUser(firstUser: widget.recipID,groupImg:senderImgURL,newConvo: true,))).then((convoInfo) {
      //  Map convoInfo = {'convoID': widget.convoId,'newConvo': true,'groupMembers': widget.members, 'groupName': controller.text,'groupImg':widget.groupImgURL};
      if(convoInfo == null){
        return;
      }
      Navigator.push(context, new MaterialPageRoute(builder: (context) =>
      new GroupChatScreen(convoID: convoInfo['convoID'],
        newConvo: true,
        groupMembers: convoInfo['groupMembers'],
        groupImg: convoInfo['groupImg'],
        groupName: convoInfo['groupName'],)));
    });
    } : null,
              icon: new Icon(Icons.group_add), label: new Text('')) : new Container()
        ],
        title: new Text((recipFullName != null) ? recipFullName : '', style: new TextStyle(color: Colors.black),),
        leading: new IconButton(
          highlightColor: Colors.yellowAccent,
          color: Colors.black,
          icon: new Icon(Icons.arrow_back),
          onPressed: (!allBtnsDisabled) ? (){
            Navigator.pop(context);
          } : null,
        ),

      ),
      body: new Column( children: <Widget>[
          new Expanded(
        child: (allInfoIsAvailable) ? new Stack(
          children: <Widget>[
            new MediaQuery.removePadding(context: context, child: msgStream(),removeBottom: true,),
          ],
        ) : new Container(
          child: new Center(
            child: new CircularProgressIndicator(),
          ),
        ),
          ),

          (!scrolled) ?  new Container(
            height: 20.0,
            width: double.infinity,
            color: Colors.transparent,
            child: new Padding(padding: new EdgeInsets.only(left: 25.0),
            child: new Row(
              children: <Widget>[
                (showingRibbon) ? new Icon(Icons.check,color: Colors.grey[600],size: 15.0,) : new Container(),
                (showingRibbon && recipHasRead != null) ? new Text((recipHasRead) ? "Read" : "Sent",style: new TextStyle(fontSize: 12.0),) : new Container(),
              ],
            ),
            )
          ) : (keyboardOffset < 20.0) ? new Container(
            height: (20.0 - keyboardOffset),
            color: Colors.transparent,
          ) : new Container(),
          new Divider(height: 1.0,),
          new Container(
            child: new Padding(padding: new EdgeInsets.only(bottom: 8.0),
            child: _buildComposer(),
    ),
            decoration: new BoxDecoration(color: Colors.white),
          ),
        ],
      )
    );
  }

  Widget msgStream(){
   return new FirebaseAnimatedList(
        query: chatQuery,
        //  sort: (DataSnapshot a, DataSnapshot b) => a.key.compareTo(b.key),
        padding: new EdgeInsets.only(left: 8.0,right: 8.0,top: 8.0),
        reverse: true,
        controller: listController,

        sort: (a, b) => sortChatStream(a, b),
        itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation, ___) {

          Map msg = snapshot.value;

          if(newConvo){
            newConvo = false;
          }
          if(msg['from'] == globals.id){
              userHasSentAtLeastOneMsg = true;
          }
          if(msg['type'] != null && msg['from'] != globals.id && msg['formattedTime'] != null){
                  return recipGlimpseCell(msg,widget.convoId,snapshot.key,recipFullName,recipImgURL);
          }
          if(msg['type'] != null && msg['from'] == globals.id && msg['formattedTime'] != null){
            return senderGlimpseCell(msg['viewed'],senderFullName, senderImgURL,msg['formattedTime']);
          }
          if(msg['type'] != null && msg['formattedTime'] == null ){
            return new Container();
          }
          if(msg['from'] == senderId){
            updateRecentMsg(msg);
            return Msg(msg['message'], senderImgURL,senderFullName, msg['formattedTime']);
          }else{
            updateRecentMsg(msg);
            return Msg(msg['message'], recipImgURL,recipFullName, msg['formattedTime']);
          }
        }
    );
  }

  int sortChatStream(DataSnapshot a, DataSnapshot b){
    return (b.key.compareTo(a.key));
  }



  Widget Msg(String txt, String imgURL, String name, String time) {
     return new Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Container(
            margin: const EdgeInsets.only(right: 5.0),
            child: new CircleAvatar(
              backgroundImage: new NetworkImage(imgURL),
              backgroundColor: Colors.transparent,            
            ),
          ),
          new Expanded(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                    new Text(name,style: new TextStyle(fontWeight: FontWeight.bold),),
                       new Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                        //  new Icon(Icons.language, color: Colors.grey,size: 10.0,),
                          Text(getDateOfMsg(time), style: new TextStyle(color: Colors.grey, fontSize: 8.0),),
                        ],
                      ),
                new Container(
                  margin: const EdgeInsets.only(top: 3.0),
                  child: new Text(txt,style: new TextStyle(fontSize: 17.0),),
                )
              ],
            ),
          )
        ],
      ));
  }

//

  Widget _buildComposer() {

    return new IconTheme(
      data: new IconThemeData(color: Colors.yellowAccent),
      child: new Container(

        margin: const EdgeInsets.symmetric(horizontal: 9.0),
        child: new Column(
          children: <Widget>[
            new Row(
              children: <Widget>[

                new Flexible(
                  child: new TextField(
                    maxLines: null,
                    focusNode: (!textfieldDisabled) ? txtInputFocusNode : new AlwaysDisabledFocusNode(),
                    controller: _textController,
                    onChanged: (String txt){
                      setState(() {
                        _isWriting = true;

                      });

                    },
                    onSubmitted: _submitMsg,
                    decoration: new InputDecoration.collapsed(hintText: 'Enter a Message!'),
                  )
                ),
                new Container(

                    margin: new EdgeInsets.symmetric(horizontal: 3.0),
                    child: new IconButton(
                      icon: new Icon(Icons.message,color: Colors.grey,),
                      onPressed: (_isWriting && _textController.text != null && !allBtnsDisabled) ? () => _submitMsg(_textController.text) : (){},
                    )
                ),
      (widget.convoId != globals.id) ? new Container(
                  height: 30.0,
                  width: 30.0,
                  decoration: new BoxDecoration(
                      color: Colors.yellowAccent,
                      shape: BoxShape.circle,
                      border: new Border.all(color: Colors.grey,width: 3.0)
                  ),
                  child: new InkWell(onTap: (!allBtnsDisabled) ? ()async{
//
//                    Navigator.push(context,
//                        new ShowRoute(widget: SnapPage(widget.convoId,widget.recipID,recipImgURL, recipFullName,newConvo,userHasSentAtLeastOneMsg)));


                  if(Platform.isIOS){
                    txtInputFocusNode.unfocus();
                    if(mounted){
                      setState(() {
                        allBtnsDisabled = true;
                        textfieldDisabled = true;
                      });
                    }

                  platform.invokeMethod('showCamera',
                        <String, dynamic> {'convoId':widget.convoId, 'sender':globals.id, 'recip':widget.recipID, 'fullName':recipFullName, 'imgURL':recipImgURL}).then((d){
                          if(mounted){
                            setState(() {
                              textfieldDisabled = false;
                            });
                          }
                          Future.delayed(new Duration(milliseconds: 500)).then((idkl){
                            if(mounted){
                              setState(() {
                                allBtnsDisabled = false;
                              });
                            }

                          });
                       });
                  }else{
                    Navigator.push(context,
                        new ShowRoute(widget: SnapPage(widget.convoId,widget.recipID,recipImgURL, recipFullName,newConvo,userHasSentAtLeastOneMsg)));
                    }
                     } : null
                  ),
                ) : new Container(),
              ],
            ),

          ],
        ),
        decoration: Theme.of(context).platform == TargetPlatform.iOS ? 
        new BoxDecoration(
          border: new Border(top: new BorderSide(color: Colors.grey, width: 0.5))) : null
        ),
      );
    
  }


  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  void _submitMsg(String txt)async{
   if(!allInfoIsAvailable){
     return;
   }
   if(_textController.text == null){
     return;
   }
   if(_textController.text == ''){
     return;
   }
    if(widget.convoId == globals.id){
     await sendFeedbackMsg();
    }else{
      if(newConvo){
        var msg = _textController.text;
        _textController.clear();
       await sendNewConvoMsg(msg);
      }else{
        var msg = _textController.text;
        _textController.clear();
        await sendRegularMsg(globals.id, msg);
      }
    }

    if(mounted){

      setState(() {_isWriting = false;});
    }


}


void updateRecentMsg(Map msg){
    var dateString = msg['formattedTime'];
    var formatter = new DateFormat('yyyy-MM-dd hh:mm:ss a');
    var msgDate = formatter.parse(dateString);
    if(recentMsgTimeAndSender['date'] != null){
      if(msgDate.isAfter(formatter.parse(recentMsgTimeAndSender['date']))){
        recentMsgTimeAndSender['sender'] = msg['from'];
        recentMsgTimeAndSender['date'] = msg['formattedTime'];
        updateReadMessageReciepts();
      }
    }else{
      recentMsgTimeAndSender['sender'] = msg['from'];
      recentMsgTimeAndSender['date'] = msg['formattedTime'];
      updateReadMessageReciepts();

    }
}

// not sure if this is the best way... but it works for now...
Future<void>updateReadMessageReciepts()async{
    if(updatedReadReciepts){
      return;
    }else{
      updatedReadReciepts = true;
      Future.delayed(new Duration(seconds: 1)).then((d){

        if(mounted){
          setState(() {
            handleReadRibbon();
          });
        }
      });
    }
  }

void handleReadRibbon(){
    if(recentMsgTimeAndSender['sender'] != globals.id){
      if(mounted){
        setState(() {
          setState(() {
            updatedReadReciepts = false;
            showingRibbon = false;
          });
        });
      }

    }else{
      if(mounted){
        setState(() {
          updatedReadReciepts = false;
          showingRibbon = true;
        });
      }

    }
}


void listenToRecipNewFlagForRecip(Event New){
  //  DatabaseReference recipNewRef = FirebaseDatabase.instance.reference();
 //   recipNewRef.child('convoLists').child(widget.recipID).child(globals.id).child('new').onValue.listen((Event New){


      if(New.snapshot.value == null){return;}
      if(mounted){
        setState(() {
          recipHasRead = !New.snapshot.value;
        });
      }


      //});
  }





Future<void> sendRegularMsg(String id, String msg)async{
  await handleContactsList();
  var formatter = new DateFormat('yyyy-MM-dd hh:mm:ss a');
  var now = formatter.format(new DateTime.now());
  DatabaseReference ref = FirebaseDatabase.instance.reference();
  var key = ref.child('convos').child(widget.convoId).push().key;

  Map message = {'to':widget.recipID,'from':globals.id,'message':msg, 'formattedTime':now};
  try{
    await ref.child('convoLists').child(globals.id).child(widget.recipID).update({'recentMsg':msg, 'time':key,'formattedTime':now});// IDK
    await ref.child('convoLists').child(widget.recipID).child(globals.id).update({'recentMsg':msg, 'time':key,'formattedTime':now,'new':true});
    await ref.child('convos').child(widget.convoId).push().set(message); // SEND THE MESSAGE
  }catch(e){
    _errorMenu("Error", "There was an error sending your message.", '');
  }

}

  Future<void> sendFeedbackMsg()async{
    var formatter = new DateFormat('yyyy-MM-dd hh:mm:ss a');
    var now = formatter.format(new DateTime.now());
    if(globals.id == null || _textController.text == null || now == null){
      return;
    }
   // Map brettsChatlist = { 'imgURL':senderImgURL, 'formattedTime':now, 'new': true, 'recentMsg':_textController.text, 'recipFullName':senderFullName, 'recipId':globals.id, 'convoId':FirebaseDatabase.instance.reference().push().key}
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    Map message = {'from':globals.id,'message':_textController.text, 'formattedTime':now};
    try{
      ref.child('feedback').child('admin').push().set(message); // for meee
      ref.child('feedback').child(globals.id).push().set(message);
      respondToFeedback();
    }catch(e){
      _errorMenu('Error', 'There was an error sending your message.', '');
    }
}


Future<void> respondToFeedback()async{
  var formatter = new DateFormat('yyyy-MM-dd hh:mm:ss a');
  var now = formatter.format(new DateTime.now());
  DatabaseReference ref = FirebaseDatabase.instance.reference();

  Map message = {'to':globals.id,'from':'link','message':"Thanks for the feedback! We will try to get back to you non-robotically.", 'formattedTime':now};
  await Future.delayed(new Duration(seconds: 1));
    ref.child('feedback').child(globals.id).push().set(message);
}



Future<void> sendNewConvoMsg(String msg)async{

if(!allInfoIsAvailable){
  return;
}

var formatter = new DateFormat('yyyy-MM-dd hh:mm:ss a');
  var now = formatter.format(new DateTime.now());
  DatabaseReference ref = FirebaseDatabase.instance.reference();
  newConvo = false;

  try{
    await handleContactsList();
    Map message = {'to':widget.recipID,'from':globals.id,'message':msg,'formattedTime':now}; // CREATE MESSAG
    await ref.child('convos').child(widget.convoId).push().set(message); // SEND THE MESSAGE

    Map convoInfoForSender = {'recipID':widget.recipID,'convoID':widget.convoId, 'time':widget.convoId, 'imgURL':recipImgURL,
      'recipFullName': recipFullName, 'recentMsg':msg,'formattedTime':now, 'new': false};
    await ref.child('convoLists').child(globals.id).child(widget.recipID).set(convoInfoForSender);

    Map convoInfoForRecipient = {'recipID':globals.id,'convoID':widget.convoId, 'time':widget.convoId, 'imgURL':senderImgURL, 'recipFullName':senderFullName,'recentMsg':msg,'formattedTime':now, 'new':true};
    await ref.child('convoLists').child(widget.recipID).child(globals.id).set(convoInfoForRecipient);
  }catch(e){
    _errorMenu('Error', 'There was an error sending your message.', '');
  }
}



Future<void> handleContactsList()async{
  DatabaseReference ref = FirebaseDatabase.instance.reference();
  if(!userHasSentAtLeastOneMsg){
    DataSnapshot snap = await ref.child('contacts').child(globals.id).once();
    if(snap.value != null){
      List<String> contacts = List.from(snap.value);
      if(!contacts.contains(widget.recipID)){
        contacts.add(widget.recipID);
        await ref.child('contacts').child(globals.id).set(contacts);
      }
    }else{
      await ref.child('contacts').child(globals.id).set([widget.recipID]);
       }
    }
}


  String getDateOfMsg(String time){

    String date = '';
    if(time == null){
      return '';
    }
    var formatter = new DateFormat('yyyy-MM-dd hh:mm:ss a');
    DateTime recentMsgDate = formatter.parse(time);
    var dayFormatter = new DateFormat('EEEE');
    var shortDatFormatter = new DateFormat('M/d/yy');
    var timeFormatter = new DateFormat('h:mm a');
    var now = new DateTime.now();
    Duration difference = now.difference(recentMsgDate);
    var differenceInSeconds = difference.inSeconds;
    // msg is less than a week old
    if(differenceInSeconds < 86400){
      date = timeFormatter.format(recentMsgDate);
    }else{
      date = shortDatFormatter.format(recentMsgDate);
    }
    return date;
  }





  Future<void> makeSureAllMsgScreenInfoIsAvailable()async{
    newConvo = widget.newConvo;
    /// senderInfo
    try{
      await getSenderFullName();
      await getSenderImgURL();
      senderId = globals.id;
      ///recipInfo
      await getRecipFullName();
      await getRecipImgURL();

      if(senderFullName != null && senderImgURL != null && recipImgURL != null && senderFullName != null && mounted){
        setState(() {
          allInfoIsAvailable = true;
        });
      }
    }catch(e){
      Future.delayed(new Duration(seconds: 2)).then((e){
        _errorMenu('Error', 'Database error, please contact Link Support.', '');
    });
  }


      }


void setupStreamQuery(){
  DatabaseReference ref = FirebaseDatabase.instance.reference();
  if(widget.convoId == globals.id){
    chatQuery = ref.child('feedback').child(globals.id);
  }else{
    chatQuery = ref.child('convos').child(widget.convoId);
  }
}


  void addDismissKeyboardListener(){
    listController.addListener((){

      if(mounted){
        setState(() {
          keyboardOffset = listController.offset;
        });
      }

      print(keyboardOffset);
     if(listController.offset > 5.0){
       if(!scrolled){
        if(mounted){
          setState(() {
            scrolled = true;
          });
        }
       }
     }else{
       if(scrolled){
       if(mounted){
         setState(() {
           scrolled = false;
         });
       }
       }
     }
      txtInputFocusNode.unfocus();
    });
  }


  Future<void> getSenderImgURL()async{
    if(widget.senderImgURL != null){
      setState(() {
        senderImgURL = widget.senderImgURL;
      });
    }else {
      DatabaseReference ref = FirebaseDatabase.instance.reference();
      DataSnapshot snap;
      try{
         snap = await ref.child(globals.cityCode).child('userInfo').child(globals.id).child('imgURL').once();
      }catch(e){
        throw new Exception('Error');
      }
      setState(() {
        if(snap.value != null){
          senderImgURL = snap.value;
        }else{
          throw new Exception('Error');
        }
      });

    }
  }


  Future<void> getSenderFullName()async{
    if(widget.senderFullName != null){
      setState(() {
        senderFullName = widget.senderFullName;

      });
    }else{
      DatabaseReference ref = FirebaseDatabase.instance.reference();
      DataSnapshot snap;
    try{
       snap = await ref.child(globals.cityCode).child('userInfo').child(globals.id).child('fullName').once();
    }catch(e){
      throw new Exception('Error');
    }
      setState(() {
        if(snap.value != null){
          senderFullName = snap.value;
        }else{
          throw new Exception('Error');
        }

      });
    }

  }


  Future<void> getRecipFullName()async{
    if(widget.recipFullName != null){
      setState(() {
        recipFullName = widget.recipFullName;
      });
    }else{
      DatabaseReference ref = FirebaseDatabase.instance.reference();
      DataSnapshot snap;

      try{
         snap = await ref.child(globals.cityCode).child('userInfo').child(widget.recipID).child('fullName').once();
      }catch(e){
       throw new Exception('Error');
      }
      setState(() {
        if(snap.value != null){
          recipFullName = snap.value;
        }else{
          throw new Exception("Error");
        }
      });
      }
    }

  Future<void> getRecipImgURL()async{
    if(widget.recipImgURL != null){
      setState(() {
        recipImgURL = widget.recipImgURL;
        return;
      });
    }else{
      DatabaseReference ref = FirebaseDatabase.instance.reference();
      DataSnapshot snap;
      try{
         snap = await ref.child(globals.cityCode).child('userInfo').child(widget.recipID).child('imgURL').once();
      }catch(e){
        throw new Exception('Error');
      }
      setState(() {
        if(snap.value != null){
          recipImgURL = snap.value;
        }else{
          throw new Exception('Error');
        }
      });
    }
  }



  // we need to listen to the other users new flag, and use that val to update the read reciept

  // we need to listen to our own flag, and when it is set, we need to set it back to false

  Future<void> updateAndListenToOurReadReciepts(Event New)async{
    DatabaseReference ref = FirebaseDatabase.instance.reference();
 //   ref.child('convoLists').child(globals.id).child(widget.recipID).child('new').onValue.listen((Event New)async{
      if(New.snapshot.value == null){return;}
      try{
        if(New.snapshot.value){
          await ref.child('convoLists').child(globals.id).child(widget.recipID).update({'new':false});// IDK
        }
      }catch(e){
        throw new Exception('Error');
      }
 //   });
  }


  String getFirstName(String fullName) {
    int i;
    String firstName;
    String lastName;
    for (i = 0; i < fullName.length; i++) {
      if (fullName[i] == " ") {
        String firstName = fullName.substring(0, i);

        return firstName;
      }
    }
    return '';
  }




  Future<Null> _errorMenu(String title, String primaryMsg, String secondaryMsg) async {
    return showDialog<Null>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text(title),
          content: new SingleChildScrollView(
            child: new ListBody(
              children: <Widget>[
                new Text(primaryMsg),
                new Text(secondaryMsg),
              ],
            ),
          ),
          actions: <Widget>[
            new FlatButton(
              child: new Text('Okay', style: new TextStyle(color: Colors.black),),
              onPressed:(!allBtnsDisabled) ? () {
                Navigator.of(context).pop();
              } : null
            ),
          ],
        );
      },
    );
  }




  Widget recipGlimpseCell(Map msg, String convoId, String glimpseKey, String fullName, String imgURL){
    return new Card(
        child:new InkWell(
         splashColor: Colors.white,
          highlightColor: Colors.white,

          onTap:(!allBtnsDisabled) ? ()async {
            if(!msg['viewed']){
              viewGlimpse(glimpseKey, msg);
            }else{
               Navigator.push(context,
                    new ShowRoute(widget: SnapPage(widget.convoId,widget.recipID,recipImgURL, recipFullName,newConvo,userHasSentAtLeastOneMsg)));
            }

          } : null,
          child:  new Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              new Expanded(
                  child: new Column(
                    children: <Widget>[
                      new Row(
                        children: <Widget>[
                          new Padding(padding: new EdgeInsets.all(5.0),
                            child:  new CircleAvatar(
                              backgroundImage: new CachedNetworkImageProvider(imgURL),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          new Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              new Padding(padding: new EdgeInsets.only(left: 10.0),
                                child: new Text(fullName,style: new TextStyle(fontWeight: FontWeight.bold),),

                              ),
        (msg['formattedTime'] != null) ?  new Padding(padding: new EdgeInsets.only(left: 10.0,top: 1.0, bottom:1.0 ),
                                child:  Text(getDateOfMsg(msg['formattedTime']), style: new TextStyle(color: Colors.grey, fontSize: 8.0),),
                              ) : new Container(),


                              new Padding(padding: new EdgeInsets.only(left: 10.0),
                                child: new Text( (!msg['viewed']) ? 'New Glimpse, tap to view!': 'Tap to Reply!!' , style: new TextStyle(fontStyle: FontStyle.italic),),
                              )
                            ],
                          )
                        ],
                      )
                    ],
                    crossAxisAlignment: CrossAxisAlignment.start,
                  )
              ),


            ],
          ),
        )
    );
  }



  Widget senderGlimpseCell(bool recipViewed, String senderName, String imgURL,String time ){
    return new Container(

        child: InkWell(

            onTap: (!allBtnsDisabled) ? ()async{

              // nothing
            } : null,
            splashColor: Colors.white,
            highlightColor: Colors.white,

            child:  new Card(
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  new Expanded(
                      child: new Column(
                        children: <Widget>[
                          new Row(
                            children: <Widget>[
                              new Padding(padding: new EdgeInsets.all(5.0),
                                child:  new CircleAvatar(
                                  backgroundImage: new CachedNetworkImageProvider(imgURL),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),

                              new Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  new Padding(padding: new EdgeInsets.only(left: 10.0),
                                    child: new Text(senderName,style: new TextStyle(fontWeight: FontWeight.bold),),

                                  ),
                                  (time != null) ? new Padding(padding: new EdgeInsets.only(left: 10.0,top: 1.0, bottom:1.0 ),
                                    child:  Text(getDateOfMsg(time), style: new TextStyle(color: Colors.grey, fontSize: 8.0),),
                                  ) : new Container(),
                                  new Padding(padding: new EdgeInsets.only(left: 10.0),
                                    child: new Text((!recipViewed) ? 'Sent Glimpse!': 'Glimpse has been opened!',style: new TextStyle(fontStyle: FontStyle.italic)
                                    ),
                                  )
                                ],
                              )
                            ],
                          )
                        ],
                        crossAxisAlignment: CrossAxisAlignment.start,
                      )
                  ),

                ],
              ),
            )
        )
    );
  }



  Future<void> viewGlimpse(String glimpseKey, Map msg)async{

    if(msg.containsKey('fromCameraRoll')){
      Navigator.push(context, ShowRoute(widget: viewPic(msg['url'],msg['duration'], true,widget.convoId,glimpseKey)),);
    }else{
        Navigator.push(context, ShowRoute(widget: viewPic(msg['url'],msg['duration'], false,widget.convoId,glimpseKey)),
        );
    }
  }


}

// solving issues ...
class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}

//Future<void> updateReadReceipts()async{
//  if(!newConvo && widget.convoId != globals.id){
//    DatabaseReference ref = FirebaseDatabase.instance.reference();
//    try{
//      await ref.child('convoLists').child(globals.id).child(widget.recipID).update({'new':false});// IDK
//    }catch(e){
//      throw new Exception('Error');
//    }
//  }
//}


