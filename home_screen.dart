///This file contains the implementation for:
/// 1. vlc player for portrait and landscape
/// 2. content for each class
/// 3. firebase firestore chat with reply function
/// 4. material download for class
/// 5. bambuser player for portrait and landscape

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flare_flutter/flare_actor.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_device_type/flutter_device_type.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:video_player/video_player.dart';
import 'package:xtraclass/chat/page/chat_page.dart';
import 'package:xtraclass/manager/downloader.dart';
import 'package:xtraclass/manager/firebase_manager.dart';
import 'package:xtraclass/manager/network/downloadTube.dart';
import 'package:xtraclass/manager/network/network_manager.dart';
import 'package:xtraclass/manager/network/vimeo_manager.dart';
import 'package:xtraclass/manager/player_manager.dart';
import 'package:xtraclass/manager/profile_manager.dart';
import 'package:xtraclass/model/delete_favorite_api_model.dart';
import 'package:xtraclass/model/get_class_details_api_model.dart';
import 'package:xtraclass/model/get_class_events_api_model.dart';
import 'package:xtraclass/model/get_class_semesters_api_model.dart';
import 'package:xtraclass/model/get_class_years_api_model.dart';
import 'package:xtraclass/model/get_lessons_api_model.dart';
import 'package:xtraclass/model/get_school_details_api_model.dart';
import 'package:xtraclass/model/get_student_profile_history_api_model.dart';
import 'package:xtraclass/model/post_email_sending_api_model.dart';
import 'package:xtraclass/model/post_history_api_model.dart';
import 'package:xtraclass/model/put_favorite_api_model.dart';
import 'package:xtraclass/model/vimeo_video_data.dart';
import 'package:xtraclass/modules/animations/fade_route_transition.dart';
import 'package:xtraclass/modules/buttons/blue_outline_button.dart';
import 'package:xtraclass/modules/buttons/toggle.dart';
import 'package:xtraclass/modules/complex_datepicker.dart';
import 'package:xtraclass/modules/complex_datepicker_home.dart';
import 'package:xtraclass/modules/dialogs/dialog.dart';
import 'package:xtraclass/modules/dialogs/login_register_dialog.dart';
import 'package:xtraclass/modules/full_screen_local.dart';
import 'package:xtraclass/modules/library_screen.dart';
import 'package:xtraclass/modules/placeholder_lines/placeholder_lines.dart';
import 'package:xtraclass/modules/texts/clickable_text.dart';
import 'package:xtraclass/screen/article_screens/article_view_screen.dart';
import 'package:xtraclass/screen/home/drawer.dart';
import 'package:xtraclass/screen/loading_screen.dart';
import 'package:xtraclass/utils/analytics.dart';
import 'package:xtraclass/utils/categories.dart';
import 'package:xtraclass/utils/constants.dart';
import 'package:xtraclass/utils/date_calculator.dart';
import 'package:dio/dio.dart';
import 'package:xtraclass/utils/offline_player_home.dart';
import 'package:xtraclass/utils/size_config.dart';
import 'package:flutter/services.dart';
import 'package:xtraclass/modules/slider/slider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:xclass_swagger/api.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:http/http.dart' as http;
import 'package:expandable/expandable.dart';
import 'package:expandable_sliver_list/expandable_sliver_list.dart';
import 'package:xtraclass/chat/model/user.dart' as ChatUser;
import 'offline_player.dart';

class VideoScreen extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> navCallback;
  VideoScreen({@required this.navCallback, this.initialIndex: 0});
  @override
  VideoScreenState createState() => VideoScreenState();
}

class VideoScreenState extends State<VideoScreen>
    with TickerProviderStateMixin {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey<ScaffoldState> landscapeScaffoldKey = GlobalKey<ScaffoldState>();

  bool _isVimeoPlaying = true;
  bool _isBookmarked = false;
  bool _isQualityButtonClicked = false;
  bool _isGetNotesButtonClicked = false;
  bool _materialsButtonSummaryClicked = false;
  bool _materialsButtonClicked = false;
  bool _materialsButtonCalendarClicked = false;

  String _downloadStatus = "Download is being started...";
  bool _downloadDone = true;
  Orientation orientation;
  bool _isLandscapeActive = false;
  bool _isLoading = false;
  List<String> downloadingList = [];
  bool isChatLoading = true;
  MyDownloader myDownloader = MyDownloader();
  double incrementer =0;
  Stream<double> bitdata;
  bool isDowloadable = false;
  bool isChecked = false;
  bool isHistorySet = false;

  bool isLoaded = false;
  String filepath;
  List<String> classIdsHistory = [];

  static bool isPDFfullScreen = false;
  static String noteUrl = "";

  SharedPreferences prefs ;
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  ExpandableSliverListController controller = ExpandableSliverListController();

  //debug_offline
  ChewieController chewieController;
  VideoPlayerController videoPlayerController;
  File file;


//////////////////////////////////////////////////////

//checkInternet

  bool isConnected = true;
  int _indexParent =0;



  Future<bool> checkInternet()async{
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('connected');
        setState((){isConnected = true;});
        return true;
      }
    } on SocketException catch (_) {

      //   showToast("Connection probleme!", Colors.red);
      setState((){isConnected = false;});
      return false;
    }
  }

  _getStudentHistory(){
    getHistory().timeout(
      TIMEOUT_DURATION,
      onTimeout: () {
        print("Time out #! Unable to fetch History"
        );
      },
    ).then((value) {
      int i = 0;
      print("#### Value data is: ${value.data}");
      if (value.statusCode == 200) {
        print("####### USER -> HISTORY : ${value.data}");
        var list = value.data;

        list.forEach((e) {
          setState(() {
            i++;
          });
          if(!classIdsHistory.contains(e.vimeoId)){
            setState(() {
              classIdsHistory.add(e.vimeoId);
              ProfileManager.shared().addHistoryVimeoId(e.vimeoId);
            });
            print("#####====> VimeoID $i :${e.vimeoId} ");
          }

        });

        //setHistoryList(classIdsHistory);

        print("############################### HISTORY (VIMEO_ID) IS :\n $classIdsHistory");

      }
    });
  }

  /* chat Message   */
  //List<ChatMessage> _chatMessage = [];
  List<ChatMessage> _chatMessage = [];

  Future<List> _getChatMessages(lessonId,classId,vimeoId)async{

      List<ChatMessage> list=[];
    Map<String,String> headers = {
      'Content-type':'application/json',
      'Accept':'application/json'
    };

    var url = 'https://demo.dextraclass.com/api/questiondata?lesson_id=$lessonId&class_id=$classId&vimeo_id=$vimeoId';
    var response = await http.get(Uri.encodeFull(url), headers: headers );

    if (response.statusCode == 200){
      ProfileManager.shared().clearParentIds();
      var res = json.decode(response.body);
      print( "################################# CHAT LIST: \n$res");
      print("####************************ DATA in CHAT: \n${res["data"]["data"] }");
      for(var data in res["data"]["data"]){
        if(data != null){
         setState(() {
           list.add(ChatMessage(
             id: data["id"],
             video_id: data["video_id"],
             class_id: data["class_id"],
             subject_id: data["subject_id"],
             content: data["content"],
             type: data["type"],
             sender_id: data["sender_id"],
             parent_id: data["parent_id"],
             status: data["status"],
             uuid: data["uuid"],
             created_at: data["created_at"],
           ));
           ProfileManager.shared().addParentIds(data["parent_id"]);
         });
        }
      }


    }
      return list;
  }

  Future<List<ChatMessage>> _getReplyList(List<ChatMessage> chatmessage, int myId)async{
    List<ChatMessage> mylist = [];
    for(var data in chatmessage){
      if(data.parent_id == myId){
        mylist.add(data);
      }
    }
    return mylist;
  }

/////////////////////////////////////////////////////////////////

  getMediaWidget(String path) {
    file = File(path);
    VideoPlayerController.file(file);

    chewieController = ChewieController(
      placeholder: BlurHash(
        hash: "L5H2EC=PM+yV0g-mq.wG9c010J}I",
      ),
      videoPlayerController: videoPlayerController,
      aspectRatio: 3 / 2,
      autoPlay: true,
      looping: false,
    );
    return Chewie(
      controller: chewieController,
    );

  }

  // DownloadTube dowloadTube = DownloadTube();

  //Request for Storage permission
  final PermissionHandler _permissionHandler = PermissionHandler();
  //var result = await _permissionHandler.requestPermissions([PermissionGroup.contacts]);

  _askStoragePermission()async{
    if(Platform.isAndroid ){
      await _permissionHandler.requestPermissions([PermissionGroup.storage]).then((value){
        if (value[PermissionGroup.storage] == PermissionStatus.granted) {
          // permission was granted
          setState(() { isDowloadable = true; });

        }
      });
    }
  }



  /* value Holding default of bookmark dropdown    */
  String selectedPopupRoute = "Bookmark";
  final List<String> popupRoutes = <String>[
    "Bookmark", "Download"];

  /* EOF of value Holding default of bookmark dropdown    */


  BlueOutlineButton _blueOutlineButton;
  ClickableText _clickableText;

/* Toggle Button */
  int selected;
  List<bool> isToggleButtonSelected;
/* End of Toggle Button */

/* Chat */
  List<DocumentSnapshot> _chatItems;

  List<String> _chatProfileImages = [];
  ScrollController _chatController = ScrollController();
  TextEditingController _chatTextController = TextEditingController();
  int _activeReplyChatIndex;
/* End of Chat */

  Animation<double> _animation;
  AnimationController _animationController;

  bool drawerIsVisible = false;
/*
*//* Bambuser *//*
  bambuseriOSPlugin.BambuserPlayer bambuseriOSPlayer;
  bambuserAndroidPlugin.BambuserPlayer bambuserAndroidPlayer;
  bambuseriOSPlugin.BambuserPlayerController _bambuseriOSPlayerController;
  bambuserAndroidPlugin.BambuserPlayerController
  _bambuserAndroidPlayerController;*/
  String _appIdIOS = "Xw4h2vCXWH3MqQbDWCUAaw";
  String _appIdAndroid = "CNRvgKbMhmWD7Oc7WC3hjw";
  String _resourceURI =
      "https://cdn.bambuser.net/groups/94422/broadcasts?by_authors=&title_contains=&has_any_tags=&has_all_tags=&order=live&da_id=a26dc76c-58c6-f7f8-8767-756846c63e78&da_timestamp=1593072132&da_signature_method=HMAC-SHA256&da_ttl=0&da_static=1&da_signature=d472eefda3c9a48d35228cc7d802837ec4e07c86309687ef95601673a783a016";
  bool _isBambuserPlaying = false;
  bool _isBambuserVisible = false;
  AnimationController _joinLiveButtonResizeController;
/* End of Bambuser */

  List<VimeoVideoData> _videoList = [];
  VimeoVideoData selectedVideo = VimeoVideoData();
  var _nowPosition = 0.0;
