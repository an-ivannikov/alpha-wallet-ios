import Foundation
import UIKit
import StatefulViewController
import Result
import TrustKeystore

protocol AlphaWalletTokensViewControllerDelegate: class {
    func didPressAddToken( in viewController: UIViewController)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didDelete(token: TokenObject, in viewController: UIViewController)
}

//Duplicated from TokensViewController.swift for easier upstream merging
class AlphaWalletTokensViewController: UIViewController {

    private let dataStore: AlphaWalletTokensDataStore

    var viewModel: AlphaWalletTokensViewModel = AlphaWalletTokensViewModel(tokens: [], tickers: .none) {
        didSet {
            refreshView(viewModel: viewModel)
        }
    }
    let account: Wallet
	let filterView = AlphaWalletFilterView()
    var importWalletView: UIView?
    var importWalletLayer = CAShapeLayer()
    let tableView: UITableView
    let refreshControl = UIRefreshControl()
    weak var delegate: AlphaWalletTokensViewControllerDelegate?

    init(
        account: Wallet,
        dataStore: AlphaWalletTokensDataStore
    ) {
        self.account = account
        self.dataStore = dataStore
        tableView = UITableView(frame: .zero, style: .plain)
        super.init(nibName: nil, bundle: nil)
        dataStore.delegate = self

        view.backgroundColor = Colors.appBackground

        filterView.delegate = self
        filterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterView)

        tableView.register(AlphaWalletTokenViewCell.self, forCellReuseIdentifier: AlphaWalletTokenViewCell.identifier)
        tableView.register(AlphaWalletTicketTokenViewCell.self, forCellReuseIdentifier: AlphaWalletTicketTokenViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            filterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterView.topAnchor.constraint(equalTo: view.topAnchor),
            filterView.bottomAnchor.constraint(equalTo: tableView.topAnchor),

            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.dataStore.fetch()
        })
        loadingView = LoadingView()
        emptyView = EmptyView(
            title: NSLocalizedString("emptyView.noTokens.label.title", value: "You haven't received any tokens yet!", comment: ""),
            onRetry: { [weak self] in
                self?.startLoading()
                self?.dataStore.fetch()
        })
        refreshView(viewModel: viewModel)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.applyTintAdjustment()
        fetch()
    }
    @objc func pullToRefresh() {
        refreshControl.beginRefreshing()
        fetch()
    }

    func fetch() {
        self.startLoading()
        self.dataStore.fetch()
    }

    override func viewDidLayoutSubviews() {
        if let importWalletView = importWalletView {
            importWalletLayer.frame = importWalletView.bounds
            importWalletLayer.path = createImportWalletImagePath().cgPath
        }
    }

    private func reload() {
        tableView.reloadData()
        let haveData = viewModel.numberOfSections > 0 && viewModel.numberOfItems(for: 0) > 0
        if haveData {
            hideImportWalletImage()
        } else {
            showImportWalletImage()
        }
    }

    private func hideImportWalletImage() {
        importWalletView?.isHidden = true
    }

    private func showImportWalletImage() {
        if let importWalletView = importWalletView {
            importWalletView.isHidden = false
            return
        }
        importWalletView = UIView()
        if let importWalletView = importWalletView {
            view.addSubview(importWalletView)

            let imageView = UIImageView(image: R.image.wallet_import())

            importWalletLayer.path = createImportWalletImagePath().cgPath
            importWalletLayer.lineDashPattern = [5, 5]
            importWalletLayer.strokeColor = UIColor.white.cgColor
            importWalletLayer.fillColor = UIColor.clear.cgColor
            importWalletView.layer.addSublayer(importWalletLayer)

            let label = UILabel()
            label.textColor = .white
            label.text = R.string.localizable.aWalletImportWalletTitle()

            let stackView = UIStackView(arrangedSubviews: [
                imageView,
                label,
            ])
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.axis = .vertical
            stackView.alignment = .center
            stackView.spacing = 10
            importWalletView.addSubview(stackView)

            let sideMargin = CGFloat(7)
            importWalletView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                importWalletView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                importWalletView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                importWalletView.topAnchor.constraint(equalTo: view.topAnchor, constant: 52),
                importWalletView.heightAnchor.constraint(equalToConstant: 138),

                stackView.centerXAnchor.constraint(equalTo: importWalletView.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: importWalletView.centerYAnchor),
            ])
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshView(viewModel: AlphaWalletTokensViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
    }

    @objc func missingToken() {
        delegate?.didPressAddToken(in: self)
    }

    private func createImportWalletImagePath() -> UIBezierPath {
        if let importWalletView = importWalletView {
            let path = UIBezierPath(roundedRect: importWalletView.bounds, cornerRadius: 7)
            return path
        } else {
            return UIBezierPath()
        }
    }
}

extension AlphaWalletTokensViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.hasContent
    }
}

extension AlphaWalletTokensViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        delegate?.didSelect(token: token, in: self)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return viewModel.canDelete(for: indexPath.row, section: indexPath.section)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            delegate?.didDelete(token: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)

        if token.isStormBird {
            let cellViewModel = AlphaWalletTicketTokenViewCellViewModel(
                    token: token,
                    ticker: viewModel.ticker(for: token)
            )
            return cellViewModel.cellHeight
        } else {
            let cellViewModel = AlphaWalletTokenViewCellViewModel(
                    token: token,
                    ticker: viewModel.ticker(for: token)
            )
            return cellViewModel.cellHeight
        }
    }
}

extension AlphaWalletTokensViewController: AlphaWalletTokensDataStoreDelegate {
    func didUpdate(result: Result<AlphaWalletTokensViewModel, TokenError>) {
        switch result {
        case .success(let viewModel):
            self.viewModel = viewModel
            endLoading()
        case .failure(let error):
            endLoading(error: error)
        }
        reload()

        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
    }
}

extension AlphaWalletTokensViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)

        if token.isStormBird {
            let cell = tableView.dequeueReusableCell(withIdentifier: AlphaWalletTicketTokenViewCell.identifier, for: indexPath) as! AlphaWalletTicketTokenViewCell
            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token)
                    )
            )
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: AlphaWalletTokenViewCell.identifier, for: indexPath) as! AlphaWalletTokenViewCell
            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token)
                    )
            )
            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }
}

extension AlphaWalletTokensViewController: AlphaWalletFilterViewDelegate {
    func didPressWalletFilter(filter: AlphaWalletFilter, in filterView: AlphaWalletFilterView) {
        viewModel.filter = filter
        reload()
    }
}