import 'package:flutter/material.dart';
import '../data/group_repository.dart';
import '../domain/group.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key, required this.repository});
  final GroupRepository repository;
  @override State<GroupsPage> createState()=>_GroupsPageState();
}
class _GroupsPageState extends State<GroupsPage> {
  late Future<List<Group>> _future;
  @override void initState(){super.initState();_future=widget.repository.list();}
  void _reload(){setState(()=>_future=widget.repository.list());}
  Future<void> _create() async {
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(context)=>AlertDialog(title:const Text('Create group'),content:TextField(controller:controller,autofocus:true,maxLength:100,decoration:const InputDecoration(labelText:'Group name')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,controller.text.trim()),child:const Text('Create'))]));
    controller.dispose();
    if(name==null||name.isEmpty)return;
    try{await widget.repository.create(name);if(mounted)_reload();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not create group: $e')));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Groups'),actions:[IconButton(onPressed:_reload,icon:const Icon(Icons.refresh))]),floatingActionButton:FloatingActionButton.extended(onPressed:_create,icon:const Icon(Icons.group_add),label:const Text('New group')),body:FutureBuilder<List<Group>>(future:_future,builder:(context,snapshot){if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(snapshot.hasError)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Could not load groups'),const SizedBox(height:8),FilledButton(onPressed:_reload,child:const Text('Retry'))]));final groups=snapshot.data??const [];if(groups.isEmpty)return const Center(child:Text('No groups yet'));return RefreshIndicator(onRefresh:()async=>_reload(),child:ListView.separated(padding:const EdgeInsets.all(12),itemCount:groups.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final g=groups[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.groups_outlined)),title:Text(g.name),subtitle:Text('${g.memberCount} members • ${g.role}'),trailing:const Icon(Icons.chevron_right)));});}));
}
