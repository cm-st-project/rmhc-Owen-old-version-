import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rmhconnect/constants.dart';
import 'package:rmhconnect/screens/ProfilePhoto.dart';
import 'package:rmhconnect/screens/residents/org_get_info.dart';
import 'package:rmhconnect/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool informationLoaded = false;
  User? user;
  String name = '';
  String role = '';
  String email = '';
  String location = '';
  bool locationPressed = false;
  List<String> orgNames = [];
  bool isLoading = true;

  @override
  void initState(){
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    init();
  }

  Future<void> init() async{
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        try{
          name = userDoc['name'];
          role = userDoc['role'];
          email = userDoc['email'];
          location = userDoc['location'];
          loadOrgNames();
        }catch(e){
          name = '';
          role = '';
          email = '';
          location = '';
        }
        informationLoaded = true;
      });
      }

  }

  Future<String> _promptForPassword() async {
    String password = '';
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Re-enter your password'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                password = controller.text;
                Navigator.of(context).pop();
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
    return password;
  }


  Future<void> loadOrgNames() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('organizations').get();
    final names = snapshot.docs
        .map((doc) => doc.data()['name'] as String?)
        .whereType<String>()
        .toList();

    setState(() {
      orgNames = names;
      isLoading = false;
      print("Loaded $orgNames successfully");
    });
  }

  void _showSettingsMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () => Navigator.pop(context, 'logout'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'logout') {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    } else if (action == 'delete') {
      try {
        // Re-authenticate the user
        final credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: await _promptForPassword(), // You’ll implement this function
        );
        await user?.reauthenticateWithCredential(credential);

        await user?.delete();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .delete();

        if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete account. Try again.")),
        );
      }

    }
  }

  Future<void> updateUserLocationInFirebase(String newLocation) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'location': newLocation});
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: backgroundColor,
          title: Text("My Profile", style: titling),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0,0,30,0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                      )
                  ),
                  IconButton(icon: Icon(Icons.settings), onPressed: _showSettingsMenu),
                ],
              ),
            ),
          ]
      ),
      body: SingleChildScrollView(
        child: Center(
            child: Column(
              children: [
                informationLoaded ?
                  Container(
                  //children: [
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Profilephoto(
                              pfp: "assets/images/person-icon.png",
                            ),
                            Column(
                                children: [
                                  Text(name, style: mytextnormal),
                                  Text(role, style: mytextnormal),
                                  Text(email, style: TextStyle(fontSize: 18, decoration: TextDecoration.underline)),
                                  Text(location, style: mytextnormal),
                                ]
                            )
                          ]
                      ),
                    ],
                  ),
                  //]
                )
                : Center(child: CircularProgressIndicator()),
        
                SizedBox(height: 30),
        
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25,0,0,0),
                      child: Text("Current Charity: ", style: TextStyle(fontSize: 22)),
                    ),
                    SizedBox(width: 10),
        
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: isLoading == false
                          ? SizedBox(
                              width: 150,
                              child: DropdownSearch<String>(
                                items: (f, cs) => orgNames,
                                popupProps: const PopupProps.menu(
                                  fit: FlexFit.loose,
                                ),
                                selectedItem: location,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      location = val;
                                      locationPressed = false;
                                    });
                                    updateUserLocationInFirebase(location);
                                  }
                                },
                              ),
                            )
                            : const SizedBox(),
                      ),
                    ),
                  ]
                ),
        
        
                Padding(
                  padding: const EdgeInsets.fromLTRB(0,18.0,0,0),
                  child: Text("My Events", style: titlingblck),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      OrgGetInfo()
                    ],
                  ),
                )
              ]
            )
          ),
      )
    );
  }
}
