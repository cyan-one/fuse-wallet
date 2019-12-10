import 'package:fusecash/models/error_state.dart';
import 'package:fusecash/models/transfer.dart';
import 'package:fusecash/redux/actions/error_actions.dart';
import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:wallet_core/wallet_core.dart';
import 'package:fusecash/services.dart';
import 'package:fusecash/models/token.dart';
import 'dart:async';

class InitWeb3Success {
  final Web3 web3;
  InitWeb3Success(this.web3);
}

class OnboardUserSuccess {
  final String accountAddress;
  OnboardUserSuccess(this.accountAddress);
}

class GetWalletAddressSuccess {
  final String walletAddress;
  GetWalletAddressSuccess(this.walletAddress);
}

class CreateAccountWalletRequest {
  final String accountAddress;
  CreateAccountWalletRequest(this.accountAddress);
}

class CreateAccountWalletSuccess {
  final String accountAddress;
  CreateAccountWalletSuccess(this.accountAddress);
}

class GetTokenBalanceSuccess {
  final BigInt tokenBalance;
  GetTokenBalanceSuccess(this.tokenBalance);
}

class SendTokenSuccess {
  final String txHash;
  SendTokenSuccess(this.txHash);
}

class JoinCommunitySuccess {
  final String txHash;
  final String communityAddress;
  final String communityName;
  final Token token;
  JoinCommunitySuccess(this.txHash, this.communityAddress, this.communityName,
      this.token);
}

class AlreadyJoinedCommunity {
  final String communityAddress;
  final String communityName;
  final Token token;
  AlreadyJoinedCommunity(this.communityAddress, this.communityName,
      this.token);
}

class SwitchCommunityRequested {
  final String communityAddress;
  SwitchCommunityRequested(this.communityAddress);

}
class SwitchCommunitySuccess {
  final Token token;
  final String communityAddress;
  final String communityName;
  SwitchCommunitySuccess(this.communityAddress, this.communityName,
      this.token);
}

class GetJoinBonusSuccess {
  // TODO
  GetJoinBonusSuccess();
}

class GetBusinessListSuccess {
  // TODO
  GetBusinessListSuccess();
}

class GetTokenTransfersListSuccess {
  List<Transfer> tokenTransfers;
  GetTokenTransfersListSuccess(this.tokenTransfers);
}

Future<bool> approvalCallback() async {
  return true;
}

ThunkAction initWeb3Call(String privateKey) {
  return (Store store) async {
    try {
      Web3 web3 = new Web3(approvalCallback);
      web3.setCredentials(privateKey);
      store.dispatch(new InitWeb3Success(web3));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not init web3'));
    }
  };
}

ThunkAction startBalanceFetchingCall(String tokenAddress) {
  return (Store store) async {
    store.dispatch(getTokenBalanceCall(tokenAddress));
    new Timer.periodic(Duration(seconds: 5), (Timer t) async {
      if (store.state.cashWalletState.walletAddress == '') {
        t.cancel();
        return;
      }
      store.dispatch(getTokenBalanceCall(tokenAddress));
    });
  };
}

ThunkAction startTransfersFetchingCall(String tokenAddress) {
  return (Store store) async {
    store.dispatch(getTokenTransfersListCall(tokenAddress));
    new Timer.periodic(Duration(seconds: 5), (Timer t) async {
      if (store.state.cashWalletState.walletAddress == '') {
        t.cancel();
        return;
      }
      store.dispatch(getTokenTransfersListCall(tokenAddress));
    });
  };
}

ThunkAction createAccountWalletCall(String accountAddress) {
  return (Store store) async {
    try {
      store.dispatch(new CreateAccountWalletRequest(accountAddress));
      await api.createWallet();
      store.dispatch(new CreateAccountWalletSuccess(accountAddress));
      new Timer.periodic(Duration(seconds: 5), (Timer t) async {
        dynamic wallet = await api.getWallet();
        String walletAddress = wallet["walletAddress"];
        if (walletAddress != null && walletAddress.isNotEmpty) {
          store.dispatch(new GetWalletAddressSuccess(walletAddress));
          t.cancel();
        }
      });
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not create wallet'));
    }
  };
}

ThunkAction getWalletAddressCall() {
  return (Store store) async {
    try {
      dynamic wallet = await api.getWallet();
      String walletAddress = wallet["walletAddress"];
      store.dispatch(new GetWalletAddressSuccess(walletAddress));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not get wallet address'));
    }
  };
}

