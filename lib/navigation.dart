import 'package:flutter/material.dart';

// Lets non-widget code (like ApiClient) navigate the app, e.g. to redirect
// to LoginScreen when a request comes back with 401.
final navigatorKey = GlobalKey<NavigatorState>();
