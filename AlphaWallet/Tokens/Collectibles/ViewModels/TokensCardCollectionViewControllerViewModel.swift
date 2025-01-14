//
//  TokensCardCollectionViewControllerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import BigInt

struct TokensCardCollectionViewControllerViewModel {

    var fungibleBalance: BigInt? {
        return nil
    }

    private let assetDefinitionStore: AssetDefinitionStore
    let token: TokenObject
    var tokenHolders: [TokenHolder]
    var actions: [TokenInstanceAction] {
        //NOTE: Show actions only in case when there is only one token id in list, othervise user is able to select each toke to perform an action
        guard numberOfItems() == 1 else { return [] }

        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if actionsFromTokenScript.isEmpty {
            switch token.type {
            case .erc875, .erc721ForTickets:
                return [
                    .init(type: .nftSell),
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc721, .erc1155:
                return [
                    .init(type: .nonFungibleTransfer)
                ]
            case .nativeCryptocurrency, .erc20:
                return []
            }
        } else {
            return actionsFromTokenScript
        }
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var navigationTitle: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }
    private let account: Wallet
    private let eventsDataStore: EventsDataStoreProtocol

    init(token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        self.account = account
        self.eventsDataStore = eventsDataStore
        self.tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: account)
        self.assetDefinitionStore = assetDefinitionStore
    }

    func tokenHolder(at indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.section]
    }

    func numberOfItems() -> Int {
        return tokenHolders.count
    }

    mutating func invalidateTokenHolders() {
        tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
            .getTokenHolders(forWallet: account)
    }

}
