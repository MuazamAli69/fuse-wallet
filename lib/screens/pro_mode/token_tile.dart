import 'package:cached_network_image/cached_network_image.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:ethereum_address/ethereum_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fusecash/models/app_state.dart';
import 'package:fusecash/models/community/community.dart';
import 'package:fusecash/models/tokens/token.dart';
import 'package:fusecash/screens/pro_mode/assets_list.dart';
import 'package:fusecash/screens/pro_mode/token_transfers.dart';
import 'package:fusecash/utils/format.dart';

class TokenTile extends StatelessWidget {
  TokenTile({this.token});
  final Token token;
  @override
  Widget build(BuildContext context) {
    final String price = prices.containsKey(token.symbol)
        ? getDollarValue(token.amount, token.decimals, prices[token.symbol])
        : '0';
    bool isFuseTxs = token.originNetwork != null;
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: const Color(0xFFDCDCDC)))),
      child: ListTile(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => TokenTransfersScreen(token: token)));
          },
          contentPadding: EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 0),
          title: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                  flex: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      StoreConnector<AppState, _TokenTileViewModel>(
                          distinct: true,
                          converter: _TokenTileViewModel.fromStore,
                          builder: (_, viewModel) {
                            final bool isCommunityToken = viewModel.communities
                                .any((element) =>
                                    element.token.address == token.address &&
                                    ![false, null].contains(
                                        element.metadata.isDefaultImage));
                            return Flexible(
                                flex: 4,
                                child: Stack(
                                  children: <Widget>[
                                    Stack(
                                      alignment: Alignment.center,
                                      children: <Widget>[
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(50),
                                          child: CachedNetworkImage(
                                            width: 60,
                                            height: 60,
                                            imageUrl: token.imageUrl != null &&
                                                    token.imageUrl.isNotEmpty
                                                ? token.imageUrl
                                                : getTokenUrl(
                                                    checksumEthereumAddress(
                                                        token.address)),
                                            placeholder: (context, url) =>
                                                CircularProgressIndicator(),
                                            errorWidget:
                                                (context, url, error) => Icon(
                                              Icons.error,
                                              size: 54,
                                            ),
                                          ),
                                        ),
                                        token.transactions.list.any(
                                                (transfer) =>
                                                    transfer.isPending())
                                            ? Container(
                                                width: 60,
                                                height: 60,
                                                child:
                                                    CircularProgressIndicator(
                                                  backgroundColor:
                                                      Color(0xFF49D88D)
                                                          .withOpacity(0),
                                                  strokeWidth: 3,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(0xFF49D88D)
                                                              .withOpacity(1)),
                                                ))
                                            : SizedBox.shrink(),
                                        isCommunityToken
                                            ? Text(
                                                token.symbol,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.left,
                                              )
                                            : SizedBox.shrink()
                                      ],
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: SvgPicture.asset(
                                        'assets/images/${isFuseTxs ? 'fuse' : 'ethereum'}_network.svg',
                                        fit: BoxFit.contain,
                                        width: 20,
                                        height: 20,
                                      ),
                                    ),
                                  ],
                                ));
                          }),
                      SizedBox(width: 10.0),
                      Flexible(
                        flex: 10,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          verticalDirection: VerticalDirection.down,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(token.name,
                                style: TextStyle(
                                    color: Color(0xFF333333), fontSize: 15)),
                            SizedBox(
                              width: 5,
                            ),
                            SvgPicture.asset(
                              'assets/images/go_to_pro.svg',
                              width: 10,
                              height: 10,
                            )
                          ],
                        ),
                      ),
                    ],
                  )),
              Flexible(
                  flex: 4,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Stack(
                              overflow: Overflow.visible,
                              alignment: AlignmentDirectional.bottomEnd,
                              children: <Widget>[
                                RichText(
                                    text: TextSpan(children: <TextSpan>[
                                  prices.containsKey(token.symbol)
                                      ? TextSpan(
                                          text: '\$' + price,
                                          style: TextStyle(
                                              fontSize: 15.0,
                                              color: Theme.of(context)
                                                  .primaryColor))
                                      : TextSpan(
                                          text: token.getBalance() +
                                              ' ' +
                                              token.symbol,
                                          style: TextStyle(
                                              fontSize: 15.0,
                                              color: Theme.of(context)
                                                  .primaryColor)),
                                ])),
                                prices.containsKey(token.symbol)
                                    ? Positioned(
                                        bottom: -20,
                                        child: Padding(
                                            child: Text(
                                                token.getBalance() +
                                                    ' ' +
                                                    token.symbol,
                                                style: TextStyle(
                                                    color: Color(0xFF8D8D8D),
                                                    fontSize: 10)),
                                            padding: EdgeInsets.only(top: 10)))
                                    : SizedBox.shrink()
                              ],
                            )
                          ],
                        )
                      ]))
            ],
          )),
    );
  }
}

class _TokenTileViewModel extends Equatable {
  final List<Community> communities;

  _TokenTileViewModel({this.communities});

  static _TokenTileViewModel fromStore(Store<AppState> store) {
    return _TokenTileViewModel(
      communities: store.state.cashWalletState.communities.values.toList(),
    );
  }

  @override
  List<Object> get props => [communities];
}