/* This would come from the API */

  toggleDrawer() async {
    if(scaffoldKey.currentState!=null)
    scaffoldKey.currentState.openEndDrawer();
  }

  showToast(String message,Color color){
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: color,
        textColor: Colors.white,
        fontSize: 15.0
    );
  }

  Future<bool> checkIfDownloadExist()async{

    getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
      print("###PORTRAIT LOCAL VIDEO: $value");
      if(value.isNotEmpty){
        return true;
      }else {
        return false;
      }

    });
  }

  Future<String>_getFilePath()async{
    Directory tempDir = await getApplicationDocumentsDirectory();
    return tempDir.path;
  }
  _isLoaded(){
    setState((){isLoaded = true;});
  }


  /* Previous flow */
  List<String> years = [];
  List<String> semesters = [];
  List<String> semesterIds = [];
  List<String> semesterEndDates = [];
  List<String> semesterStartDates = []; //debug
  /* End of previous flow */

  /* Rotate screen animation */
  double opacityLevel = 1.0;
  bool _showRotateAnimation = false;
  /* End of rotate screen animation */

  /* Program click handler */
  bool _isProgramItemCLickable = true;
  bool _makeVimeoCall = false;
  /* End of program click handler */

  /* List of Locally downlaoded video */
  List<String> localVideos = [];


  Future<List<String>> _getLocalVideoList() async {
    final SharedPreferences prefs = await _prefs;
    List<String> list = (prefs.getInt('LOCAL_VIDEO_LIST') ?? []) ;
    return list;
  }

  Future<void> _delaySmall()async{
   await Future.delayed( Duration(seconds: 3),(){
      setState(() {
        isLoaded = true;
      });
    });
  }

  Future<List> _checkUserSubscription()async {
    List<String> list = [];
    Map<String, String> headers = {
      'Content-type': 'application/json',
      'Accept': 'application/json',
      "Authorization":
      "Bearer ${ProfileManager.shared().getUserAccessToken()}"
    };

    var url = 'https://demo.dextraclass.com/api/subscription/check';
    var response = await http.post(Uri.encodeFull(url), headers: headers);

    if (response.statusCode == 200) {

      return list;
    }
  }


  @override
  void initState() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    ProfileManager.shared().setSchoolMode("private");

    _getStudentHistory();

    _delaySmall();

    checkInternet().then((value){
      setState((){ isConnected = value;});
    });

    // _askStoragePermission();

    _getFilePath().then((value){
      setState((){ filepath = value;});
    });

    // localVideos = ProfileManager.shared().getLocalVideoList();

    /* _getLocalVideoList().then((value){
      print ("******************* LOCAL VIDEO LIST \n $value");
      setState(() {
        localVideos = value;
        //  showToast("Total saved: ${value.length}", Colors.blue);
      });
    });*/

    setState(() {
      localVideos = ProfileManager.shared().getLocalVideoList();
    });

    /* getLocalVideoList().then((vidList){
      setState(() {
        localVideos = vidList;
      });
    });*/

    // showToast("Total saved: ${localVideos.length}", Colors.blue);

    print("--------------------------------------> ### getPlayPrevious() = ${ProfileManager.shared().getPlayPrevious()}");

   // ProfileManager.shared().setPlayPrevious(false);
    toggleDrawer();
    if (ProfileManager.shared().getIsStudentLoggedIn() == true ||
        ProfileManager.shared().getPlayHistoryOrFavourite() == false) {
      ProfileManager.shared().clearLessons();
      _isLoading = true;

      print('making network call for makeNetworkCalls');
      makeNetworkCalls().then((e) {});
    }


    else {
      if (ProfileManager.shared().getPlayPrevious() == true) {
        print("--------------------------------------> ### getPlayPrevious() = ${ProfileManager.shared().getPlayPrevious()}");
        _isLoading = true;
        ProfileManager.shared().clearLessons();
        fetchLessons(
            classId: ProfileManager.shared().getClassId(),
            query: ProfileManager.shared().getPlayPrevious() == true
                ? "play_on=${ProfileManager.shared().getLessonQueryDate()}"
                : "play_on=${ProfileManager.shared().getClassVideoPlayOn()}")
            .timeout(
          TIMEOUT_DURATION,
          onTimeout: () {
            setState(() {
              _isLoading = false;
            });

            return _showTimeoutDialog();
          },
        ).then((value) {
          if (value.statusCode == 200) {
            print("################# CLASS LESSONS FETCHED");
            var list = value.data.toList();
            ProfileManager.shared().addLessons(list);

            list.forEach((e) {
              ProfileManager.shared().addLessonIds(e.lessonId);
              ProfileManager.shared().addLessonPeriodTitles(e.periodTitle);
              ProfileManager.shared().addLessonSubjects(e.subject);
              ProfileManager.shared().addLessonVimeoIds(e.vimeoId);
              ProfileManager.shared().addLessonTopicNames(e.topicName);
              ProfileManager.shared().addLessonNotesUrls(e.notesUrl);
              ProfileManager.shared().addLessonTeacherName(e.teacherName);
              ProfileManager.shared().addLessonClassIds(e.classId); // #debug -->
              //local video link
              // ProfileManager.shared().addLocalVideoLink(e.localvideoLink);
            });
            print("###---------------------------> LessonIds: ${ProfileManager.shared().getLessonIds()}");
            print("###-----------------------------> ClassIds: ${ProfileManager.shared().getLessonClassIds()}");
            print("###----------------------------> VimeoIds: ${ProfileManager.shared().getLessonVimeoIds()}");
          }
        });
      }

      ComplexDatePickerHome.markedDateMap.clear();
      downloadingList.clear();

      fetchClassYears(ProfileManager.shared().getClassId()).then((value) {
        if (value.statusCode == 200) {
          print("################# CLASS YEAR FETCHED");

          value.data.forEach((e) {
            years.add(e.year.toString());
          });

          fetchClassSemesters(
              classId: ProfileManager.shared().getClassId(), year: years[0])
              .then((value) {
            if (value.statusCode == 200) {
              print("################# CLASS SEMESTERS FETCHED");
              value.data.forEach((element) {
                semesters.add(element.name);
                semesterIds.add(element.id.toString());
                semesterEndDates.add(element.dateEnd);
                semesterStartDates.add(element.dateBegin);
              });

              semesterIds.forEach((id) {
                Widget _eventIcon(String day) => Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(
                      Radius.circular(5),
                    ),
                  ),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: buttonColorBlue.withOpacity(0.6),
                      borderRadius: BorderRadius.all(
                        Radius.circular(5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        day,
                        style:
                        TextStyle(color: Colors.black.withOpacity(0.7)),
                      ),
                    ),
                  ),
                );
                fetchEvents(
                    classId: ProfileManager.shared().getClassId(),
                    semesterId: id)
                    .then((value) {
                  print("################# EVENTS FETCHED");
                  print(value.data);
                  if (value.statusCode == 200) {
                    print("################# EVENTS FETCHED");
                    if (value.data.isNotEmpty) {
                      value.data.forEach((element) {
                        DateTime dateTime = DateTime.parse(element);
                        ComplexDatePickerHome.markedDateMap.add(
                            dateTime,
                            Event(
                              icon: _eventIcon(dateTime.day.toString()),
                              date: dateTime,
                              title: element,
                            ));
                      });
                    }
                    /* setState(() {
                      _isLoading = false;
                      if (ProfileManager.shared().getPlayPrevious() == true) {
                        if (Platform.isAndroid) {
                          PlayerManager.shared().disposeControllers();
                        }
                        print("PLAYER: #6");
                        initVimeoPlayer(
                            ProfileManager.shared().getLessonVimeoIds()[0])
                            .then((videoList) {
                              //debug_offline
                          getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
                            if(value.isNotEmpty){
                              PlayerManager.shared()
                                  .changeActiveUrl(value,isLocal: true);
                              FirebaseManager.shared()
                                  .getAllChatMessagesForRoom(ProfileManager.shared()
                                  .getLessonSubjects()[selected])
                                  .then((value) {
                                _chatItems = value;

                                _chatItems.forEach((e) {
                                  _chatProfileImages.add(e.data["userImage"]);
                                });
                              });
                            }else {
                              //default
                              PlayerManager.shared()
                                  .changeActiveUrl(selectedVideo.url);
                              FirebaseManager.shared()
                                  .getAllChatMessagesForRoom(ProfileManager.shared()
                                  .getLessonSubjects()[selected])
                                  .then((value) {
                                _chatItems = value;

                                _chatItems.forEach((e) {
                                  _chatProfileImages.add(e.data["userImage"]);
                                });
                              });
                            }
                          });

                        });
                      }
                    });*/
                  }
                });
              });
            } else {
              semesters.add("No record available");
            }

            if (Platform.isAndroid) {
              setState(() {
                _isLoading = false;
                print("############# init player in semesters");

                print("1");
                initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[0])
                    .then((videoList) {
                  //debug_offline
                  getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
                    if(!value.isEmpty){
                      PlayerManager.shared()
                          .changeActiveUrl(value,isLocal: true);
                      FirebaseManager.shared()
                          .getAllChatMessagesForRoom(ProfileManager.shared()
                          .getLessonSubjects()[selected])
                          .then((value) {
                        _chatItems = value;

                        _chatItems.forEach((e) {
                          _chatProfileImages.add(e.data()["userImage"]);
                        });
                      });
                    }else {
                      //default
                      PlayerManager.shared()
                          .changeActiveUrl(selectedVideo.url);
                      FirebaseManager.shared()
                          .getAllChatMessagesForRoom(ProfileManager.shared()
                          .getLessonSubjects()[selected])
                          .then((value) {
                        _chatItems = value;

                        _chatItems.forEach((e) {
                          _chatProfileImages.add(e.data()["userImage"]);
                        });
                      });
                    }
                  });
                });
              });
            }
          });
          setState(() {
            _isLoading = false;
            print("############# init player after semesters");
            if (Platform.isAndroid) {
              PlayerManager.shared().disposeControllers();
            }
            print("2");

            initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[0])
                .then((videoList) {
              //debug_offline
              getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
                if(!value.isEmpty){
                  PlayerManager.shared()
                      .changeActiveUrl(value,isLocal: true);
                  FirebaseManager.shared()
                      .getAllChatMessagesForRoom(ProfileManager.shared()
                      .getLessonSubjects()[selected])
                      .then((value) {
                    _chatItems = value;

                    _chatItems.forEach((e) {
                      _chatProfileImages.add(e.data()["userImage"]);
                    });
                  });
                }else {
                  //default
                  PlayerManager.shared()
                      .changeActiveUrl(selectedVideo.url);
                  FirebaseManager.shared()
                      .getAllChatMessagesForRoom(ProfileManager.shared()
                      .getLessonSubjects()[selected])
                      .then((value) {
                    _chatItems = value;

                    _chatItems.forEach((e) {
                      _chatProfileImages.add(e.data()["userImage"]);
                    });
                  });
                }
              });
            });
          });
        }
      });
    }

    //initBambuserPlayer();

    _blueOutlineButton = BlueOutlineButton(
      onTap: _getNotesButtonCallback,
    );
    _clickableText = ClickableText(
      onTap: _learnMoreButtonCallback,
    );

    selected = widget.initialIndex; /* Click handler for program listing */
    isToggleButtonSelected = [
      /* Click handler for ToggleButton */
      true,
      false,
      false
    ];
    PlayerManager.shared().initController().then((_) {
      setState(() {});
    }).catchError((error) {});

    super.initState();

    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
  }

  //----------------------> END OF INIT   -------------------------------------/////

  Future<void> initVimeoPlayer(String vimeoId) async {
    await VimeoManager.shared().getVideoData(vimeoId).then((videoList) {
      print("video sizes: " + videoList.length.toString());
      setState(() {
        _videoList = videoList;

        if (Platform.isIOS) {
          _isProgramItemCLickable = false;
        }

        if (Platform.isAndroid) {
          Timer(Duration(seconds: 1), () {
            setState(() {
              _isProgramItemCLickable = false;
            });
          });
        }

        if (ProfileManager.shared().getPreselectVideoQuality() == null) {
          selectedVideo = _videoList[0];
        } else {
          selectedVideo =
          _videoList[ProfileManager.shared().getPreselectVideoQuality()];
        }
      });
    });
  }

  Future makeNetworkCalls() async {
    print(ProfileManager.shared().getInstitutionId());
    await fetchSchoolDetails(ProfileManager.shared().getSchoolId()).timeout(
      TIMEOUT_DURATION,
      onTimeout: () {
        setState(() {
          _isLoading = false;
        });

        return _showTimeoutDialog();
      },
    ).then((value) {
      if (value.statusCode == 200) {
        print("################# SCHOOL FOR INSTITUTE FETCHED");
        ProfileManager.shared().setSchoolLogo(value.data.logoUrl);

        print(
            "CLASS ID ON HOMESCREEN: ${ProfileManager.shared().getClassId()}");

        fetchClassDetails(ProfileManager.shared().getClassId()).timeout(
          TIMEOUT_DURATION,
          onTimeout: () {
            setState(() {
              _isLoading = false;
            });

            return _showTimeoutDialog();
          },
        ).then((value) {
          if (value.statusCode == 200) {
            print("################# CLASS DETAILS FETCHED");
            ProfileManager.shared().setClassName(value.data.name);
            ProfileManager.shared().setClassFullName(value.data.fullName);
            ProfileManager.shared().setClassIsLocked(value.data.locked);
            ProfileManager.shared().setClassVimeoId(value.data.vimeoId);
            ProfileManager.shared().setClassViewCount(value.data.viewCount);
            ProfileManager.shared().setSchoolName(value.data.schoolName);

            var videoList = value.data.video;

            videoList.forEach((e) {
              ProfileManager.shared().setClassVideoPlayOn(e.playOn);
              ProfileManager.shared().setClassTeacherName(e.teacher.name);
              print(e.teacher.name);
            });

            fetchLessons(
                classId: ProfileManager.shared().getClassId(),
                query: ProfileManager.shared().getPlayPrevious() == true
                    ? "play_on=${ProfileManager.shared().getLessonQueryDate()}"
                    : "play_on=${ProfileManager.shared().getClassVideoPlayOn()}")
                .timeout(
              TIMEOUT_DURATION,
              onTimeout: () {
                setState(() {
                  _isLoading = false;
                });

                return _showTimeoutDialog();
              },
            ).then((value) {
              if (value.statusCode == 200) {
                ProfileManager.shared().clearLessons();

                print("################# CLASS LESSONS FETCHED");
                var list = value.data.toList();
                ProfileManager.shared().addLessons(list);

                list.forEach((e) {
                  ProfileManager.shared().addLessonIds(e.lessonId);
                  ProfileManager.shared().addLessonPeriodTitles(e.periodTitle);
                  ProfileManager.shared().addLessonSubjects(e.subject);
                  ProfileManager.shared().addLessonVimeoIds(e.vimeoId);
                  //Add locaUrl for caching/download
                  ProfileManager.shared().addLessonTopicNames(e.topicName);
                  ProfileManager.shared().addLessonNotesUrls(e.notesUrl);
                  ProfileManager.shared().addLessonTeacherName(e.teacherName);
                  ProfileManager.shared().addLessonClassIds(e.classId); // #debug -->
                });

                //----------------------------------------------------------->

                print("###---------------------------2> LessonIds: ${ProfileManager.shared().getLessonIds()}");
                print("###----------------------------2> ClassIds: ${ProfileManager.shared().getLessonClassIds()}");
                print("###----------------------------2> VimeoIds: ${ProfileManager.shared().getLessonVimeoIds()}");
                //----------------------------------------------------------->

                print("################ LESSON IDS 2:  ${ProfileManager.shared().getLessonIds()}");

                ComplexDatePickerHome.markedDateMap.clear();

                //debug
                //ComplexDatePickerHome.miniSelectedDate.


                fetchClassYears(ProfileManager.shared().getClassId()).timeout(
                  TIMEOUT_DURATION,
                  onTimeout: () {
                    setState(() {
                      _isLoading = false;
                    });

                    return _showTimeoutDialog();
                  },
                ).then((value) {
                  if (value.statusCode == 200) {
                    print("################# CLASS YEAR FETCHED");

                    value.data.forEach((e) {
                      years.add(e.year.toString());
                    });

                    fetchClassSemesters(
                        classId: ProfileManager.shared().getClassId(),
                        year: years[0])
                        .timeout(
                      TIMEOUT_DURATION,
                      onTimeout: () {
                        setState(() {
                          _isLoading = false;
                        });

                        return _showTimeoutDialog();
                      },
                    ).then((value) {
                      if (value.statusCode == 200) {
                        print("################# CLASS SEMESTERS FETCHED: ${value.data}");
                        value.data.forEach((element) {
                          semesters.add(element.name);
                          semesterIds.add(element.id.toString());
                          semesterEndDates.add(element.dateEnd);
                          print("+++++++++++++++++++ SEMESTER DATE END:  ${element.dateEnd}"); // YYYY-MM-DD
                          semesterStartDates.add(element.dateBegin);
                          print("+++++++++++++++++++ SEMESTER DATE START:  ${element.dateBegin}"); // YYYY-MM-DD
                        });

                        semesterIds.forEach((id) {
                          Widget _eventIcon(String day) => Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(5),
                              ),
                            ),
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: buttonColorBlue.withOpacity(0.6),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(5),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                      color: Colors.black.withOpacity(0.7)),
                                ),
                              ),
                            ),
                          );
                          fetchEvents(
                              classId: ProfileManager.shared().getClassId(),
                              semesterId: id)
                              .timeout(
                            TIMEOUT_DURATION,
                            onTimeout: () {
                              setState(() {
                                _isLoading = false;
                              });

                              return _showTimeoutDialog();
                            },
                          ).then((value) {
                            if (value.statusCode == 200) {
                              if (value.data.isNotEmpty) {
                                value.data.forEach((element) {
                                  DateTime dateTime = DateTime.parse(element);
                                  ComplexDatePickerHome.markedDateMap.add(
                                      dateTime,
                                      Event(
                                        icon: _eventIcon(dateTime.day.toString()),
                                        date: dateTime,
                                        title: element,
                                      ));
                                });
                              }
                            }
                          });
                        });
                      } else {
                        semesters.add("No record available");
                      }

                      setState(() {
                        _isLoading = false;
                        print("############# init player in semesters");
                        print("PLAYER: #3");
                        if (Platform.isAndroid) {
                          initVimeoPlayer(ProfileManager.shared()
                              .getLessonVimeoIds()[0])
                              .then((videoList) {
                            /* PlayerManager.shared()
                                .changeActiveUrl(selectedVideo.url); */
                          });
                        }
                      });
                    });
                    setState(() {
                      _isLoading = false;
                      print("############# init player after semesters");
                      /* if (Platform.isAndroid) {
                        PlayerManager.shared().disposeControllers();
                      } */
                      print("PLAYER: #4");
                      if (Platform.isIOS) {
                        initVimeoPlayer(
                            ProfileManager.shared().getLessonVimeoIds()[0])
                            .then((videoList) {
                          PlayerManager.shared()
                              .changeActiveUrl(selectedVideo.url);
                        });
                      }
                    });
                  }
                });
              } else {
                setState(() {
                  _isLoading = false;
                  _showNoLessonsAvailableDialog();
                });
              }
            });
          }
        });
      }
    });
  }

  _showNoLessonsAvailableDialog() {
    return showDialog(
      context: context,
      builder: (BuildContext context) => Center(
        child: CustomDialogPopup(
          description:
          "The selected class does not yet contain lessons. Try again later",
          disableButton: true,
        ),
      ),
    );
  }

  _showTimeoutDialog() {
    return showDialog(
      context: context,
      builder: (BuildContext context) => Center(
        child: CustomDialogPopup(
          description: TIMEOUT_TEXT,
          disableButton: true,
        ),
      ),
    );
  }

  Future<String> getLocalVidUri(String index)async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(index) ?? "";
  }

/*
  void initBambuserPlayer() {
    if (Platform.isIOS) {
      _bambuseriOSPlayerController =
      new bambuseriOSPlugin.BambuserPlayerController(onInit: () {
        _bambuseriOSPlayerController.play();
      });

      bambuseriOSPlayer = bambuseriOSPlugin.BambuserPlayer(
        appId: _appIdIOS,
        uri: _resourceURI,
        controller: _bambuseriOSPlayerController,
        placeholder: Center(
          child: Container(
            height: 100.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                  child: Text("LOADING",
                      style: (TextStyle(
                          fontFamily: "Montserrat Normal",
                          fontWeight: FontWeight.normal,
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          letterSpacing: 1.5))),
                )
              ],
            ),
          ),
        ),
      );
      _bambuseriOSPlayerController.addListener(() {
        setState(() {
          if (_bambuseriOSPlayerController.playingState ==
              bambuseriOSPlugin.PlayingState.PLAYING) {
            _isBambuserPlaying = true;
          } else {
            _isBambuserPlaying = false;
          }
        });
      });
    }

    if (Platform.isAndroid) {
      _bambuserAndroidPlayerController =
      new bambuserAndroidPlugin.BambuserPlayerController(onInit: () {
        _bambuserAndroidPlayerController.play();
      });

      bambuserAndroidPlayer = bambuserAndroidPlugin.BambuserPlayer(
        appId: _appIdAndroid,
        uri: _resourceURI,
        controller: _bambuserAndroidPlayerController,
        placeholder: Center(
          child: Container(
            height: 100.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                  child: Text("LOADING",
                      style: (TextStyle(
                          fontFamily: "Montserrat Normal",
                          fontWeight: FontWeight.normal,
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          letterSpacing: 1.5))),
                )
              ],
            ),
          ),
        ),
      );
      _bambuserAndroidPlayerController.addListener(() {
        setState(() {
          if (_bambuserAndroidPlayerController.playingState ==
              bambuserAndroidPlugin.PlayingState.PLAYING) {
            _isBambuserPlaying = true;
          } else {
            _isBambuserPlaying = false;
          }
        });
      });
    }
  }
*/

 /* void resetBambuserPlayer() {
    if (Platform.isIOS) {
      _bambuseriOSPlayerController.stop();
      _bambuseriOSPlayerController = null;
      bambuseriOSPlayer = null;
    }
    if (Platform.isAndroid) {
      _bambuserAndroidPlayerController.stop();
      _bambuserAndroidPlayerController = null;
      bambuserAndroidPlayer = null;
    }
  }*/

  _getNotesButtonCallback() {
    if (_isGetNotesButtonClicked == false) {
      setState(() {
        _isGetNotesButtonClicked = true;
        _buildGetNotesDialog();
      });
    } else {
      setState(() {
        _isGetNotesButtonClicked = false;
      });
    }
  }

