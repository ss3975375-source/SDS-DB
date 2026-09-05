import 'package:flutter/material.dart';
import 'notification_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState()=>_NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationPreferences p=const NotificationPreferences();

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Notifications')),
    body:ListView(children:[
      SwitchListTile(title:const Text('Messages'),value:p.messagesEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(messagesEnabled:v))),
      SwitchListTile(title:const Text('Groups'),value:p.groupsEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(groupsEnabled:v))),
      SwitchListTile(title:const Text('Contact requests'),value:p.contactRequestsEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(contactRequestsEnabled:v))),
      SwitchListTile(title:const Text('Feel It'),value:p.feelItEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(feelItEnabled:v))),
      const Divider(),
      SwitchListTile(
        title:const Text('Show previews on lock screen'),
        subtitle:const Text('Off by default. Android/iOS system settings can also affect this.'),
        value:p.lockScreenPreviewEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(lockScreenPreviewEnabled:v)),
      ),
      SwitchListTile(title:const Text('Sound'),value:p.soundEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(soundEnabled:v))),
      SwitchListTile(title:const Text('Vibration'),value:p.vibrationEnabled,
        onChanged:(v)=>setState(()=>p=p.copyWith(vibrationEnabled:v))),
    ]),
  );
}
