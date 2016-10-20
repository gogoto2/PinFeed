import UIKit
import MisterFusion

class TimelineViewController: UIViewController {

    @IBOutlet weak var timelineTableView: UITableView!
    
    private let refreshControl = UIRefreshControl()
    
    private let indicatorView = UIActivityIndicatorView()

    private let notificationView = UINib.instantiate(nibName: "URLNotificationView", ownerOrNil: TimelineViewController.self) as? URLNotificationView
    
    var timeline: [Bookmark] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Timeline"
        indicatorView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        indicatorView.activityIndicatorViewStyle = .gray
        view?.addSubview(indicatorView)
        timelineTableView.delegate = self
        timelineTableView.dataSource = self
        timelineTableView.register(UINib(nibName: "BookmarkCell", bundle: nil), forCellReuseIdentifier: "data")
        timelineTableView.alwaysBounceVertical = true
        timelineTableView.addSubview(refreshControl)
        timelineTableView.rowHeight = UITableViewAutomaticDimension
        timelineTableView.estimatedRowHeight = 2
        
        if let notificationView = notificationView {
            notificationView.isHidden = true
            notificationView.addTarget(self, action: #selector(didTapNotification), for: .touchUpInside)
            view?.addLayoutSubview(notificationView, andConstraints:
                notificationView.top |==| self.view.bottom |-| 103,
                notificationView.right,
                notificationView.left,
                notificationView.bottom |==| self.view.bottom |-| 49
            )
        }

        indicatorView.startAnimating()

        refresh {
            if self.indicatorView.isAnimating {
                self.indicatorView.stopAnimating()
            }

            self.refreshControl.addTarget(self, action: #selector(self.didRefresh), for: UIControlEvents.valueChanged)
        }
        
        URLNotificationManager.sharedInstance.listen(observer: self, selector: #selector(didCopyURL), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.hidesBarsOnSwipe = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func refresh(block: (() -> ())?) {
        TimelineManager.sharedInstance.fetch {
            BookmarkManager.sharedInstance.fetch {
                self.timeline = (TimelineManager.sharedInstance.timeline +
                                 BookmarkManager.sharedInstance.bookmark).sorted { a, b in
                    return a.date.compare(b.date).rawValue > 0
                }
                
                block?()

                self.timelineTableView.reloadData()
            }
        }
    }
    
    func didRefresh() {
        refresh {
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    func didCopyURL(notification: Notification?) {
        guard let url = notification?.userInfo?["url"] as? URL else {
            return
        }
        
        guard let notificationView = notificationView else {
            return
        }
        
        notificationView.isHidden = false
        notificationView.url = url
        notificationView.urlLabel.text = url.absoluteString
        if let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(url.absoluteString)") {
            DispatchQueue.global().async {
                if let faviconData = try? Data(contentsOf: faviconURL) {
                    DispatchQueue.main.async {
                        notificationView.faviconImageView?.image = UIImage(data: faviconData)
                    }
                }
            }
        }
        
        Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(didTimeoutNotification), userInfo: nil, repeats: false)
    }
    
    func didTapNotification(sender: UIControl) {
        guard let webViewController = UIStoryboard.instantiateViewController(name: "Main", identifier: "WebViewController") as? WebViewController else {
            return
        }
        
        guard let notificationView = sender as? URLNotificationView else {
            return
        }
        
        notificationView.isHidden = true
        webViewController.url = notificationView.url
        navigationController?.pushViewController(webViewController, animated: true)
    }
    
    func didTimeoutNotification() {
        notificationView?.isHidden = true
    }
}

extension TimelineViewController: UITableViewDelegate {}

extension TimelineViewController: UITableViewDataSource {
    private func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return timeline.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let data = timeline[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "data", for: indexPath) as! BookmarkCell
        cell.authorLabel?.text = data.author
        cell.dateTimeLabel?.text = data.relativeDateTime
        cell.faviconImageView?.image = nil
        if let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(data.url.absoluteString)") {
            DispatchQueue.global().async {
                if let faviconData = try? Data(contentsOf: faviconURL) {
                    DispatchQueue.main.async {
                        cell.faviconImageView?.image = UIImage(data: faviconData)
                    }
                }
            }
        }
        cell.descriptionLabel?.text = data.description
        cell.titleLabel?.text = data.title
        return cell
    }
    
    @objc(tableView:didSelectRowAtIndexPath:) func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let webViewController = UIStoryboard.instantiateViewController(name: "Main", identifier: "WebViewController") as? WebViewController else {
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: false)
        webViewController.url = timeline[indexPath.row].url
        navigationController?.pushViewController(webViewController, animated: true)
    }
}
