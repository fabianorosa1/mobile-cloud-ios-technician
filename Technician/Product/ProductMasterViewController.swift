//
// ProductMasterViewController.swift
// Technician
//
// Created by SAP Cloud Platform SDK for iOS Assistant application on 04/07/18
//

import Foundation
import SAPCommon
import SAPFiori
import SAPFoundation
import SAPOData
import SAPOfflineOData

class ProductMasterViewController: FUIFormTableViewController, SAPFioriLoadingIndicator {
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var espmContainer: ESPMContainer<OfflineODataProvider> {
        return self.appDelegate.espmContainer
    }

    public var loadEntitiesBlock: ((_ completionHandler: @escaping ([Product]?, Error?) -> Void) -> Void)?
    private var entities: [Product] = [Product]()
    private var entityImages = [Int: UIImage]()
    private let logger = Logger.shared(named: "ProductMasterViewControllerLogger")
    private let okTitle = NSLocalizedString("keyOkButtonTitle",
                                            value: "OK",
                                            comment: "XBUT: Title of OK button.")
    var loadingIndicator: FUILoadingIndicatorView?
    var entitySetName: String?
    var kpiHeader : FUIKPIHeader?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        // Add refreshcontrol UI
        self.refreshControl?.addTarget(self, action: #selector(self.refresh), for: UIControlEvents.valueChanged)
        self.tableView.addSubview(self.refreshControl!)
        // Cell height settings
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 98
        self.updateTable()
        
        initUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func initUI() {
        self.kpiHeader = UIFunctionsHelper.getEmptyCompletedSalesOrdersChart()
        self.tableView.tableHeaderView = self.kpiHeader
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIFunctionsHelper.updateSalesOrderChart(appDelegate: appDelegate, logger: self.logger, completedKPIChart: self.kpiHeader?.items[0] as! FUIKPIProgressView)
    }

    // MARK: - Table view data source

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return self.entities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let product = self.entities[indexPath.row]
        let cell = CellCreationHelper.objectCellWithNonEditableContent(tableView: tableView, indexPath: indexPath, key: product.productID ?? "", value: product.name ?? "" )
        
        return cell
    }

    // MARK: - Data accessing

    func requestEntities(completionHandler: @escaping (Error?) -> Void) {
        self.loadEntitiesBlock!() { entities, error in
            if let error = error {
                completionHandler(error)
                return
            }
            self.entities = entities!
            completionHandler(nil)
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "showDetail" {
            // Show the selected Entity on the Detail view
            guard let indexPath = self.tableView.indexPathForSelectedRow else {
                return
            }
            self.logger.info("Showing details of the chosen element.")
            let selectedEntity = self.entities[indexPath.row]
            let detailViewController = segue.destination as! ProductDetailViewController
            detailViewController.entity = selectedEntity
            detailViewController.navigationItem.leftItemsSupplementBackButton = true
            detailViewController.navigationItem.title = self.entities[(self.tableView.indexPathForSelectedRow?.row)!].productID ?? ""
            detailViewController.tableUpdater = self
            detailViewController.entitySetName = self.entitySetName
        }
    }

    // MARK: - Table update

    func updateTable() {
        self.showFioriLoadingIndicator()
        let oq = OperationQueue()
        oq.addOperation({
            self.loadData {
                self.hideFioriLoadingIndicator()
            }
        })
    }

    private func loadData(completionHandler: @escaping () -> Void) {
        self.requestEntities { error in
            defer {
                completionHandler()
            }
            if let error = error {
                let alertController = UIAlertController(title: NSLocalizedString("keyErrorLoadingData", value: "Loading data failed!", comment: "XTIT: Title of loading data error pop up."), message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: self.okTitle, style: .default))
                OperationQueue.main.addOperation({
                    // Present the alertController
                    self.present(alertController, animated: true)
                })
                self.logger.error("Could not update table. Error: \(error)", error: error)
                return
            }
            OperationQueue.main.addOperation({
                self.tableView.reloadData()
                self.logger.info("Table updated successfully!")
            })
        }
    }

    @objc func refresh() {
        let oq = OperationQueue()
        oq.addOperation({
            self.loadData {
                OperationQueue.main.addOperation({
                    self.refreshControl?.endRefreshing()
                })
            }
        })
    }
}

extension ProductMasterViewController: EntitySetUpdaterDelegate {
    func entitySetHasChanged() {
        self.updateTable()
    }
}