/* Button Callback Section */
  _learnMoreButtonCallback() {
    if (PlayerManager.shared().isVLCPlaying() == true) {
      PlayerManager.shared().pause();
    }

    Navigator.push(context, FadeRoute(page: ArticleContentViewScreen()));
  }

  _noInternetRefreshButtonCallback() {
    return null;
  }

  _downloadDoneButtonCallback() {
    Navigator.pop(context);
    _isGetNotesButtonClicked = false;
  }

  _rewindButtonCallback() {

    List<String> locallyvid =  ProfileManager.shared().getLocalVideoList();

    checkInternet().then((value){
      if(value){
        if (selected > 0) {
          setState(() {
            _closeBottomsheet();
            selected = selected - 1;
            _isVimeoPlaying = true;
            /* if (Platform.isAndroid) {
          PlayerManager.shared().disposeControllers();
        } */

            //debug_offline
            getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
              if(value.isNotEmpty){
                PlayerManager.shared().changeActiveUrl(value,isLocal: true);
                if (Platform.isAndroid) {
                  //  _videoSlider.sliderValue = 0.0;
                }

              }else {
                initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[selected])
                    .then((videoList) {
                  PlayerManager.shared().changeActiveUrl(selectedVideo.url);
                });
                _addLessonToHistory(ProfileManager.shared().getLessonIds()[selected]);
                if (Platform.isAndroid) {
                  _videoSlider.sliderValue = 0.0;
                }
              }
            });


          });
        }
      }else {

        if (selected > 0) {

          setState(() {
            _closeBottomsheet();
            selected = selected - 1;
            if(!locallyvid.contains(ProfileManager.shared().getLessonIds()[selected])){
              showToast("No internet available", Colors.red);
            }
            _isVimeoPlaying = true;
            /* if (Platform.isAndroid) {
          PlayerManager.shared().disposeControllers();
        } */

            //debug_offline
            getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
              if(value.isNotEmpty){

                //  PlayerManager.shared().disposeControllers();
                PlayerManager.shared().changeActiveUrl(value,isLocal: true);
                if (Platform.isAndroid) {
                  //  _videoSlider.sliderValue = 0.0;
                }

              }else {
                PlayerManager.shared().changeActiveUrl(selectedVideo.url);

               /* initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[selected])
                    .then((videoList) {
                  PlayerManager.shared().changeActiveUrl(selectedVideo.url);
                });
                _addLessonToHistory(ProfileManager.shared().getLessonIds()[selected]);*/
                if (Platform.isAndroid) {
                  _videoSlider.sliderValue = 0.0;
                }
              }
            });


          });
        }
      }
    });

  }

  _forwardButtonCallback() {
    List<String> locallyvid =  ProfileManager.shared().getLocalVideoList();

    checkInternet().then((value){
      if(value){
        if (selected < ProfileManager.shared().getLessonPeriodTitles().length - 1) {
          setState(() {
            _closeBottomsheet();
            selected += 1;
            _isVimeoPlaying = false;
            // _isVimeoPlaying = true;
            /* if (Platform.isAndroid) {
          PlayerManager.shared().disposeControllers();
        } */
            //debug_offline
            getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
              if(value.isNotEmpty){
                //  PlayerManager.shared().disposeControllers();
                PlayerManager.shared().changeActiveUrl(value,isLocal: true);
                if (Platform.isAndroid) {
                  //  _videoSlider.sliderValue = 0.0;
                }

              }else {
                _isVimeoPlaying = true;
                initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[selected])
                    .then((videoList) {
                  PlayerManager.shared().changeActiveUrl(selectedVideo.url);
                });
                _addLessonToHistory(ProfileManager.shared().getLessonIds()[selected]);
                if (Platform.isAndroid) {
                  _videoSlider.sliderValue = 0.0;
                }
              }
            });
          });
        }
        //-------------end of internet check
      }else {
        if (selected < ProfileManager.shared().getLessonPeriodTitles().length - 1) {
          setState(() {
            _closeBottomsheet();
            selected += 1;
            if(!locallyvid.contains(ProfileManager.shared().getLessonIds()[selected])){
              showToast("No internet available", Colors.red);
            }
            _isVimeoPlaying = true;
            /* if (Platform.isAndroid) {
          PlayerManager.shared().disposeControllers();
        } */
            //debug_offline
            getLocalVidUri(ProfileManager.shared().getLessonIds()[selected]).then((value){
              if(value.isNotEmpty){
              //  PlayerManager.shared().disposeControllers();
               /* print("######## LOCAL URL: $value");
                showToast("# LOCAL URL: $value", Colors.blue);
                Navigator.push(context, MaterialPageRoute(builder: (context) => OfflinePlayer(uri:value ,)));*/
                  PlayerManager.shared().changeActiveUrl(value,isLocal: true);

              }else {
                PlayerManager.shared().changeActiveUrl(selectedVideo.url);

               /* initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[selected])
                    .then((videoList) {
                  PlayerManager.shared().changeActiveUrl(selectedVideo.url);
                });
                _addLessonToHistory(ProfileManager.shared().getLessonIds()[selected]);
                */
                if (Platform.isAndroid) {
                  _videoSlider.sliderValue = 0.0;
                }
              }
            });
          });
        }
        //-------------end of internet check
      }
    });


  }
/* End of Button Callback Section */

/* Scrabber/Slider for landscape */
  bool _isBottomsheetOpen = false;
  Timer _timer;
  VideoSlider _videoSlider = VideoSlider();
/* End of Scrabber/Slider for landscape */

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      //set default overlay for iOS
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarBrightness: Brightness.dark,
      ));
    }
    if (Platform.isAndroid) {
      //set default overlay for android
      /*SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
        statusBarColor: Colors.transparent,
      ));*/
    }
    SizeConfig().init(context);

    return WillPopScope(
      //if Tutor was logged in, back button should work, since this screen is accessible from the tutor flow
        onWillPop: _onBackPressed,
        /*() async => Platform.isAndroid &&
                    ProfileManager.shared().getIsTutorLoggedIn() == true ||
                ProfileManager.shared().getPlayHistoryOrFavourite() == true
            ? true
            : false,*/
        child: Material(
          child:
          OrientationBuilder(builder: (BuildContext context, orientation) {
            return Stack(
              children: [
                Container(
                  child: _buildPortraitScreen(orientation),
                ),
                /* _showRotateAnimation == true
                    ? _showRotateAnimationScreen(orientation)
                    : Offstage(), */
                _isLoading == true
                    ? Container(color: Colors.black26)
                    : Offstage()
              ],
            );
          }),
        ));
  }

  _buildLocalPlayer(String LessonId){
    return OfflinePlayerHome(lessonId: LessonId);
  }

  void _changeOpacity() {
    setState(() => opacityLevel = opacityLevel == 0 ? 1.0 : 0.0);
  }

  _showRotateAnimationScreen(Orientation orientation) {
    return AnimatedOpacity(
      opacity: opacityLevel,
      duration: Duration(milliseconds: 3000),
      /* child: Container(
          height: orientation == Orientation.portrait
              ? (SizeConfig.blockSizeVertical * 26) +
                  (MediaQuery.of(context).padding.top)
              : SizeConfig.blockSizeVertical * 100,
          width: orientation == Orientation.portrait
              ? SizeConfig.blockSizeVertical * 100
              : SizeConfig.blockSizeHorizontal * 100,
          color: Colors.black.withOpacity(0.6),
          child: Stack(
            children: [
              FlareActor(
                  orientation == Orientation.portrait
                      ? "assets/animations/rotate_screen.flr"
                      : "assets/animations/rotate_screen_to_portrait.flr",
                  alignment: Alignment.center,
                  fit: BoxFit.contain,
                  animation: "idle"),
              Positioned(
                  bottom: 20,
                  right: 0,
                  left: 0,
                  child: Center(
                    child: Text("rotate the screen",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: SizeConfig.safeBlockHorizontal * 5,
                            fontFamily: "Roboto")),
                  )),
            ],
          )) ,*/
    );
  }

  _buildPortraitScreen(Orientation orientation) {
    bool loadFromDisk = false;
    List<String> locallyvid =[];
    locallyvid =  ProfileManager.shared().getLocalVideoList();

    String lessonID;

    try{

      lessonID = ProfileManager.shared().getLessonIds()[selected];

    }
    catch (e) {
      lessonID = "";
      print("exception $e");
    }

    _isLandscapeActive = false;
    var width = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Scaffold(
          key: scaffoldKey,
          drawerEdgeDragWidth:
          ProfileManager.shared().getIsStudentLoggedIn() == true ? 0 : null,
          //resizeToAvoidBottomInset: false,
          drawer: ProfileManager.shared().getIsStudentLoggedIn() == true
              ? Container(
            width: width * 0.85,
            child: Drawer(
              child: _buildDrawer(),
            ),
          )
              : Offstage(),
          body: Container(
            child: Column(
              children: [
                Container(
                  height: orientation == Orientation.portrait
                      ? MediaQuery.of(context).viewPadding.top
                      : 0,
                  color: Colors.black,
                ),
                 isLoaded ?
                locallyvid.isEmpty ? _portraitVimeoPlayerSection(orientation):
                locallyvid.contains(ProfileManager.shared().getLessonIds()[selected]) ?
                //  Container(width: 600,height: 200, color:Colors.yellow,) : _portraitVimeoPlayerSection(orientation)
                _portraitVimeoPlayerSection(orientation,isLocalMedia: true,uri: 'file://$filepath/${ProfileManager.shared().getLessonIds()[selected]+'.mp4'}')
                    : _portraitVimeoPlayerSection(orientation)

                    : Column(
                  children: [
                    SizedBox(height: 30,),
                    CircularProgressIndicator(),
                    SizedBox(height: 30,),
                  ],
                )
                ,
                orientation == Orientation.portrait
                    ? Container(
                  //height: SizeConfig.safeBlockVertical * 34.4,
                  child: Column(
                    children: [
                      _buildPortraitVideoPlayerController(),
                      _buildToggleButtons()
                    ],
                  ),
                )
                    : SizedBox(),
                orientation == Orientation.portrait
                    ? Expanded(
                  child: GestureDetector(
                    onTap: () {
                      SystemChannels.textInput
                          .invokeMethod('TextInput.hide');
                    },
                    child: Container(
                      color: programBackgroundColorInactive,
                      child: isToggleButtonSelected[0]
                          ? _materialsButtonClicked == false
                          ? _buildVideoProgram()
                          : (  _materialsButtonSummaryClicked ? _buildMaterialsDownloadScreen() : Container(child: _buildPrevious(),))
                          : isToggleButtonSelected[1]
                          ? ChatPage(lessonID: lessonID,user: ChatUser.User(name: ProfileManager.shared().getUsername()))
                          : isToggleButtonSelected[2]
                          ?   FullScreenLocal(
                        pdfUrl: noteUrl
                        ,isOnline: noteUrl.startsWith("http")|| noteUrl.startsWith("https") ? true :false,)
                          :ChatPage(lessonID: lessonID,user: ChatUser.User(name: ProfileManager.shared().getUsername())),
                    ),
                  ),
                )
                    : SizedBox(),
              ],
            ),
          ),
        ),
        _isQualityButtonClicked == true ? _buildQualityDropdown() : SizedBox(),
        _isGetNotesButtonClicked == true ? _buildGetNotesDialog() : SizedBox(),
        orientation == Orientation.portrait
            ? ProfileManager.shared().getIsTutorLoggedIn() == true ||
            ProfileManager.shared().getPlayHistoryOrFavourite() == true
            ? Container(
          height: SizeConfig.safeBlockVertical * 10,
          width: MediaQuery.of(context).size.width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios),
                onPressed: () {
                  PlayerManager.shared().disposeControllers();
                  Navigator.pop(context);
                },
                color: Colors.white,
              )
            ],
          ),
        )
            : SizedBox()
            : Container()
      ],
    );
  }

  _portraitVimeoPlayerSection(Orientation orientation, {bool isLocalMedia = false,String uri=""}) {

    /*  checkInternet().then((value){
        setState(() {
          isChecked = true;
        });
        if(!value){
          showToast("No Internet", Colors.red);
        }

      });*/
    String localvideUri;
    print("**************$uri");



    var _width = SizeConfig.blockSizeHorizontal * 100;
    return Container(
      height: orientation == Orientation.portrait
          ? (_width / 16) * 9
          : SizeConfig.blockSizeVertical * 100,
      width: _width,
      child: Stack(children: [
        Container(
          // color: Colors.red,
          color: Colors.black,
          child: selectedVideo.url != null ?

          SizedBox.expand(
            child: PlayerManager.shared()
                .createVideoPlayer(isLocalMedia ? uri: selectedVideo.url,isLocalMedia:isLocalMedia
            ),
          )
              : isLocalMedia ?
          SizedBox.expand(
            child: PlayerManager.shared()
                .createVideoPlayer(isLocalMedia ? uri: selectedVideo.url,isLocalMedia:isLocalMedia
            ),
          )
              : Container(),
          width: SizeConfig.blockSizeHorizontal * 100,
          height: SizeConfig.blockSizeVertical * 100,
        ),
        GestureDetector(
          onTap: () {
            if (orientation == Orientation.landscape) {
              if (_timer == null) {
                print("start timer");
                _timer = Timer.periodic(Duration(seconds: 1), (timer) {
                  print("Timer tick");
                  //refresh slider
                  if (Platform.isIOS) {
                    setState(() {
                      PlayerManager.shared().position().then((value) {
                        _videoSlider.sliderValue = value.toDouble();
                      });
                    });
                  }
                });
                Future.delayed(Duration(seconds: 10)).then((value) {
                  _timer.cancel();
                  _timer = null;
                  print("TIMER CANCELLED!");

                  if (_isBottomsheetOpen == true) {
                    Navigator.pop(context);
                  }
                });
              }
              if (_isBottomsheetOpen == false) {
                print("bottoms sheet is open: $_isBottomsheetOpen");
                _isBottomsheetOpen = true;
              }

              _buildLandscapeBottomSheet();
            }
          },
          /* child: Container(color: Colors.transparent) */
        )
      ]),
    );
  }
/*

  _portraitBambuserVideoSection() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
          width: SizeConfig.blockSizeHorizontal * 100,
          color: Colors.black,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Stack(
                    children: [
                      Platform.isIOS
                          ? bambuseriOSPlayer
                          : bambuserAndroidPlayer,
                    ],
                  )),
            ),
          )),
    );
  }
*/

  _buildLandscapeBottomSheet() {
    setState(() {});
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          width: double.infinity,
          //height: 500.0,
          //margin: EdgeInsets.only(top: 30),
          child: Stack(
            children: [
              Container(
                height: 350,
                //color: Colors.red,
                color: Colors.transparent,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _isQualityButtonClicked = false;
                      },
                      child: Container(
                        color: Colors.transparent,
                        height: 280,
                      ),
                    ),
                    Container(
                      height: 70,
                      color: Colors.white.withOpacity(0.8),
                      child: Row(
                        children: <Widget>[
                          Center(
                           child: _buildLandscapeVideoPlayerController(context))
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _isQualityButtonClicked == true
                  ? _buildQualityDropdown()
                  : SizedBox(),
              _isBambuserVisible == false
                  ? Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: SizedBox(child: _videoSlider))
                  : SizedBox(),
            ],
          ),
        )).whenComplete(() {
      _isBottomsheetOpen = false;
    });
  }

 /* _buildLandscapeBambuserPlayer() {
    initBambuserPlayer();
    return Container(
      child: Container(
          color: Colors.black,
          child: Platform.isIOS ? bambuseriOSPlayer : bambuserAndroidPlayer),
    );
  }*/

