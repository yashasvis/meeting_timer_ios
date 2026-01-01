// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NoInternetConnectionPage extends StatefulWidget{
  const NoInternetConnectionPage({super.key});

  @override
  State<NoInternetConnectionPage> createState() => _NoInternetConnectionPage();
}
class _NoInternetConnectionPage extends State<NoInternetConnectionPage>{
  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: Image.asset(
                  "Asset/no-connection.webp",
                  color: Colors.blue,
                ),
              ),
              Padding(
                  padding: EdgeInsets.only(top: screenSize.height * 0.01),
                  child: const Text(
                    "Oops..!!",
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontFamily: 'Cabin-Bold'
                    ),
                  )
              ),
              Padding(
                  padding: EdgeInsets.only(top: screenSize.height * 0.02),
                  child: const Text(
                    "No Internet Connection",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.blue,
                        fontFamily: 'Cabin'
                    ),
                  )
              ),
              Padding(
                  padding: EdgeInsets.only(top: screenSize.height * 0.01),
                  child: const Text(
                    "Please check your network.",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.blue,
                        fontFamily: 'Cabin'
                    ),
                  )
              ),
              Padding(
                padding: EdgeInsets.only(top: screenSize.height * 0.05),
                child: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero
                  ),
                  onPressed: () async{
                    final connectivityResult = await (Connectivity().checkConnectivity());
                    if(connectivityResult[0].index == 4){
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Please connect to your network.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Cabin-Bold',
                                fontSize: 13,
                                color: Colors.red
                            ),
                          ),
                          backgroundColor:Colors.red.shade100,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(10),
                        ));
                    }
                  },
                  child: Container(
                      width: screenSize.width * 0.30,
                      height: screenSize.height * 0.06,
                      padding: EdgeInsets.zero,
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        border: Border.all(
                          width: 1.0,
                          color: Colors.blue,
                        ),
                        borderRadius: const BorderRadius.all(
                            Radius.circular(25.0)
                        ),
                      ),
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Retry",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      )
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }

}