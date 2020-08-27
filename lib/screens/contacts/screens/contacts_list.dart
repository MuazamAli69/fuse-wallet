import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_segment/flutter_segment.dart';
import 'package:ceu_do_mapia/generated/i18n.dart';
import 'package:ceu_do_mapia/models/app_state.dart';
import 'package:ceu_do_mapia/models/views/contacts.dart';
import 'package:ceu_do_mapia/screens/contacts/widgets/contact_tile.dart';
import 'package:ceu_do_mapia/screens/contacts/widgets/recent_contacts.dart';
import 'package:ceu_do_mapia/utils/contacts.dart';
import 'package:ceu_do_mapia/utils/format.dart';
import 'package:ceu_do_mapia/utils/phone.dart';
import 'package:ceu_do_mapia/utils/send.dart';
import 'package:ceu_do_mapia/widgets/main_scaffold.dart';
import "package:ethereum_address/ethereum_address.dart";
import 'package:ceu_do_mapia/widgets/preloader.dart';
import 'package:ceu_do_mapia/widgets/silver_app_bar.dart';

class ContactsList extends StatefulWidget {
  @override
  _ContactsListState createState() => _ContactsListState();
}

class _ContactsListState extends State<ContactsList> {
  List<Contact> userList = [];
  List<Contact> filteredUsers = [];
  bool hasSynced = false;
  TextEditingController searchController = TextEditingController();
  bool isPreloading = false;
  List<Contact> _contacts;

  @override
  void dispose() {
    super.dispose();
    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new StoreConnector<AppState, ContactsViewModel>(
        distinct: true,
        onInitialBuild: (viewModel) {
          Segment.screen(screenName: '/contacts-screen');
        },
        converter: ContactsViewModel.fromStore,
        builder: (_, viewModel) {
          return _contacts != null
              ? MainScaffold(
                  automaticallyImplyLeading: false,
                  title: I18n.of(context).send_to,
                  sliverList: _buildPageList(viewModel),
                )
              : Center(
                  child: Preloader(),
                );
        });
  }

  Future<void> refreshContacts() async {
    List<Contact> contacts = await ContactController.getContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
      });
    }

    filterList();
    searchController.addListener(filterList);

    if (Platform.isAndroid) {
      for (final contact in contacts) {
        ContactsService.getAvatar(contact).then((avatar) {
          if (avatar == null) return;
          if (mounted) {
            setState(() => contact.avatar = avatar);
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    refreshContacts();
  }

  filterList() {
    List<Contact> users = [];
    users.addAll(_contacts);
    if (searchController.text.isNotEmpty) {
      users.retainWhere((user) => user.displayName
          .toLowerCase()
          .contains(searchController.text.toLowerCase()));
    }

    if (this.mounted) {
      setState(() {
        filteredUsers = users;
      });
    }
  }

  void resetSearch() {
    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() {
        searchController.text = '';
      });
    }
  }

  SliverPersistentHeader listHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      floating: true,
      delegate: SliverAppBarDelegate(
        minHeight: 40.0,
        maxHeight: 40.0,
        child: Container(
          color: Color(0xFFF8F8F8),
          padding: EdgeInsets.only(left: 20, top: 7),
          child: Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  SliverList listBody(ContactsViewModel viewModel, List<Contact> group) {
    List<Widget> listItems = List();
    for (Contact user in group) {
      Iterable<Item> phones = user.phones
          .map((e) => Item(
              label: e.label, value: clearNotNumbersAndPlusSymbol(e.value)))
          .toSet()
          .toList();
      for (Item phone in phones) {
        listItems.add(ContactTile(
            image: user.avatar != null && user.avatar.isNotEmpty
                ? MemoryImage(user.avatar)
                : null,
            displayName: user.displayName,
            phoneNumber: phone.value,
            onTap: () {
              resetSearch();
              sendToContact(ExtendedNavigator.named('contactsRouter').context,
                  user.displayName, phone.value,
                  isoCode: viewModel.isoCode,
                  countryCode: viewModel.countryCode,
                  avatar: user.avatar != null && user.avatar.isNotEmpty
                      ? MemoryImage(user.avatar)
                      : new AssetImage('assets/images/anom.png'));
            },
            trailing: Text(
              phone.value,
              style: TextStyle(
                  fontSize: 13, color: Theme.of(context).primaryColor),
            )));
      }
    }
    return SliverList(
      delegate: SliverChildListDelegate(listItems),
    );
  }

  Widget sendToAcccountAddress(String accountAddress) {
    Widget component = ContactTile(
      displayName: formatAddress(accountAddress),
      onTap: () {
        resetSearch();
        sendToPastedAddress(accountAddress);
      },
      trailing: InkWell(
        child: Text(
          I18n.of(context).next_button,
          style: TextStyle(color: Color(0xFF0377FF)),
        ),
        onTap: () {
          resetSearch();
          sendToPastedAddress(accountAddress);
        },
      ),
    );
    return SliverList(
      delegate: SliverChildListDelegate([component]),
    );
  }

  List<Widget> _buildPageList(ContactsViewModel viewModel) {
    List<Widget> listItems = List();

    listItems.add(searchPanel(viewModel));

    if (searchController.text.isEmpty) {
      listItems.add(RecentContacts());
    } else if (isValidEthereumAddress(searchController.text)) {
      listItems.add(sendToAcccountAddress(searchController.text));
    }

    Map<String, List<Contact>> groups = new Map<String, List<Contact>>();
    for (Contact c in filteredUsers) {
      String groupName = c.displayName[0];
      if (!groups.containsKey(groupName)) {
        groups[groupName] = new List<Contact>();
      }
      groups[groupName].add(c);
    }

    List<String> titles = groups.keys.toList()..sort();

    for (String title in titles) {
      List<Contact> group = groups[title];
      listItems.add(listHeader(title));
      listItems.add(listBody(viewModel, group));
    }

    return listItems;
  }

  SliverPersistentHeader searchPanel(ContactsViewModel viewModel) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: SliverAppBarDelegate(
        minHeight: 80.0,
        maxHeight: 100.0,
        child: Container(
          decoration: new BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8)))),
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: TextFormField(
                    controller: searchController,
                    style: TextStyle(fontSize: 18, color: Colors.black),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(0.0),
                      border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFFE0E0E0), width: 3)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: const Color(0xFF292929)),
                      ),
                      suffixIcon: Icon(
                        Icons.search,
                        color: Color(0xFFACACAC),
                      ),
                      labelText: I18n.of(context).search,
                    ),
                  ),
                ),
              ),
              Container(
                width: 45,
                height: 45,
                child: new FloatingActionButton(
                    heroTag: 'contacts_list',
                    backgroundColor: const Color(0xFF292929),
                    elevation: 0,
                    child: Image.asset(
                      'assets/images/scan.png',
                      width: 25.0,
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    onPressed: () {
                      bracodeScannerHandler();
                      if (mounted) {
                        setState(() {
                          searchController.text = '';
                        });
                      }
                    }),
              )
            ],
          ),
        ),
      ),
    );
  }
}