ThunkAction getTokenBalanceCall(String tokenAddress) {
  return (Store store) async {
    try {
      String walletAddress = store.state.cashWalletState.walletAddress;
      print('fetching token balance of $tokenAddress for $walletAddress wallet');
      BigInt tokenBalance =
          await graph.getTokenBalance(walletAddress, tokenAddress);
      store.dispatch(new GetTokenBalanceSuccess(tokenBalance));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not get token balance'));
    }
  };
}

ThunkAction sendTokenCall(String receiverAddress, num tokensAmount) {
  return (Store store) async {
    try {
      Web3 web3 = store.state.cashWalletState.web3;
      String walletAddress = store.state.cashWalletState.walletAddress;
      String tokenAddress = store.state.cashWalletState.token.address;
      await api.tokenTransfer(web3, walletAddress, tokenAddress, receiverAddress, tokensAmount);
      // store.dispatch(new SendTokenSuccess(txHash));
      store.dispatch(getTokenBalanceCall(tokenAddress));
      store.dispatch(getTokenTransfersListCall(tokenAddress));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not send token'));
    }
  };
}

ThunkAction joinCommunityCall({String communityAddress}) {
  return (Store store) async {
    try {
      Web3 web3 = store.state.cashWalletState.web3;
      String walletAddress = store.state.cashWalletState.walletAddress;
      communityAddress = communityAddress ?? Web3.getDefaultCommunity();
      dynamic community =
          await graph.getCommunityByAddress(communityAddress: communityAddress);
      dynamic token =
          await graph.getTokenOfCommunity(communityAddress: communityAddress);
      bool isMember = await graph.isCommunityMember(
          walletAddress, community["entitiesList"]["address"]);
      if (isMember) {
        return store.dispatch(new AlreadyJoinedCommunity(
            communityAddress,
            community["name"],
            new Token(address: token["address"], name: token["name"], symbol: token["symbol"], decimals: token["decimals"])));
      }
      await api.joinCommunity(web3, walletAddress, communityAddress);
      // return store.dispatch(new JoinCommunitySuccess(
      //     txHash,
      //     communityAddress,
      //     community["name"],
      //     new Token(address: token["address"], name: token["name"], symbol: token["symbol"], decimals: token["decimals"])));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not join community'));
    }
  };
}

ThunkAction switchCommunityCall({String communityAddress}) {
  return (Store store) async {
    try {
      communityAddress = communityAddress ?? Web3.getDefaultCommunity();
      store.dispatch(new SwitchCommunityRequested(communityAddress));
      dynamic community =
          await graph.getCommunityByAddress(communityAddress: communityAddress);
      print('community fetched for $communityAddress');
      dynamic token =
          await graph.getTokenOfCommunity(communityAddress: communityAddress);
      print('token ${token["address"]} fetched for $communityAddress');
      store.dispatch(startBalanceFetchingCall(token["address"]));
      store.dispatch(startTransfersFetchingCall(token["address"]));
      return store.dispatch(new SwitchCommunitySuccess(
          communityAddress,
          community["name"],
          new Token(address: token["address"], name: token["name"], symbol: token["symbol"], decimals: token["decimals"])));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not join community'));
    }
  };
}

ThunkAction getJoinBonusCall() {
  return (Store store) async {
    try {
      // TODO
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not get join bonus'));
    }
  };
}

ThunkAction getBusinessListCall() {
  return (Store store) async {
    try {
      // TODO
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not get business list'));
    }
  };
}

ThunkAction getTokenTransfersListCall(String tokenAddress) {
  return (Store store) async {
    try {
      String walletAddress = store.state.cashWalletState.walletAddress;
      print('fetching token transfers of $tokenAddress for $walletAddress wallet');
      Map<String, dynamic> response =
          await graph.getTransfers(walletAddress, tokenAddress);
      List<Transfer> transfers = List<Transfer>.from(response["data"].map((json) => Transfer.fromJson(json)).toList());
      store.dispatch(new GetTokenTransfersListSuccess(transfers));
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not get token transfers'));
    }
  };
}

ThunkAction sendTokenToContactCall(
    String contactPhoneNumber, num tokensAmount) {
  return (Store store) async {
    try {
      dynamic wallet = await api.getWalletByPhoneNumber(contactPhoneNumber);
      String walletAddress = wallet["walletAddress"];
      if (walletAddress == null || walletAddress.isEmpty) {
        store.dispatch(new ErrorState('Could not find wallet for contact'));
      } else {
        store.dispatch(sendTokenCall(walletAddress, tokensAmount));
      }
    } catch (e) {
      print(e);
      store.dispatch(new ErrorAction('Could not send token to contact'));
    }
  };
}