/*
  _buildLandscapeBambuserPlayerController(BuildContext context) {
    var _height = MediaQuery.of(context).size.height;
    return Container(
      height: (_height / 10) * 0.6,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.only(left: 40, right: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                playOrPauseVideo();
              },
              child: Container(
                child: _isBambuserPlaying
                    ? Image.asset(
                  "assets/icons/pause_icon.png",
                  width: 15,
                )
                    : Image.asset(
                  "assets/icons/play_icon.png",
                  width: 15,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitDown,
                  DeviceOrientation.portraitUp
                ]);
                Navigator.of(context).maybePop();
              },
              child: Container(
                child: Image.asset(
                  "assets/icons/fullscreen_icon.png",
                  width: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
*/

  _buildLandscapeVideoPlayerController(BuildContext context) {
    var _height = MediaQuery.of(context).size.height;
    return Container(
      height: (_height / 10) * 0.6,
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              PlayerManager.shared().isVLCPlaying().then((value) {
                setState(() {
                  _closeBottomsheet();
                  _isVimeoPlaying = !value;
                  !_isVimeoPlaying
                      ? PlayerManager.shared().pause()
                      : PlayerManager.shared().play();
                });
              });
            },
            child: Container(
              child: _isVimeoPlaying
                  ? Image.asset(
                "assets/icons/pause_icon.png",
                width: 15,
              )
                  : Image.asset(
                "assets/icons/play_icon.png",
                width: 15,
              ),
            ),
          ),
          GestureDetector(
            onTap: _rewindButtonCallback,
            child: Container(
              child: Image.asset(
                "assets/icons/rewind_icon.png",
                width: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: _forwardButtonCallback,
            child: Container(
              child: Image.asset(
                "assets/icons/forward_icon.png",
                width: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                String currentLessonId =
                ProfileManager.shared().getLessonIds()[selected];

                if (ProfileManager.shared().getIsTutorLoggedIn() == true ||
                    ProfileManager.shared().getIsStudentLoggedIn() == true) {
                  if (ProfileManager.bookmarkedPrograms
                      .contains(currentLessonId)) {
                    _deleteBookmarkedLesson();

                    _closeBottomsheet(); // close bottoms sheet

                    ProfileManager.bookmarkedPrograms
                        .remove(currentLessonId); //manage UI icon change

                    print(ProfileManager.bookmarkedPrograms);
                  } else {
                    _bookmarkLesson();

                    _closeBottomsheet(); // close bottoms sheet

                    ProfileManager.bookmarkedPrograms
                        .add(currentLessonId); //manage UI icon change
                    print(ProfileManager.bookmarkedPrograms);
                  }
                }

                if (ProfileManager.shared().getIsTutorLoggedIn() == false &&
                    ProfileManager.shared().getIsStudentLoggedIn() == false) {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) =>
                          LoginRegisterDialogPopup(
                              description:
                              "Login or Register to bookmark Lessons"));
                }
              });
            },
            child: Container(
              child: ProfileManager.shared().getLessonIds().isEmpty
                  ? Image.asset(
                "assets/icons/bookmark_icon.png",
                width: 15,
              )
                  : ProfileManager.bookmarkedPrograms.contains(
                  ProfileManager.shared()
                      .getLessonIds()[selected]) ==
                  true
                  ? Image.asset(
                "assets/icons/bookmark_red.png",
                width: 15,
              )
                  : Image.asset(
                "assets/icons/bookmark_icon.png",
                width: 15,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_isQualityButtonClicked == false) {
                setState(() {
                  _isQualityButtonClicked = true;
                });
              } else {
                setState(() {
                  _isQualityButtonClicked = false;
                });
              }
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  child: _isQualityButtonClicked
                      ? Image.asset(
                    "assets/icons/HD_blue.png",
                    width: SizeConfig.safeBlockHorizontal * 7.2,
                  )
                      : Image.asset(
                    ProfileManager.shared().getChosenVideoQualityIcon() ==
                        null
                        ? "assets/icons/HD_icon.png"
                        : ProfileManager.shared()
                        .getChosenVideoQualityIcon(),
                    width: SizeConfig.safeBlockHorizontal * 7.2,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_isBottomsheetOpen == true) {
                Navigator.pop(context);
              }
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown
              ]);
            },
            child: Container(
              child: Image.asset(
                "assets/icons/fullscreen_icon.png",
                width: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _closeBottomsheet() {
    setState(() {});
    if (_isBottomsheetOpen == true) {
      Timer(Duration(milliseconds: 300), () {
        Navigator.pop(context);
        _isBottomsheetOpen = false;
      });
    }

    // close bottoms sheet
  }

  _buildNoInternetDialog() {
    return Center(
      child: CustomDialogPopup(
        disableTitle: true,
        buttonText: "Refresh",
        description:
        "The app is not connected to the internet. Please enable data connection!",
        onTap: _noInternetRefreshButtonCallback,
      ),
    );
  }

  _buildDrawer() {
    return LeftDrawer();
  }

  _buildPortraitVideoPlayerController() {
    var _height = MediaQuery.of(context).size.height;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      height: (_height / 10) * 0.6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
              onTap: () {
                PlayerManager.shared().isVLCPlaying().then((value) {
                  setState(() {
                    _isVimeoPlaying = !value;
                    !_isVimeoPlaying
                        ? PlayerManager.shared().pause()
                        : PlayerManager.shared().play();
                  });
                });
              },
              child: Container(
                  color: Colors.transparent,
                  width: SizeConfig.blockSizeHorizontal * 100 / 6,
                  child: Center(
                      child: _isVimeoPlaying
                          ? Image.asset(
                        "assets/icons/pause_icon.png",
                        width: Platform.isAndroid
                            ? SizeConfig.safeBlockHorizontal * 3
                            : SizeConfig.safeBlockVertical * 1.7,
                      )
                          : Image.asset(
                        "assets/icons/play_icon.png",
                        width: Platform.isAndroid
                            ? SizeConfig.safeBlockHorizontal * 3
                            : SizeConfig.safeBlockVertical * 1.7,
                      )))),
          GestureDetector(
            onTap: () {
              _rewindButtonCallback();
            },
            child: Container(
                width: SizeConfig.blockSizeHorizontal * 100 / 6,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    child: Image.asset(
                      selected == 0 ? "assets/icons/rewind_icon_grey.png" : "assets/icons/rewind_icon.png",
                      width: Platform.isAndroid
                          ? SizeConfig.safeBlockHorizontal * 4
                          : SizeConfig.safeBlockVertical * 2.2,
                    ),
                  ),
                )),
          ),
          GestureDetector(
            onTap: () {
              _forwardButtonCallback();
            },
            child: Container(
                width: SizeConfig.blockSizeHorizontal * 100 / 6,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    child: Image.asset(
                      selected == ProfileManager.shared().getLessonIds().length - 1 ? "assets/icons/forward_icon_grey.png":"assets/icons/forward_icon.png",
                      width: Platform.isAndroid
                          ? SizeConfig.safeBlockHorizontal * 4
                          : SizeConfig.safeBlockVertical * 2.2,
                    ),
                  ),
                )),
          ),
          GestureDetector(
            onTap: () {
              print("U JUST CLIKCKED ME, SIR!");
              _showBookmarkDialog(context);
              // setState(() {
              //   String currentLessonId =
              //       ProfileManager.shared().getLessonIds()[selected];

              //   if (ProfileManager.shared().getIsTutorLoggedIn() == true ||
              //       ProfileManager.shared().getIsStudentLoggedIn() == true) {
              //     if (ProfileManager.bookmarkedPrograms
              //         .contains(currentLessonId)) {
              //       _deleteBookmarkedLesson();
              //       ProfileManager.bookmarkedPrograms
              //           .remove(currentLessonId); //manage UI icon change

              //       print(ProfileManager.bookmarkedPrograms);
              //     } else {
              //       _bookmarkLesson();Rograms
              //           .add(currentLessonId); //manage UI icon change
              //       print(ProfileManager.bookmarkedPrograms);
              //     }
              //   }

              //   if (ProfileManager.shared().getIsTutorLoggedIn() == false &&
              //       ProfileManager.shared().getIsStudentLoggedIn() == false) {
              //     showDialog(
              //         context: context,
              //         builder: (BuildContext context) =>
              //             LoginRegisterDialogPopup(
              //                 description:
              //                     "Login or Register to bookmark Lessons"));
              //   }
              // });
            },
            child: Container(
              width: SizeConfig.blockSizeHorizontal * 100 / 6,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  child: Icon(Icons.file_download,color: Colors.blueGrey,),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_isQualityButtonClicked == false) {
                setState(() {
                  _isQualityButtonClicked = true;
                });
              } else {
                setState(() {
                  _isQualityButtonClicked = false;
                });
              }
            },
            child: Container(
              width: SizeConfig.blockSizeHorizontal * 100 / 6,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  child: _isQualityButtonClicked
                      ? Image.asset(
                    ProfileManager.shared().getPreselectVideoQuality() ==
                        null
                        ? "assets/icons/HD_blue.png"
                        : _icons.values.elementAt(ProfileManager.shared()
                        .getPreselectVideoQuality()),
                    width: Platform.isAndroid
                        ? SizeConfig.safeBlockHorizontal * 7
                        : SizeConfig.safeBlockVertical * 3.6,
                  )
                      : Image.asset(
                    ProfileManager.shared().getChosenVideoQualityIcon() ==
                        null
                        ? "assets/icons/HD_icon.png"
                        : ProfileManager.shared()
                        .getChosenVideoQualityIcon(),
                    width: Platform.isAndroid
                        ? SizeConfig.safeBlockHorizontal * 7
                        : SizeConfig.safeBlockVertical * 3.6,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              /* if (Platform.isIOS) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeRight,
                  DeviceOrientation.landscapeLeft,
                ]);
              } */
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeRight,
                DeviceOrientation.landscapeLeft,
              ]);
            },
            child: Container(
                width: SizeConfig.blockSizeHorizontal * 100 / 6,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    child: Image.asset(
                      "assets/icons/fullscreen_icon.png",
                      width: Platform.isAndroid
                          ? SizeConfig.safeBlockHorizontal * 7
                          : SizeConfig.safeBlockVertical * 3.4,
                    ),
                  ),
                )),
          )
        ],
      ),
    );
  }

/*  _buildPortraitBambuserPlayerController() {
    var _height = MediaQuery.of(context).size.height;
    return Material(
      shadowColor: Colors.grey,
      elevation: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        height: (_height / 10) * 0.6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () {
                playOrPauseVideo();
              },
              child: Container(
                  color: Colors.transparent,
                  width: SizeConfig.blockSizeHorizontal * 100 / 6,
                  child: Container(
                    child: Center(
                      child: _isBambuserPlaying
                          ? Image.asset(
                        "assets/icons/pause_icon.png",
                        width: Platform.isAndroid
                            ? SizeConfig.safeBlockHorizontal * 3
                            : SizeConfig.safeBlockVertical * 1.7,
                      )
                          : Image.asset(
                        "assets/icons/play_icon.png",
                        width: Platform.isAndroid
                            ? SizeConfig.safeBlockHorizontal * 3
                            : SizeConfig.safeBlockVertical * 1.7,
                      ),
                    ),
                  )),
            ),
            Padding(
              padding:
              EdgeInsets.only(top: SizeConfig.safeBlockHorizontal * 4.26),
              child: Container(
                width: SizeConfig.blockSizeHorizontal * 100 / 4,
                color: Colors.transparent,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        child: Image.asset(
                          "assets/icons/Buffer.png",
                          width: SizeConfig.safeBlockVertical * 20,
                        ),
                      ),
                      Container(
                        child: Text("Buffer",
                            style: TextStyle(
                                fontFamily: "Roboto",
                                color: Color.fromRGBO(119, 119, 119, 0.8),
                                fontSize:
                                SizeConfig.safeBlockHorizontal * 3.5)),
                      )
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: SizeConfig.blockSizeHorizontal * 100 / 6,
              color: Colors.transparent,
            ),
            Container(
              width: SizeConfig.blockSizeHorizontal * 100 / 6,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  child: Image.asset(
                    "assets/icons/HD_icon.png",
                    width: Platform.isAndroid
                        ? SizeConfig.safeBlockHorizontal * 7
                        : SizeConfig.safeBlockVertical * 3.6,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  resetBambuserPlayer();
                  isToggleButtonSelected[0] =
                  true; //to return it's original state where the first tab is visible
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight
                  ]);
                  SystemChrome.setEnabledSystemUIOverlays(
                      [SystemUiOverlay.bottom]);
                  SystemChrome.setEnabledSystemUIOverlays(
                      [SystemUiOverlay.top]);
                });
              },
              child: Container(
                  width: SizeConfig.blockSizeHorizontal * 100 / 6,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      child: Image.asset(
                        "assets/icons/fullscreen_icon.png",
                        width: Platform.isAndroid
                            ? SizeConfig.safeBlockHorizontal * 7
                            : SizeConfig.safeBlockVertical * 3.4,
                      ),
                    ),
                  )),
            )
          ],
        ),
      ),
    );
  }*/

  Map<String, String> _icons = {
    "AUTO": "assets/icons/AU.png",
    "720p": "assets/icons/hD.png",
    "1080p": "assets/icons/hD.png",
    "360p": "assets/icons/SD.png",
    "540p": "assets/icons/SD.png",
    "240p": "assets/icons/LD.png"
  };
  _buildQualityDropdown() {

    String selectedV = ProfileManager.shared().getSelectedVideoQuality();

    // List<String> _names = ["AUTO", "720p", "360p", "240p"];
    var _width = MediaQuery.of(context).size.width;
    var _height = MediaQuery.of(context).size.height;
    return Positioned(
        bottom: SizeConfig.safeBlockVertical * 28,
        right: _isLandscapeActive == true
            ? MediaQuery.of(context).viewPadding.right + 130
            : MediaQuery.of(context).viewPadding.right + 40,
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), color: Colors.white),
            height: _isLandscapeActive == true ? _height / 2 : _height / 3,
            width: _isLandscapeActive == true ? _width / 5 : _width / 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_videoList.length, (index) {
                return GestureDetector(
                  onTap: () {
                    selectedVideo = _videoList[index];
                    PlayerManager.shared().savePosition();
                    PlayerManager.shared().changeVideoUrl(selectedVideo.url);
                    setState(() {
                      _isVimeoPlaying = true;
                      _isQualityButtonClicked = false;
                      ProfileManager.shared().setChosenVideoQualityIcon(
                          _icons[_videoList[index].quality]);

                      ProfileManager.shared().setSelectedVideoQuality(_videoList[index].quality);

                      print('SELECTED QUALITY SELECTED IS ${_videoList[index].quality}');
                    });
                  },
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Row(
                        children: [
                          Container(
                            child: _icons[_videoList[index].quality] != null
                                ?(_videoList[index].quality == selectedV ?
                            Image.asset(_icons[_videoList[index].quality], color: Colors.blue,):
                            Image.asset(_icons[_videoList[index].quality])
                            )
                                : Image.asset("assets/icons/LD.png", color: Colors.blue,),
                            width: 22,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              _videoList[index].quality,
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ));
  }

  _toggleSelected(int index) {
    setState(() {
      for (int i = 0; i < isToggleButtonSelected.length; i++) {
        isToggleButtonSelected[i] = false;
      }
      isToggleButtonSelected[index] == true;
    });
  }

  _buildToggleButtons() {
    return Material(
      shadowColor: Colors.grey,
      elevation: 5,
      child: GestureDetector(
        onTap: () {
          SystemChannels.textInput.invokeMethod('TextInput.hide');
          setState(() {
            _isGetNotesButtonClicked = false;
          });
        },
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 30,
                        ),
                        ProfileManager.shared().getIsTutorLoggedIn() == true ||
                            ProfileManager.shared()
                                .getIsStudentLoggedIn() ==
                                true
                            ? SizedBox(
                          width: SizeConfig.safeBlockHorizontal * 80,
                          height: SizeConfig.safeBlockHorizontal * 12,
                          child: Toggle(
                            isToggleButtonSelected:
                            isToggleButtonSelected,
                            width: SizeConfig.safeBlockHorizontal * 80,
                            selectedCallback: _toggleSelected,
                            thirdButtonText: "Library",

                          ),
                        )
                            : GestureDetector(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (BuildContext context) =>
                                    LoginRegisterDialogPopup(
                                        description:
                                        "Login or register to enable you access previous Lessons and ask questions"));
                          },
                          child: Stack(
                            children: [
                              SizedBox(
                                width:
                                SizeConfig.safeBlockHorizontal * 80,
                                height:
                                SizeConfig.safeBlockHorizontal * 12,
                                child: IgnorePointer(
                                  child: Toggle(
                                    isToggleButtonSelected:
                                    isToggleButtonSelected,
                                    width:
                                    SizeConfig.safeBlockHorizontal *
                                        80,
                                    selectedCallback: _toggleSelected,
                                  ),
                                ),
                              ),
                              Container(
                                color: Colors.transparent,
                                width:
                                SizeConfig.safeBlockHorizontal * 80,
                                height:
                                SizeConfig.safeBlockHorizontal * 12,
                              )
                            ],
                          ),
                        ),
                        ProfileManager.shared().getIsStudentLoggedIn() == true ||
                            ProfileManager.shared()
                                .getPlayHistoryOrFavourite() ==
                                true
                            ? Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                              onTap: () {
                                _isGetNotesButtonClicked = false;
                                setState(() {
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                });

                                scaffoldKey.currentState.openDrawer();
                                PlayerManager.shared().pause();
                                setState(() {
                                  _isVimeoPlaying = false;
                                });
                              },
                              child: Container(
                                height:
                                SizeConfig.safeBlockHorizontal * 12,
                                width: SizeConfig.safeBlockHorizontal * 8,
                                color: Colors.transparent,
                                child: Center(
                                  child: Image.asset(
                                      "assets/icons/menu.png",
                                      width:
                                      SizeConfig.safeBlockHorizontal *
                                          5.3),
                                ),
                              )),
                        )
                            : SizedBox(
                          width: 30,
                        )
                      ],
                    ),
                    isToggleButtonSelected[1] == true ||
                        isToggleButtonSelected[2] == true
                        ? SizedBox(
                      width: double.infinity,
                    )
                        : _buildTabBottomSection()
                  ],
                ),
              ),
            ),
            SizedBox(
              height: isToggleButtonSelected[0] == true
                  ? SizeConfig.safeBlockVertical * 2
                  : SizeConfig.safeBlockVertical * 2,
              child: Container(color: textColorWhiteWithoutOpacity),
            )
          ],
        ),
      ),
    );
  }

  _buildTabBottomSection() {
    return Column(
      children: [
        Padding(
          padding:
          EdgeInsets.fromLTRB(15, SizeConfig.safeBlockVertical * 3, 0, 0),
          child: Container(
            alignment: Alignment.centerLeft,
            width: SizeConfig.safeBlockHorizontal * 100,
            child: Text(
                ProfileManager.shared().getClassFullName() == null
                    ? ""
                    : ProfileManager.shared().getClassFullName(),
                style: TextStyle(
                    fontSize: SizeConfig.safeBlockHorizontal * 5.3,
                    fontFamily: "Roboto"),
                overflow: TextOverflow.ellipsis),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
          child: _buildTabBottom(),
        )
      ],
    );
  }

  _buildTabBottom() {
    return Padding(
      padding: EdgeInsets.only(top: SizeConfig.safeBlockVertical * 0.74),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildSchoolLocation(), _buildViewNumber()],
          ),
          /* Column(
            children: [_buildLiveButton()],
          ), */
          Column(
            children: [_buildMaterialsButton()],
          )
        ],
      ),
    );
  }

  _buildSchoolLocation() {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: SizeConfig.safeBlockHorizontal * 4,
          color: buttonColorBlue,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: Container(
            width: SizeConfig.safeBlockHorizontal * 30,
            child: Text(
              ProfileManager.shared().getSchoolName() == null
                  ? ""
                  : ProfileManager.shared().getSchoolName(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: "Roboto",
                  color: Color.fromRGBO(119, 119, 119, 1),
                  fontSize: SizeConfig.safeBlockHorizontal * 3.5),
            ),
          ),
        )
      ],
    );
  }

  _buildViewNumber() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child:
      (ProfileManager.shared().getClassViewCount()  == null ? 0: ProfileManager.shared().getClassViewCount() ) < 100 ? Container()
          : Row(
        children: [
          Icon(
            Icons.person,
            size: 15,
            color: buttonColorBlue,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
            child: Text(
                ProfileManager.shared().getClassViewCount() == null
                    ? ""
                    : "Views " +
                    "${ProfileManager.shared().getClassViewCount().toString()}",
                style: TextStyle(
                    fontFamily: "Roboto",
                    color: Color.fromRGBO(119, 119, 119, 1),
                    fontSize: SizeConfig.safeBlockHorizontal * 3.5)),
          )
        ],
      ),
    );
  }

/*
  _buildLiveButton() {
    return GestureDetector(
      onTap: () {
        if (Platform.isIOS) {
          PlayerManager.shared().disposeControllers();
          setState(() {
            if (_isBambuserVisible == true) {
              _isBambuserVisible = false;
              _isVimeoPlaying = true;
              _bambuseriOSPlayerController = null;
              bambuseriOSPlayer = null;
            } else {
              _isBambuserVisible = true;
              if (_bambuseriOSPlayerController == null) {
                initBambuserPlayer();
              }
            }
          });
        }

        if (Platform.isAndroid) {
          PlayerManager.shared().disposeControllers();
          setState(() {
            if (_isBambuserVisible == true) {
              _isBambuserVisible = false;
              _isVimeoPlaying = true;
              _bambuserAndroidPlayerController.stop();
              _bambuserAndroidPlayerController = null;
              bambuserAndroidPlayer = null;
            } else {
              _isBambuserVisible = true;
              if (_bambuserAndroidPlayerController == null) {
                initBambuserPlayer();
              }
            }
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
        child: Container(
          height: SizeConfig.safeBlockVertical * 5.4,
          width: SizeConfig.safeBlockHorizontal * 26.67,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: _isBambuserVisible == false ? Colors.white : generalGreen,
              border: Border.all(
                  color: _isBambuserVisible == false
                      ? generalGreen
                      : Colors.white)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isBambuserVisible == false
                  ? Container(
                  height: SizeConfig.safeBlockHorizontal * 2.6,
                  width: SizeConfig.safeBlockHorizontal * 2.6,
                  decoration: BoxDecoration(
                      color: textColorWhiteWithoutOpacity,
                      border: Border.all(
                        color: generalGreen,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(50))))
                  : SpinKitDoubleBounce(
                color: Colors.white.withOpacity(0.6),
                size: 12,
                duration: Duration(seconds: 4),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: _isBambuserVisible == false ? 5 : 1),
                  child: Text(
                    _isBambuserVisible == false ? "Join Live" : "Streaming",
                    style: TextStyle(
                        color: _isBambuserVisible == false
                            ? generalGreen
                            : textColorWhiteWithoutOpacity,
                        fontFamily: "Roboto"),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
*/
  _buildMaterialsButton() {

    bool isSubscribed = ProfileManager.shared().getSubscription();

    print(' material button clicked for $isSubscribed');
    _showMaterialsScreen() {
      /*  if (_materialsButtonClicked == false) {
        if(_materialsButtonSummaryClicked) {
          setState(() {
            _materialsButtonCalendarClicked = false;
            _materialsButtonClicked = true;
          });
        }
        else if(_materialsButtonCalendarClicked){
          setState(() {
            _materialsButtonSummaryClicked = false;
            _materialsButtonClicked = true;
          });
        }
      }

      else {
        setState(() {
          _materialsButtonClicked = false;
          _isGetNotesButtonClicked = false;
        });
      }*/
    }

    if(isSubscribed)
      return Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
            child: GestureDetector(
              onTap: () {


                setState(() {


                  if(_materialsButtonCalendarClicked){
                    _materialsButtonClicked = false;
                    _materialsButtonCalendarClicked = false;
                  }
                  else {
                    _materialsButtonClicked = true;
                    _materialsButtonCalendarClicked = true;
                  }

                  _materialsButtonSummaryClicked = false;
                });


                // Navigator.pushNamed(context, '/offline_player');
                ProfileManager.shared().getIsStudentLoggedIn() == false &&
                    ProfileManager.shared().getIsTutorLoggedIn() == false &&
                    ProfileManager.shared().getIsRegistered() == false
                    ? showDialog(
                    context: context,
                    builder: (BuildContext context) => LoginRegisterDialogPopup(
                        description: "Login or Register to download notes"))
                    : _showMaterialsScreen();
              },
              child:
              _materialsButtonCalendarClicked == false ?
              Card(
                elevation: 5,
                shape: CircleBorder(),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    border:
                    Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Container(
                      width: SizeConfig.safeBlockHorizontal * 4,
                      child: Image.asset(
                        "assets/icons/calendar.png",
                      ),
                    ),
                  ),
                ),
              ) :  Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  border:
                  Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
                  borderRadius: BorderRadius.all(Radius.circular(50)),
                  color: Colors.white,
                ),
                child: Center(
                  child: Container(
                    width: SizeConfig.safeBlockHorizontal * 4,
                    child: Image.asset(
                      "assets/icons/calendar.png",
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
            child: GestureDetector(
              onTap: () {



                setState(() {


                  if(_materialsButtonSummaryClicked){
                    _materialsButtonClicked = false;
                    _materialsButtonSummaryClicked = false;
                  }
                  else {
                    _materialsButtonClicked = true;
                    _materialsButtonSummaryClicked = true;
                  }

                  _materialsButtonCalendarClicked = false;
                });


                // Navigator.pushNamed(context, '/offline_player');
                ProfileManager.shared().getIsStudentLoggedIn() == false &&
                    ProfileManager.shared().getIsTutorLoggedIn() == false &&
                    ProfileManager.shared().getIsRegistered() == false
                    ? showDialog(
                    context: context,
                    builder: (BuildContext context) => LoginRegisterDialogPopup(
                        description: "Login or Register to download notes"))
                    : _showMaterialsScreen();
              },
              child:
              _materialsButtonSummaryClicked == false ?
              Card(
                elevation: 5,
                shape: CircleBorder(),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    border:
                    Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Container(
                      width: SizeConfig.safeBlockHorizontal * 4,
                      child: Image.asset(
                        "assets/icons/book_icon.png",
                      ),
                    ),
                  ),
                ),
              ) :  Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  border:
                  Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
                  borderRadius: BorderRadius.all(Radius.circular(50)),
                  color: Colors.white,
                ),
                child: Center(
                  child: Container(
                    width: SizeConfig.safeBlockHorizontal * 4,
                    child: Image.asset(
                      "assets/icons/book_icon.png",
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

    else
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 25, 0),
        child: GestureDetector(
          onTap: () {
            // Navigator.pushNamed(context, '/offline_player');
            ProfileManager.shared().getIsStudentLoggedIn() == false &&
                ProfileManager.shared().getIsTutorLoggedIn() == false &&
                ProfileManager.shared().getIsRegistered() == false
                ? showDialog(
                context: context,
                builder: (BuildContext context) => LoginRegisterDialogPopup(
                    description: "Login or Register to download notes"))
                : _showMaterialsScreen();
          },
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              border:
              Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
              borderRadius: BorderRadius.all(Radius.circular(50)),
              color: _materialsButtonClicked == true
                  ? Color.fromRGBO(77, 194, 255, 0.2)
                  : Colors.white,
            ),
            child: Center(
              child: Container(
                width: SizeConfig.safeBlockHorizontal * 4,
                child: Image.asset(
                  "assets/icons/book_icon.png",
                ),
              ),
            ),
          ),
        ),
      );



    /*
        return Row(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
          child: GestureDetector(
            onTap: () {
              // Navigator.pushNamed(context, '/offline_player');
              ProfileManager.shared().getIsStudentLoggedIn() == false &&
                  ProfileManager.shared().getIsTutorLoggedIn() == false &&
                  ProfileManager.shared().getIsRegistered() == false
                  ? showDialog(
                  context: context,
                  builder: (BuildContext context) => LoginRegisterDialogPopup(
                      description: "Login or Register to download notes"))
                  : _showMaterialsScreen();
            },
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                border:
                Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
                borderRadius: BorderRadius.all(Radius.circular(50)),
                color: _materialsButtonClicked == true
                    ? Color.fromRGBO(77, 194, 255, 0.2)
                    : Colors.white,
              ),
              child: Center(
                child: Container(
                  width: SizeConfig.safeBlockHorizontal * 4,
                  child: Image.asset(
                    "assets/icons/calendar.png",
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 25, 0),
          child: GestureDetector(
            onTap: () {
              // Navigator.pushNamed(context, '/offline_player');
              ProfileManager.shared().getIsStudentLoggedIn() == false &&
                  ProfileManager.shared().getIsTutorLoggedIn() == false &&
                  ProfileManager.shared().getIsRegistered() == false
                  ? showDialog(
                  context: context,
                  builder: (BuildContext context) => LoginRegisterDialogPopup(
                      description: "Login or Register to download notes"))
                  : _showMaterialsScreen();
            },
            child: Card(
              elevation: 5,
              shape: CircleBorder(),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  border:
                  Border.all(color: Color.fromRGBO(77, 194, 255, 1), width: 0.5),
                  borderRadius: BorderRadius.all(Radius.circular(50)),
                  color: _materialsButtonClicked == true
                      ? Color.fromRGBO(77, 194, 255, 0.2)
                      : Colors.white,
                ),
                child: Center(
                  child: Container(
                    width: SizeConfig.safeBlockHorizontal * 4,
                    child: Image.asset(
                      "assets/icons/book_icon.png",
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      ],
    );
    */
  }

  //----------> CustomBookmark -----\\

  _showBookmarkDialog(BuildContext context) async{
    String userSelection =  await showMenu<String>(
      shape: RoundedRectangleBorder(
        side: BorderSide(width: 1.0, style: BorderStyle.none),
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
      ),
      context: context,
      position: RelativeRect.fromLTRB(220, 300, 100, 100),
      items: popupRoutes.map((String popupRoute) {
        return new PopupMenuItem<String>(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              popupRoute == "Bookmark" ? SizedBox(height: 10) : Container(),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //Icon(popupRoute == "Bookmark" ? Icons.star : Icons.phone_android,size: 22, color: Colors.grey[300],),
                  popupRoute == "Bookmark" ? ProfileManager.shared().getLessonIds().isEmpty ?
                  Image.asset("assets/icons/bookmark_icon.png",width: 15,) : ProfileManager.bookmarkedPrograms.contains(
                      ProfileManager.shared()
                          .getLessonIds()[selected]) ==
                      true
                      ? Image.asset(
                    "assets/icons/bookmark_red.png",
                    width: 15,
                  )
                      : Image.asset(
                    "assets/icons/bookmark_icon.png",
                    width: 15,
                  )
                      : Icon(Icons.phone_android,
                    size: 23, color: Colors.grey[500],),
                  popupRoute == "Bookmark" ? SizedBox(width:5) : SizedBox(width:3),
                  Text(popupRoute)
                ],),
              popupRoute == "Bookmark" ? SizedBox(height: 10) : SizedBox(height: 5),
              popupRoute == "Bookmark" ? Divider(color:Colors.grey) : Container(),
              // popupRoute == "Bookmark" ? SizedBox(height: 5) : Container(),
            ],
          ),
          value: popupRoute,
        );
      }).toList(),

      elevation: 8.0,
    );

    if (userSelection == "Bookmark") {
      print("BOOKMARKED!");
      // print("VIDEO TOTAL: ${ProfileManager.shared().getLessonIds().length}\nSELECTED:");
      print("VIDEO TOTAL: ${ProfileManager.shared().getLessonIds().length} \nSELECTED: $selected");
      setState(() {
        String currentLessonId =
        ProfileManager.shared().getLessonIds()[selected];

        if (ProfileManager.shared().getIsTutorLoggedIn() == true ||
            ProfileManager.shared().getIsStudentLoggedIn() == true) {
          if (ProfileManager.bookmarkedPrograms
              .contains(currentLessonId)) {
            _deleteBookmarkedLesson();
            ProfileManager.bookmarkedPrograms
                .remove(currentLessonId); //manage UI icon change

            print(ProfileManager.bookmarkedPrograms);
          } else {
            _bookmarkLesson();
            ProfileManager.bookmarkedPrograms
                .add(currentLessonId); //manage UI icon change
            print(ProfileManager.bookmarkedPrograms);
          }
        }

        if (ProfileManager.shared().getIsTutorLoggedIn() == false &&
            ProfileManager.shared().getIsStudentLoggedIn() == false) {
          showDialog(
              context: context,
              builder: (BuildContext context) =>
                  LoginRegisterDialogPopup(
                      description:
                      "Login or Register to bookmark Lessons"));
        }
      });
    }
    if (userSelection == "Download"){
      if(Platform.isAndroid){
        if(isDowloadable){
          print("DOWNLOAD CLICKED!");
          print("************** BEFORE DOWNLOAD ************* ");
          print("////// ${ProfileManager.shared().getLessonIds()}   /////////");

          setState(() {
            downloadingList.add(ProfileManager.shared().getLessonIds()[selected]);
          });
        }else {
          await _permissionHandler.requestPermissions([PermissionGroup.storage]).then((value){
            if (value[PermissionGroup.storage] == PermissionStatus.granted) {
              // permission was granted
              setState(() { isDowloadable = true; });
              print("DOWNLOAD CLICKED!");
              print("************** BEFORE DOWNLOAD ************* ");
              print("////// ${ProfileManager.shared().getLessonIds()}   /////////");

              setState(() {
                downloadingList.add(ProfileManager.shared().getLessonIds()[selected]);
              });

            }
          });
        }
      }



      //_downloadVideo();
      /*myDownloader.downloadFile("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
          filename:"videodownloaded.mp4");*/

      /*showDialog(
        context: context,
        builder: (BuildContext context) => Center(
          child: CustomDialogPopup(
            description:
            "Download and access this video offline ?",
            buttonText: "NO",
            secondaryButtonText: "YES",
            disableButton: false,
            enableSecondaryButton: true,
            onTap: (){
              Navigator.pop(context);
            },
            secondaryButtonCallback: ()async{
              _downloadVideo();
            },
          ),
        ),
      );*/
      /*  AwesomeDialog(
        context: context,
        keyboardAware: true,
        dismissOnBackKeyPress: false,
        dialogType: DialogType.WARNING,
        animType: AnimType.BOTTOMSLIDE,
        btnCancelText: "Cancel",
        btnOkText: "Download",
        title: 'Download Video?',
        padding: const EdgeInsets.all(16.0),
        desc:
        'Download and access this video offline',
        btnCancelOnPress: () {},
        btnOkOnPress: () { _downloadVideo(); print("DONEEEEEEEEEEEE");},
      ).show();*/

    }

  }





  //---------<END of Customk Bookmark>-------\\

  _buildVideoProgram() {
    // downloadingList.remove(value)


    bool isSubscribed = ProfileManager.shared().getSubscription();
    //isSubscribed = true;
    bool isHistory = false;

    List<String> locallyvid =[];
    locallyvid =  ProfileManager.shared().getLocalVideoList();
    var _width = MediaQuery.of(context).size.width;
    return isConnected ? IgnorePointer(
      ignoring: _isProgramItemCLickable,
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Container(
                child: Column(
                  children: List.generate(
                      ProfileManager.shared().getLessonSubjects().length,
                          (index) {
                        return GestureDetector(
                          onTap: () {

                            checkInternet().then((value){
                              if(value){

                                getLocalVidUri(ProfileManager.shared().getLessonIds()[index]).then((uri){
                                  if(uri.isNotEmpty){

                                    setState(() {
                                      _isProgramItemCLickable = true;
                                      selected = index;

                                      /////////////////////////////
                                      initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[selected])
                                          .then((videoList) {
                                        //   PlayerManager.shared().changeActiveUrl(uri,isLocal: true);
                                        PlayerManager.shared().changeActiveUrl('file://$filepath/${ProfileManager.shared().getLessonIds()[selected]+'.mp4'}',isLocal: true);
                                      });
                                      ////////////////////////////

                                      /*initVimeoPlayer(ProfileManager.shared()
                                      .getLessonVimeoIds()[index])
                                      .then((videoList) {
                                    if (Platform.isAndroid) {
                                      PlayerManager.shared().disposeControllers();
                                    }

                                    PlayerManager.shared()
                                        .changeActiveUrl(selectedVideo.url);
                                  });*/

                                      _isVimeoPlaying = true;


                                      print("#### LESSON_ID: ${ProfileManager.shared().getLessonIds()[selected]}");

                                      _addLessonToHistory(
                                          ProfileManager.shared().getLessonIds()[selected]);
                                    });


                                  }else {
                                    setState(() {
                                      _isProgramItemCLickable = true;
                                      selected = index;

                                      /////////////////////////////
                                      initVimeoPlayer(ProfileManager.shared().getLessonVimeoIds()[selected])
                                          .then((videoList) {
                                        PlayerManager.shared().changeActiveUrl(selectedVideo.url);
                                      });
                                      ////////////////////////////

                                      /*initVimeoPlayer(ProfileManager.shared()
                                      .getLessonVimeoIds()[index])
                                      .then((videoList) {
                                    if (Platform.isAndroid) {
                                      PlayerManager.shared().disposeControllers();
                                    }

                                    PlayerManager.shared()
                                        .changeActiveUrl(selectedVideo.url);
                                  });*/

                                      _isVimeoPlaying = true;


                                      print(
                                          ProfileManager.shared().getLessonIds()[selected]);

                                      _addLessonToHistory(
                                          ProfileManager.shared().getLessonIds()[selected]);
                                    });

                                  }


                                });


                              } else {

                                setState((){
                                  _isProgramItemCLickable = true;
                                });

                                getLocalVidUri(ProfileManager.shared().getLessonIds()[index]).then((link){
                                  if(link.isNotEmpty){
                                    showToast("URL NOT EMPTY", Colors.black);
                                    setState((){
                                      selected = index;
                                      _isProgramItemCLickable = true;
                                      _isVimeoPlaying = false;
                                      selectedVideo.url = 'file://$filepath/${ProfileManager.shared().getLessonIds()[index]+'.mp4'}';

                                    });

                                    PlayerManager.shared()
                                        .changeActiveUrl(selectedVideo.url,isLocal: true);
                                    PlayerManager.shared().play();

                                    showToast("Playing saved video", Colors.blue);

                                  }
                                });


                                //=========================================


                                if(locallyvid.contains(ProfileManager.shared().getLessonIds()[index])){

                                  /*setState((){
                                    selected = index;
                                    _isProgramItemCLickable = true;
                                    _isVimeoPlaying = false;
                                    PlayerManager.shared()
                                        .changeActiveUrl('file://$filepath/${ProfileManager.shared().getLessonIds()[index]+'.mp4'}',isLocal: true);
                                    PlayerManager.shared().play();
                                  });

                                  showToast("Playing saved video", Colors.blue);*/


                                }else {
                                  showToast("No internet available!", Colors.red);
                                  selected = index;

                                  PlayerManager.shared()
                                      .changeActiveUrl(selectedVideo.url);
                                }


                              }
                            });
                          },
                          child: Container(
                            decoration: selected == index
                                ? BoxDecoration(
                              color: programBackgroundColorActive,
                            )
                                : BoxDecoration(
                              color: programBackgroundColorInactive,
                            ),
                            padding: EdgeInsets.symmetric(vertical: 5),
                            width: double.infinity,
                            //############# Column added for downlaod progress
                            child: Column(
                              children: [
                                SizedBox(height: Device.get().isTablet ? 5 : 3,),
                                // Divider(color: Colors.blue,thickness: Device.get().isTablet ? 2 : 1,),
                                SizedBox(height: Device.get().isTablet ? 5 : 3,),
                                downloadingList.contains(ProfileManager.shared().getLessonIds()[index]) ?
                                DownloadTube(filename: "${ProfileManager.shared().getLessonIds()[index]}.mp4",
                                url: "https://xtraclassnotes.s3-us-west-2.amazonaws.com/videos/Academic_TV_logo-reveal.mp4",
                                //  url: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                                  // url: "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
                                  listToDownload: downloadingList,
                                  listDownloaded: localVideos,
                                  index: ProfileManager.shared().getLessonIds()[index],
                                )
                                //  Text("$incrementer",style:TextStyle(color: Colors.green[700], fontSize: 13,))
                                    :
                                SizedBox(),
                                SizedBox(height: 3,),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Container(
                                      width: selected != index
                                          ? (_width / 10) * 0.7
                                          : (_width / 10) * 0.5,
                                      child: Padding(
                                          padding: const EdgeInsets.only(left: 10),
                                          child:
                                          selected == index ? Image.asset( "assets/icons/play_icon_blue.png") : classIdsHistory.contains(ProfileManager.shared().getLessonVimeoIds()[selected]) ?
                                          selected == index ?
                                          Image.asset( "assets/icons/play_icon_blue.png") : Image.asset(selected != index
                                              ? (isSubscribed? (isHistory ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"): (index == 0 ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"))
                                              : "assets/icons/play_icon_blue.png") :  Image.asset(selected != index
                                              ? (isSubscribed? (isHistory ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"): (index == 0 ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"))
                                              : "assets/icons/play_icon_blue.png")
                                        //"assets/icons/play_icon_blue.png"
                                      ),
                                    ),
                                    Expanded(
                                      flex:1,
                                      child: Container(
                                          width: (_width / 10) * 2,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 10),
                                            child: Text(
                                                ProfileManager.shared()
                                                    .getLessonPeriodTitles()[index]
                                                    .toString(),
                                                maxLines:1,
                                                style: TextStyle(
                                                  color:
                                                  Color.fromRGBO(23, 147, 205, 1),
                                                  fontFamily: "Roboto",
                                                  fontSize:
                                                  SizeConfig.safeBlockHorizontal * 4,),
                                                overflow: TextOverflow.ellipsis
                                            ),
                                          )),
                                    ),
                                    Container(
                                        padding: EdgeInsets.only(
                                            left: SizeConfig.safeBlockHorizontal * 1),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: (_width / 10) * 7,
                                              child: Text(
                                                  ProfileManager.shared()
                                                      .getLessonSubjects()[index]
                                                      .toString() +
                                                      " - " +
                                                      ProfileManager.shared()
                                                          .getLessonTopicNames()[
                                                      index]
                                                          .toString(),
                                                  maxLines: 3,
                                                  style: TextStyle(
                                                      color: programInactiveTextColor,
                                                      fontFamily: "Roboto",
                                                      fontSize: SizeConfig
                                                          .safeBlockHorizontal *
                                                          4.1,
                                                      fontWeight: FontWeight.w400),
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        )),

                                  ],
                                ),
                                localVideos.contains(ProfileManager.shared().getLessonIds()[index]) ?
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right:8.0),
                                    child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(13),
                                          color: Colors.blue[800],
                                        ),

                                        padding: EdgeInsets.all(3),
                                        child: Text("Saved",style:TextStyle(color: Colors.white,fontSize: 10))),
                                  ),
                                ) : Container(),
                                SizedBox(height: Device.get().isTablet ? 5 : 3,),
                                //  Divider(color: Colors.blue,thickness: Device.get().isTablet ? 2 : 1,),

                              ],
                            ),
                          ),
                        );
                      }),
                ),
              ),
              _isLoading == true
                  ? Container(
                  child: PlaceHolderLines(disableDefaultPadding: true))
                  : Offstage()
            ],
          ),
        ),
      ),
    )   :
    IgnorePointer(
      ignoring: false,
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Container(
                child: Column(
                  children: List.generate(
                      ProfileManager.shared().getLessonSubjects().length,
                          (index) {
                        return GestureDetector(
                          onTap: () {

                            checkInternet().then((value){
                              if(value){
                                setState(() {
                                  _isProgramItemCLickable = true;
                                  selected = index;
                                  initVimeoPlayer(ProfileManager.shared()
                                      .getLessonVimeoIds()[index])
                                      .then((videoList) {
                                    /*if (Platform.isAndroid) {
                                      PlayerManager.shared().disposeControllers();
                                    }*/
                                    PlayerManager.shared()
                                        .changeActiveUrl(selectedVideo.url);
                                  });
                                  _isVimeoPlaying = true;

                                  print(
                                      ProfileManager.shared().getLessonIds()[selected]);

                                  _addLessonToHistory(
                                      ProfileManager.shared().getLessonIds()[selected]);
                                });
                              } else {

                                setState((){
                                  _isProgramItemCLickable = true;
                                });

                                getLocalVidUri(ProfileManager.shared().getLessonIds()[index]).then((link){
                                  if(link.isNotEmpty){
                                    showToast("URL NOT EMPTY", Colors.black);
                                    setState((){
                                      selected = index;
                                      _isProgramItemCLickable = true;
                                      _isVimeoPlaying = true;
                                    //  selectedVideo.url = 'file://$filepath/${ProfileManager.shared().getLessonIds()[index]+'.mp4'}';
                                      PlayerManager.shared().changeActiveUrl('file://$filepath/${ProfileManager.shared().getLessonIds()[index]+'.mp4'}',
                                          isLocal: true);

                                    });

                                    PlayerManager.shared()
                                        .changeActiveUrl(selectedVideo.url,isLocal: true);
                                    PlayerManager.shared().play();

                                    showToast("Playing saved video", Colors.blue);

                                  }else {
                                    //put here
                                    showToast("No internet available!", Colors.red);
                                    selected = index;

                                    PlayerManager.shared()
                                        .changeActiveUrl(selectedVideo.url);
                                  }
                                });


                                //=========================================


                               /* if(locallyvid.contains(ProfileManager.shared().getLessonIds()[index])){

                                  *//*setState((){
                                    selected = index;
                                    _isProgramItemCLickable = true;
                                    _isVimeoPlaying = false;
                                    PlayerManager.shared()
                                        .changeActiveUrl('file://$filepath/${ProfileManager.shared().getLessonIds()[index]+'.mp4'}',isLocal: true);
                                    PlayerManager.shared().play();
                                  });

                                  showToast("Playing saved video", Colors.blue);*//*


                                }else {

                                }*/
                              }
                            });


                          },
                          child: Container(
                            decoration: selected == index
                                ? BoxDecoration(
                              color: programBackgroundColorActive,
                            )
                                : BoxDecoration(
                              color: programBackgroundColorInactive,
                            ),
                            padding: EdgeInsets.symmetric(vertical: 5),
                            width: double.infinity,
                            //############# Column added for downlaod progress
                            child: Column(
                              children: [
                                downloadingList.contains(ProfileManager.shared().getLessonIds()[index]) ?
                                DownloadTube(filename: "${ProfileManager.shared().getLessonIds()[index]}.mp4",
                                  url: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                                  listToDownload: downloadingList,
                                  listDownloaded: localVideos,
                                  index: ProfileManager.shared().getLessonIds()[index],
                                )
                                //  Text("$incrementer",style:TextStyle(color: Colors.green[700], fontSize: 13,))
                                    :
                                SizedBox(),
                                SizedBox(height: 3,),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Container(
                                      width: selected != index
                                          ? (_width / 10) * 0.7
                                          : (_width / 10) * 0.5,
                                      child:  Padding(
                                          padding: const EdgeInsets.only(left: 10),
                                          child:
                                          selected == index ? Image.asset( "assets/icons/play_icon_blue.png") : classIdsHistory.contains(ProfileManager.shared().getLessonVimeoIds()[selected]) ?
                                          selected == index ?
                                          Image.asset( "assets/icons/play_icon_blue.png") : Image.asset(selected != index
                                              ? (isSubscribed? (isHistory ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"): (index == 0 ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"))
                                              : "assets/icons/play_icon_blue.png") :  Image.asset(selected != index
                                              ? (isSubscribed? (isHistory ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"): (index == 0 ? "assets/icons/eye_blue.png": "assets/icons/eye_icon.png"))
                                              : "assets/icons/play_icon_blue.png")
                                        //"assets/icons/play_icon_blue.png"
                                      ),
                                    ),
                                    Expanded(
                                      flex:1,
                                      child: Container(
                                          width: (_width / 10) * 2,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 10),
                                            child: Text(
                                                ProfileManager.shared()
                                                    .getLessonPeriodTitles()[index]
                                                    .toString(),
                                                maxLines:1,
                                                style: TextStyle(
                                                  color:
                                                  Color.fromRGBO(23, 147, 205, 1),
                                                  fontFamily: "Roboto",
                                                  fontSize:
                                                  SizeConfig.safeBlockHorizontal * 4,),
                                                overflow: TextOverflow.ellipsis
                                            ),
                                          )),
                                    ),
                                    Container(
                                        padding: EdgeInsets.only(
                                            left: SizeConfig.safeBlockHorizontal * 1),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: (_width / 10) * 7,
                                              child: Text(
                                                  ProfileManager.shared()
                                                      .getLessonSubjects()[index]
                                                      .toString() +
                                                      " - " +
                                                      ProfileManager.shared()
                                                          .getLessonTopicNames()[
                                                      index]
                                                          .toString(),
                                                  maxLines: 3,
                                                  style: TextStyle(
                                                      color: programInactiveTextColor,
                                                      fontFamily: "Roboto",
                                                      fontSize: SizeConfig
                                                          .safeBlockHorizontal *
                                                          4.1,
                                                      fontWeight: FontWeight.w400),
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        )),

                                  ],
                                ),
                                localVideos.contains(ProfileManager.shared().getLessonIds()[index]) ?
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right:8.0),
                                    child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue[800],
                                          borderRadius: BorderRadius.all(Radius.circular(15)),
                                        ),

                                        padding: EdgeInsets.all(3),
                                        child: Text("Saved",style:TextStyle(color: Colors.white,fontSize: 10))),
                                  ),
                                ) : Container(),

                              ],
                            ),
                          ),
                        );
                      }),
                ),
              ),
              _isLoading == true
                  ? Container(
                  child: PlaceHolderLines(disableDefaultPadding: true))
                  : Offstage()
            ],
          ),
        ),
      ),
    )
    ;




    //  print("File Progress - Downloaded: ${myDownloader.percentage}");

  }

  _addLessonToHistory(String lessonID) {
    if (ProfileManager.shared().getLessonIds().isNotEmpty) {
      ProfileManager.shared().setLessonId(lessonID);
      postHistory(ProfileManager.shared().getLessonId()).then((value) {
        print(value.statusCode);
        if(value.statusCode == 200){
          _getStudentHistory();
          setState(() { });
          print("##########---> HISTORY SAVED SUCCESSFULLY!!!  ##########");
        }
      });
    }
  }

  _bookmarkLesson() {
    ProfileManager.shared()
        .setLessonId(ProfileManager.shared().getLessonIds()[selected]);
    putFavorite(ProfileManager.shared().getLessonId()).then((value) {
      if (value.statusCode == 200) {}
    });
  }

  _deleteBookmarkedLesson() {
    ProfileManager.shared()
        .setLessonId(ProfileManager.shared().getLessonIds()[selected]);
    deleteFavorite(ProfileManager.shared().getLessonId()).then((value) {
      if (value.statusCode == 200) {}
    });
  }

  _buildMaterialsDownloadScreen() {
    var _width = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGetNotesButtonClicked = false;
        });
      },
      child: Scrollbar(
        child:  ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15, top: 20),
              child: Flexible (
                fit: FlexFit.tight,
                // width: MediaQuery.of(context).size.width*0.9,
                child: Row(
                  //  direction: Axis.horizontal,
                  children: [
                    Flexible(
                      flex: 1,
                      child: Material(
                        elevation: 2.0,
                        shape: CircleBorder(),
                        clipBehavior: Clip.hardEdge,
                        child: Container(
                            height: SizeConfig.safeBlockHorizontal * 13,
                            width: SizeConfig.safeBlockHorizontal * 13,
                            child: ClipRRect(
                              //#DEBUG ON 27-NOV FOR IMAGE ERROR
                                child: ProfileManager.shared().getSchoolLogo() == null ? FadeInImage.assetNetwork(
                                  fadeInDuration: Duration(
                                      milliseconds:
                                      BUTTON_FADEIN_TRANSITION_DURATION),
                                  //#debug 27-Nov for image error
                                  image:  "assets/icons/school_crest.png",
                                  height: 40,
                                  placeholderCacheHeight: 40,
                                  placeholderCacheWidth: 40,
                                  width: 40, placeholder: "assets/icons/school_crest.png",
                                ) :FadeInImage.memoryNetwork(
                                  fadeInDuration: Duration(
                                      milliseconds:
                                      BUTTON_FADEIN_TRANSITION_DURATION),
                                  placeholder: kTransparentImage,
                                  //#debug 27-Nov for image error
                                  image: ProfileManager.shared().getSchoolLogo(),
                                  width: 40,
                                )
                            ),
                        ),
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.tight,
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Container(
                          //  width: _width,
                          height: 80,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Subject:",
                                    style: TextStyle(
                                        color: inputFieldHintColor,
                                        fontSize: 15),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                          ProfileManager.shared()
                                              .getLessonSubjects()[
                                          selected] ==
                                              null
                                              ? " "
                                              : ProfileManager.shared()
                                              .getLessonSubjects()[selected],
                                          style: TextStyle(
                                              color: inputFieldHintColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                    ),
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  Text("Topic:",
                                      style: TextStyle(
                                          color: inputFieldHintColor,
                                          fontSize: 15)),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child:Text(
                                        ProfileManager.shared()
                                            .getLessonTopicNames()[
                                        selected] ==
                                            null
                                            ? " "
                                            : ProfileManager.shared()
                                            .getLessonTopicNames()[
                                        selected],
                                        style: TextStyle(
                                            color: inputFieldHintColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  Text("Tutor:",
                                      style: TextStyle(
                                          color: inputFieldHintColor,
                                          fontSize: 15)),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                          ProfileManager.shared()
                                              .getLessonTeacherName()[
                                          selected] ==
                                              null
                                              ? " "
                                              : ProfileManager.shared()
                                              .getLessonTeacherName()[
                                          selected],
                                          style: TextStyle(
                                              color: inputFieldHintColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                    ),
                                  )
                                ],
                              ),

                              //get note


                       /* Expanded(
                          child:  Container(
                            decoration: BoxDecoration(
                                gradient: new LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white, Colors.grey[300]],
                                ),
                                *//* color: Colors.white, *//*
                                border: Border.all(color: buttonColorBlue),
                                borderRadius: Device.get().isTablet ? BorderRadius.all(Radius.circular(50)) : BorderRadius.all(Radius.circular(25))
                            ),
                            width: 200,
                            height: 60,
                            child:  Center(
                                child: Text('Get notes',
                                    style: TextStyle(
                                        fontSize:
                                        SizeConfig.safeBlockHorizontal * 4.4,
                                        fontFamily: "Roboto Regular"))),
                          ),
                        ),*/
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  Container(
                      child: Text(" ", //description of lesson would come here
                          style: TextStyle(
                              color: inputFieldHintColor,
                              height: 1.6,
                              fontSize: 15))),
                  SizedBox(height: 10),
                  ProfileManager.shared()
                      .getLessonNotesUrls()[selected]
                      .isEmpty
                      ? Offstage()
                      : BlueOutlineButton(
                    enableIcon: true,
                    icon: "assets/icons/book_icon.png",
                    title: "Get notes",
                    onTap: _getNotesButtonCallback,
                  ),
                    ProfileManager.shared()
                            .getLessonNotesUrls()[selected]
                            .isEmpty
                        ? Offstage()
                        : _buildLearnMoreButton(),
                  SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _buildLearnMoreButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GestureDetector(
        onTap: () {
          _learnMoreButtonCallback();
        },
        child: Container(
          width: SizeConfig.safeBlockHorizontal * 100,
          height: 30,
          color: Colors.transparent,
          child: ClickableText(
            text: "Learn more",
            setColorBlue: true,
            onTap: _learnMoreButtonCallback,
          ),
        ),
      ),
    );
  }

  _buildGetNotesDialog() {
    var _width = MediaQuery.of(context).size.width;
    var _height = MediaQuery.of(context).size.height;
    return Positioned(
        bottom: _height / 8,
        right: _width / 4,
        left: _width / 4,
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), color: Colors.white),
            height: SizeConfig.safeBlockVertical * 18,
            width: _width / 4,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(
                    height: ((_height / 6) / 10) * 1,
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isGetNotesButtonClicked = false;

                        Analytics.analytics.logEvent(
                          name: "send_email",
                          parameters: <String, dynamic>{
                            'userId': ProfileManager.shared().getUserUUID(),
                            'lessonId': ProfileManager.shared()
                                .getLessonIds()[selected],
                          },
                        );

                        showDialog(
                          context: context,
                          builder: (context) => Center(
                            child: CustomDialogPopup(
                              description: "Email is being sent..." ?? "",
                              disableButton: true,
                              enableProgressIndicator: true,
                              buttonText: "CLOSE",
                            ),
                          ),
                        );
                        postSendEmail(ProfileManager.shared()
                            .getLessonIds()[selected])
                            .timeout(
                          TIMEOUT_DURATION,
                          onTimeout: () {
                            setState(() {
                              _isLoading = false;
                            });

                            return _showTimeoutDialog();
                          },
                        ).then((value) {
                          if (value.statusCode == 200) {
                            setState(() {
                              Analytics.analytics.logEvent(
                                name: "send_email_successful",
                                parameters: <String, dynamic>{
                                  'userId':
                                  ProfileManager.shared().getUserUUID(),
                                  'lessonId': ProfileManager.shared()
                                      .getLessonIds()[selected],
                                },
                              );

                              Navigator.of(context).pop();
                              showDialog(
                                context: context,
                                builder: (context) => Center(
                                  child: CustomDialogPopup(
                                    description:
                                    "Email is successfully sent to your email address" ??
                                        "",
                                    disableButton: false,
                                    buttonText: "CLOSE",
                                    onTap: _downloadDoneButtonCallback,
                                  ),
                                ),
                              );
                            });
                          } else {
                            Analytics.analytics.logEvent(
                              name: "send_email_failed",
                              parameters: <String, dynamic>{
                                'userId': ProfileManager.shared().getUserUUID(),
                                'lessonId': ProfileManager.shared()
                                    .getLessonIds()[selected],
                              },
                            );
                            setState(() {
                              Navigator.of(context).pop();
                            });

                            showDialog(
                              context: context,
                              builder: (context) => Center(
                                child: CustomDialogPopup(
                                  description:
                                  "Oops. Something went wrong with sending the attachment to your email address. Try again later" ??
                                      "",
                                  disableButton: false,
                                  enableProgressIndicator: false,
                                  buttonText: "CLOSE",
                                  onTap: _downloadDoneButtonCallback,
                                ),
                              ),
                            );
                          }
                        });
                      });
                    },
                    child: Container(
                      height: ((_height / 6) / 3) * 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            child: Image.asset("assets/icons/Envelope.png"),
                            width: 16,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              "Email me",
                              style: TextStyle(
                                  fontSize:
                                  SizeConfig.safeBlockHorizontal * 4.8,
                                  color: inputFieldHintColor),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Container(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        thickness: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isGetNotesButtonClicked = false;
                      });
                      _downloadManager();

                      if (_downloadDone == false) {
                      } else {
                        Analytics.analytics.logEvent(
                          name: "download_attachment",
                          parameters: <String, dynamic>{
                            'userId': ProfileManager.shared().getUserUUID(),
                            'lessonId': ProfileManager.shared()
                                .getLessonIds()[selected],
                          },
                        );
                        showDialog(
                          context: context,
                          builder: (context) => Center(
                            child: CustomDialogPopup(
                              description:
                              "Downloading in the background" ?? "",
                              disableButton: true,
                              enableProgressIndicator: true,
                              buttonText: "CLOSE",
                              onTap: _downloadDoneButtonCallback,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: ((_height / 6) / 3) * 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            child: Image.asset("assets/icons/Phone.png"),
                            width: 10,
                          ),
                          Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                "Download",
                                style: TextStyle(
                                    fontSize:
                                    SizeConfig.safeBlockHorizontal * 4.8,
                                    color: inputFieldHintColor),
                              ))
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: ((_height / 6) / 10) * 1,
                  ),
                ]),
          ),
        ));
  }

  /* this manager downloads the materials. Different logic for iOS and Android */
  _downloadManager() async {
    bool _isDownloading = false;
    setState(() {
      _isDownloading = !_isDownloading;
    });
    var directory;
    var urlPath = ProfileManager.shared().getLessonNotesUrls()[selected];

    Dio dio = Dio();

    /* Download logic */
    _downloadProcess() {
      dio.download(
          urlPath,
          Platform.isAndroid
              ? "${directory.toString()}/${urlPath.split('/').last}" //on android it's being downloaded to the download folder
              : "${directory.path}/${urlPath.split('/').last}", // on ios it's being downloaded to the document folder of the app
          onReceiveProgress: (actualBytes, totalBytes) {
            var percentage = actualBytes / totalBytes * 100;

            _downloadStatus = "${percentage.floor()}%";
            print("Download message: $_downloadStatus");
            if (percentage < 100) {
              _downloadDone = false;
            } else {
              print("Download is done");
              _downloadDone = true;
              Timer(Duration(seconds: 2), () {
                Navigator.pop(context);

                Analytics.analytics.logEvent(
                  name: "download_attachment_done",
                  parameters: <String, dynamic>{
                    'userId': ProfileManager.shared().getUserUUID(),
                    'lessonId': ProfileManager.shared().getLessonIds()[selected],
                  },
                );

                showDialog(
                  context: context,
                  builder: (context) => Center(
                    child: CustomDialogPopup(
                      description:
                      "Download finished successfully. You can check the file in the Downloads folder" ??
                          "",
                      disableButton: false,
                      buttonText: "CLOSE",
                      onTap: _downloadDoneButtonCallback,
                    ),
                  ),
                );
              });
            }
          });
      _isGetNotesButtonClicked = false;
    }

    openstorage() async {
      PermissionStatus permission = await PermissionHandler()
          .checkPermissionStatus(PermissionGroup.storage);
      if (permission.value == PermissionStatus.denied.value) {
        Map<PermissionGroup, PermissionStatus> permissions =
        await PermissionHandler()
            .requestPermissions([PermissionGroup.storage]);
        if (permissions[PermissionGroup.storage] == PermissionStatus.granted) {
          directory = await ExtStorage.getExternalStoragePublicDirectory(
              ExtStorage.DIRECTORY_DOWNLOADS);
          print("!!!!!!!!!!!!!!!!!!!!!!!!!!!Download path $directory");
          _downloadProcess();
        }
      } else {
        directory = await ExtStorage.getExternalStoragePublicDirectory(
            ExtStorage.DIRECTORY_DOWNLOADS);
        print("######################Download path $directory");
        _downloadProcess();
      }
    }

    /* Download starter for iOS */
    if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
      _downloadProcess();
    }

    if (Platform.isAndroid) {
      openstorage();
    }
  }

  /*---------- DownloadVideo  ---------------  */
  _downloadVideo() async* {
    // bool _isDownloading = false;
    setState(() {
      //    _isDownloading = !_isDownloading;
    });
    var directory;
    var urlPath = ProfileManager.shared().getLocalVideoLink()[selected];

    Dio dio = Dio();

    /* Download logic */
    _downloadProcess() {
      dio.download(
          "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
          Platform.isAndroid
              ? "/sdcard/Download/" //on android it's being downloaded to the download folder
              : "${directory.path}/${urlPath.split('/').last}", // on ios it's being downloaded to the document folder of the app
          onReceiveProgress: (actualBytes, totalBytes) {
            var percentage = actualBytes / totalBytes * 100;
            bitdata = (() async* {
              yield actualBytes / totalBytes;
            })();
            /* setState(() {
                    incrementer = actualBytes / totalBytes;
              });*/
            _downloadStatus = "${percentage.floor()}%";
            print("Download message: $_downloadStatus");
            if (percentage < 100) {
              _downloadDone = false;
            } else {
              print("Download is done");
              _downloadDone = true;
              Timer(Duration(seconds: 2), () {
                // Navigator.pop(context);

                showDialog(
                  context: context,
                  builder: (context) => Center(
                    child: CustomDialogPopup(
                      description:
                      "Downloading in the background" ?? "",
                      disableButton: true,
                      enableProgressIndicator: true,
                      buttonText: "CLOSE",
                      onTap: _downloadDoneButtonCallback,
                    ),
                  ),
                );

                Analytics.analytics.logEvent(
                  name: "download_video_done",
                  parameters: <String, dynamic>{
                    'userId': ProfileManager.shared().getUserUUID(),
                    'lessonId': ProfileManager.shared().getLessonIds()[selected],
                  },
                );

                showDialog(
                  context: context,
                  builder: (context) => Center(
                    child: CustomDialogPopup(
                      description:
                      "Download finished successfully." ??
                          "",
                      disableButton: false,
                      buttonText: "CLOSE",
                      onTap: _downloadDoneButtonCallback,
                    ),
                  ),
                );
              });
            }
          });
      _isGetNotesButtonClicked = false;
    }

    openstorage() async {
      PermissionStatus permission = await PermissionHandler()
          .checkPermissionStatus(PermissionGroup.storage);
      if (permission.value == PermissionStatus.denied.value) {
        Map<PermissionGroup, PermissionStatus> permissions =
        await PermissionHandler()
            .requestPermissions([PermissionGroup.storage]);
        if (permissions[PermissionGroup.storage] == PermissionStatus.granted) {
          directory = await ExtStorage.getExternalStoragePublicDirectory(
              ExtStorage.DIRECTORY_DOWNLOADS);
          print("!!!!!!!!!!!!!!!!!!!!!!!!!!!Download path $directory");
          _downloadProcess();
        }
      } else {
        directory = await ExtStorage.getExternalStoragePublicDirectory(
            ExtStorage.DIRECTORY_DOWNLOADS);
        print("######################Download path $directory");
        _downloadProcess();
      }
    }

    /* Download starter for iOS */
    if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
      _downloadProcess();
    }

    if (Platform.isAndroid) {
      openstorage();
    }
  }
  /* --------- end of downloading video   */

  /* Previous section with the date picker */
  _buildPrevious() {
     // return LibraryScreen();
    List<DateTime> years = [];
        print(ProfileManager.shared().getClassId());
    print(ProfileManager.shared().getLessons());
    print(ProfileManager.shared().getLessons()[0].map((e) {
      years.add(DateTime.parse(e.startsAt));
    }));
    years = years.toSet().toList(); //remove duplicates
    print(years);
    // print(DateFormat("yyyy").format(years[0]));
    // print(DateFormat.y().format(new DateTime.);

    if(semesterEndDates!=null && semesterStartDates!=null)
    return ComplexDatePickerHome(
      lists: {
        "year": ["2020", "2019", "2018"],
        "semester": ["1st Semester", "2nd Semester"],
        "term": ["1st term", "2nd term", "3rd term"]
      },
      miniDate: DateTime.parse(semesterStartDates[selected]),
      maxiDate: DateTime.parse(semesterEndDates[selected]),
      // currentDate: DateTime.now(),
    );
    else return SizedBox(height: 20,);
  }

  /* Chat with reply function with Firebase firestore */
  _buildChat() {

    _getChatMessages(ProfileManager.shared().getLessonIds()[selected],
        ProfileManager.shared().getLessonClassIds()[selected],
        ProfileManager.shared().getLessonVimeoIds()[selected]
    ).then((value){
      setState(() {
        _chatMessage = value;
        /*value.sort((a,b){
          var ax = a['id'];
          var bx = b['id'];
          return ax.compareTo(bx);
        });*/


      });
    });

    return _chatMessage == null ?Column(
      children: [
        SizedBox(height: 15,),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Center(child: Text("Loading...",style: TextStyle(color: Colors.grey,fontSize: 20),)),
        )
      ],
    ) :
      Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            controller: _chatController,
            reverse: true,
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: _chatMessage.length,
            itemBuilder: (BuildContext context, int index) {
              /*setState(() {
                _indexParent = index;
              });*/
              var reply = _chatMessage[index].type == "reply";
              return Container(
                  decoration: BoxDecoration(
                    color: programBackgroundColorInactive,
                  ),
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        child: Padding(
                          padding:
                          EdgeInsets.fromLTRB(reply ? 70 : 20, 6, 8, 2),
                          child: Align(
                            child: Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15.0),
                                    border:
                                    Border.all(color: Colors.greenAccent)),
                                height: SizeConfig.safeBlockHorizontal * 8,
                                width: SizeConfig.safeBlockHorizontal * 8,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Image.asset(
                                      "assets/icons/avatars/diamond.png",
                                      fit: BoxFit.cover),
                                )),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                          child: Container(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(0),
                                      topRight: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8)),
                                  border: Border.all(
                                      width: _activeReplyChatIndex == index
                                          ? 2.0
                                          : 2.0,
                                      color: _activeReplyChatIndex == index
                                          ? Colors.green
                                          : Colors.transparent),
                                  color:
                                  _chatMessage[index].sender_id == 0
                                  //ProfileManager.shared().getUsername()
                                      ? Colors.blue[100]
                                      : Colors.white,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _buildMessageBox(index, reply),
                                ),
                              )),
                        ),
                      )
                    ],
                  ));
            },
          ),
        ),
        Container(
            height: SizeConfig.safeBlockVertical * 12,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                SizedBox(
                  width: SizeConfig.safeBlockHorizontal * 10,
                ),
                _buildInputField(_activeReplyChatIndex != null),
                SizedBox(
                  width: SizeConfig.safeBlockHorizontal * 3,
                ),
                GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: SizeConfig.safeBlockHorizontal * 8,
                    child: Container(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          RawMaterialButton(
                            onPressed: () {
                            //  _postChatMessage();
                              _sendMessage(selected, _indexParent, _activeReplyChatIndex != null);
                              SystemChannels.textInput
                                  .invokeMethod('TextInput.hide');
                            },
                            elevation: 2.0,
                            fillColor: Color.fromRGBO(42, 203, 114, 1),
                            child: Center(
                              child: Image.asset("assets/icons/flight.png",
                                  width: SizeConfig.safeBlockHorizontal * 5),
                            ),
                            padding: EdgeInsets.all(6),
                            shape: CircleBorder(),
                          ),
                          Text(
                            "Post",
                            style: TextStyle(
                                color:
                                programInactiveTextColor.withOpacity(0.5),
                                fontFamily: "Roboto Regular",
                                fontSize: 13),
                          ),
                          SizedBox(
                            height: SizeConfig.safeBlockVertical * 2.2,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: SizeConfig.safeBlockHorizontal * 3,
                ),
              ],
            )),
      ],
    );
  }

  _buildReply(int myIndex,List<ChatMessage> repliesMessages) {

    _getReplyList(repliesMessages, myIndex).then((value){

      return value == null ?Column(
        children: [
          SizedBox(height: 15,),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(child: Text("Loading...",style: TextStyle(color: Colors.grey,fontSize: 20),)),
          )
        ],
      ) :
      Container(
        child: ListView.builder(
          controller: _chatController,
          reverse: true,
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: value.length,
          itemBuilder: (BuildContext context, int index) {
            var reply = value[index].type == "reply";
            return Container(
                decoration: BoxDecoration(
                  color: programBackgroundColorInactive,
                ),
                width: double.infinity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      child: Padding(
                        padding:
                        EdgeInsets.fromLTRB(reply ? 70 : 20, 6, 8, 2),
                        child: Align(
                          child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15.0),
                                  border:
                                  Border.all(color: Colors.greenAccent)),
                              height: SizeConfig.safeBlockHorizontal * 8,
                              width: SizeConfig.safeBlockHorizontal * 8,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Image.asset(
                                    "assets/icons/avatars/diamond.png",
                                    fit: BoxFit.cover),
                              )),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                        child: Container(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(0),
                                    topRight: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8)),
                                border: Border.all(
                                    width: _activeReplyChatIndex == index
                                        ? 2.0
                                        : 2.0,
                                    color: _activeReplyChatIndex == index
                                        ? Colors.green
                                        : Colors.transparent),
                                color:
                                value[index].sender_id == 0
                                //ProfileManager.shared().getUsername()
                                    ? Colors.blue[100]
                                    : Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: _buildReplyBox(index, value),
                              ),
                            )),
                      ),
                    )
                  ],
                ));
          },
        ),
      );

    });


  }

  _buildInputField(bool activeReply) {
    var hintText = activeReply ? "Write reply..." : "Ask a question...";
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: TextField(
            textInputAction: TextInputAction.send,
            onSubmitted: (value) {
              _postChatMessage();
              _chatTextController.clear();
            },
            controller: _chatTextController,
            //obscureText: widget.secure == null ? false : widget.secure,
            decoration: InputDecoration(
              filled: true,
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 10, 0),
              alignLabelWithHint: true,
              fillColor: Color.fromRGBO(243, 245, 248, 1),
              hintStyle: TextStyle(
                  fontFamily: "Roboto Light", color: inputFieldHintColor),
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _buildMessageBox(int index, bool reply) {
    DateTime time = DateTime.parse(_chatMessage[index].created_at);
    var date = time;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!reply) {
          setState(() {
            _activeReplyChatIndex = index;
          });
        } else {
          setState(() {
            _activeReplyChatIndex = null;
            _chatTextController.text = "";
          });
        }
      },
      child:ExpandablePanel(
        collapsed:  Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                _chatMessage[index].content.toString(),
                style: TextStyle(
                    color: programInactiveTextColor,
                    fontFamily: "Roboto",
                    fontSize: SizeConfig.safeBlockHorizontal * 4),
              ),
            ),
            SizedBox(height: SizeConfig.safeBlockHorizontal * 2.33),
            Container(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          "User name",
                          style: TextStyle(
                              color: Colors.grey, fontFamily: "Roboto", fontSize: 11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          reply
                              ? DateCalculator.getDiffererence2DatesInText(
                              DateTime.now(), date)
                              : DateCalculator.getDiffererence2DatesInText(
                              DateTime.now(), date) +
                              " | Reply",
                          style: TextStyle(
                              color: Colors.grey, fontFamily: "Roboto", fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                )),
          ],
        ),
        expanded: _buildReply(index,_chatMessage),
        tapHeaderToExpand: true,
        tapBodyToCollapse: true,
      )
    );
  }

  _buildReplyBox(int index,List<ChatMessage> replyList, { bool reply=false}) {
    DateTime time = DateTime.parse(replyList[index].created_at);
    var date = time;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!reply) {
          setState(() {
            _activeReplyChatIndex = index;
          });
        } else {
          setState(() {
            _activeReplyChatIndex = null;
            _chatTextController.text = "";
          });
        }
      },
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              replyList[index].content.toString(),
              style: TextStyle(
                  color: programInactiveTextColor,
                  fontFamily: "Roboto",
                  fontSize: SizeConfig.safeBlockHorizontal * 4),
            ),
          ),
          SizedBox(height: SizeConfig.safeBlockHorizontal * 2.33),
          Container(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        "User name",
                        style: TextStyle(
                            color: Colors.grey, fontFamily: "Roboto", fontSize: 11),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        reply
                            ? DateCalculator.getDiffererence2DatesInText(
                            DateTime.now(), date)
                            : DateCalculator.getDiffererence2DatesInText(
                            DateTime.now(), date) +
                            " | Reply",
                        style: TextStyle(
                            color: Colors.grey, fontFamily: "Roboto", fontSize: 11),
                      ),
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  Future<Null> _sendMessage(int index,int parentid,bool activeReply) async {
    print("##### Index is: $index");
    if(_chatTextController.text.trim().isNotEmpty){
      var url = 'https://demo.dextraclass.com/api/questiondata';
      var body = json.encode({
        "content": _chatTextController.text.trim(),
        "parent_id": parentid,
        "sender_type": activeReply ? "reply":"question",
        "lesson_id": ProfileManager.shared().getLessonIds()[index],
        "class_id": ProfileManager.shared().getLessonClassIds()[index],
        "vimeo_id":  ProfileManager.shared().getLessonVimeoIds()[index]

      });

      print(body);

      Map<String, String> headers = {
        'Content-type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.post(url, headers: headers, body: body);
      final res = json.decode(response.body);
      print(response.body);

      if(response.statusCode == 200){
        print("### -> Question posted successfully !!!: $res");
        _chatTextController.clear();

      }

    }

  }

  _postChatMessage() {
    void _loadProfileImages(List<DocumentSnapshot> messages) {
      messages.forEach((e) {
        _chatProfileImages.add(e.data()["userImage"]);
      });
    }

    if (_chatTextController.text != "") {
      FirebaseManager.shared()
          .addNewChatMessageToRoom(
          roomID: ProfileManager.shared().getLessonSubjects()[selected],
          userId: ProfileManager.shared().getProfileId(),
          userName: ProfileManager.shared().getUsername(),
          userImage: ProfileManager.shared().getProfileImage(),
          messageText: _chatTextController.text,
          replyID: _activeReplyChatIndex == null
              ? null
              : _chatItems[_activeReplyChatIndex].documentID)
          .then((value) {
        _activeReplyChatIndex = null;
        print("post succes");
        Future.delayed(Duration(milliseconds: 100)).then((value) {
          FirebaseManager.shared()
              .getAllChatMessagesForRoom(
              ProfileManager.shared().getLessonSubjects()[selected])
              .then((messages) {
            _loadProfileImages(messages);
            setState(() {
              _activeReplyChatIndex = null;
              _chatItems = messages.toList();
            });
          });
        });
      });
    }
  }

/*
  void playOrPauseVideo() async {
    if (Platform.isIOS) {
      bambuseriOSPlugin.PlayingState state =
          _bambuseriOSPlayerController.playingState;
      print("playing state in flutter: $state");
      try {
        if (state == bambuseriOSPlugin.PlayingState.PLAYING) {
          print("############# PAUSED in progress");
          await _bambuseriOSPlayerController.pause();
          setState(() {
            _isBambuserPlaying = false;
            print("############# PAUSED");
          });
        } else {
          print("############# PLAYING in progress");
          await _bambuseriOSPlayerController.play();
          setState(() {
            _isBambuserPlaying = true;
            print("############# PLAYING");
          });
        }
      } catch (e) {
        print("exception $e");
      }
    }

    if (Platform.isAndroid) {
      bambuserAndroidPlugin.PlayingState state =
          _bambuserAndroidPlayerController.playingState;
      print("playing state in flutter: $state");
      try {
        if (state == bambuserAndroidPlugin.PlayingState.PLAYING) {
          await _bambuserAndroidPlayerController.pause();
          setState(() {
            _isBambuserPlaying = false;
          });
        } else {
          await _bambuserAndroidPlayerController.play();
          setState(() {
            _isBambuserPlaying = true;
          });
        }
      } catch (e) {
        print("exception $e");
      }
    }
  }
*/

    @override
  void dispose() {
    PlayerManager.shared()
        .disposeControllers(); //stop playing the video in VLC player
    super.dispose();
  }
  Future<bool> _onBackPressed() {
    return  showDialog(
      context: context,
      builder: (BuildContext context) => Center(
        child: CustomDialogPopup(
          description:
          "Are you sure you want to Exit?                       ",
          buttonText: "NO",
          secondaryButtonText: "YES",
          disableButton: false,
          enableSecondaryButton: true,
          onTap: (){
            Navigator.pop(context);
          },
          secondaryButtonCallback: () =>  SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
        ),
      ),
    ) ??
        false;
  }

}
