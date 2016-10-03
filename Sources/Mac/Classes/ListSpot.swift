import Cocoa
import Brick

open class ListSpot: NSObject, Listable {

  public struct Key {
    public static let titleSeparator = "titleSeparator"
    public static let titleFontSize = "titleFontSize"
    public static let titleTopInset = "titleTopInset"
    public static let titleBottomInset = "titleBottomInset"
    public static let titleLeftInset = "titleLeftInset"
    public static let contentInsetsTop = "insetTop"
    public static let contentInsetsLeft = "insetLeft"
    public static let contentInsetsBottom = "insetBottom"
    public static let contentInsetsRight = "insetRight"
    public static let doubleAction = "doubleClick"
  }

  public struct Default {
    public static var titleSeparator: Bool = true
    public static var titleFontSize: CGFloat = 18.0
    public static var titleLeftInset: CGFloat = 0.0
    public static var titleTopInset: CGFloat = 10.0
    public static var titleBottomInset: CGFloat = 10.0
    public static var contentInsetsTop: CGFloat = 0.0
    public static var contentInsetsLeft: CGFloat = 0.0
    public static var contentInsetsBottom: CGFloat = 0.0
    public static var contentInsetsRight: CGFloat = 0.0
  }

  /// A Registry struct that contains all register components, used for resolving what UI component to use
  open static var views = Registry()
  open static var configure: ((_ view: NSTableView) -> Void)?
  open static var defaultView: View.Type = ListSpotItem.self
  open static var defaultKind: StringConvertible = Component.Kind.List.string

  open weak var spotsCompositeDelegate: SpotsCompositeDelegate?
  open weak var spotsDelegate: SpotsDelegate?

  open var cachedViews = [String : SpotConfigurable]()
  open var component: Component
  open var configure: ((SpotConfigurable) -> Void)?
  open var index = 0
  /// Indicator to calculate the height based on content
  open var usesDynamicHeight = true

  open fileprivate(set) var stateCache: SpotCache?

  open var adapter: SpotAdapter? {
    return listAdapter
  }

  fileprivate lazy var listAdapter: ListAdapter = ListAdapter(spot: self)

  open lazy var scrollView: ScrollView = {
    let scrollView = ScrollView()
    scrollView.documentView = NSView()

    return scrollView
  }()

  open lazy var titleView: NSTextField = {
    let titleView = NSTextField()
    titleView.isEditable = false
    titleView.isSelectable = false
    titleView.isBezeled = false
    titleView.textColor = NSColor.gray
    titleView.drawsBackground = false

    return titleView
  }()

  open lazy var tableView: NSTableView = {
    let tableView = NSTableView(frame: CGRect.zero)
    tableView.backgroundColor = NSColor.clear
    tableView.allowsColumnReordering = false
    tableView.allowsColumnResizing = false
    tableView.allowsColumnSelection = false
    tableView.allowsEmptySelection = true
    tableView.allowsMultipleSelection = false
    tableView.headerView = nil
    tableView.selectionHighlightStyle = .none
    tableView.allowsTypeSelect = true
    tableView.focusRingType = .none

    return tableView
  }()

  open lazy var tableColumn: NSTableColumn = {
    let column = NSTableColumn(identifier: "tableview-column")
    column.maxWidth = 250
    column.width = 250
    column.minWidth = 150

    return column
  }()

  lazy var lineView: NSView = {
    let lineView = NSView()
    lineView.frame.size.height = 1
    lineView.wantsLayer = true
    lineView.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.2).cgColor

    return lineView
  }()

  public required init(component: Component) {
    self.component = component
    super.init()

    scrollView.contentView.addSubview(tableView)
    configureLayout(component)
  }

  public convenience init(cacheKey: String) {
    let stateCache = SpotCache(key: cacheKey)

    self.init(component: Component(stateCache.load()))
    self.stateCache = stateCache
  }

  deinit {
    tableView.delegate = nil
    tableView.dataSource = nil
  }

  open func doubleAction(_ sender: Any?) {
    guard let viewModel = item(tableView.clickedRow), component.meta(Key.doubleAction, type: Bool.self) == true else { return }
    spotsDelegate?.spotDidSelectItem(self, item: viewModel)
  }

  open func action(_ sender: Any?) {
    guard let viewModel = item(tableView.clickedRow), component.meta(Key.doubleAction, false) == false else { return }
    spotsDelegate?.spotDidSelectItem(self, item: viewModel)
  }

  open func render() -> ScrollView {
    return scrollView
  }

  open func layout(_ size: CGSize) {
    scrollView.contentInsets.top = component.meta(Key.contentInsetsTop, Default.contentInsetsTop)
    scrollView.contentInsets.left = component.meta(Key.contentInsetsLeft, Default.contentInsetsLeft)
    scrollView.contentInsets.bottom = component.meta(Key.contentInsetsBottom, Default.contentInsetsBottom)
    scrollView.contentInsets.right = component.meta(Key.contentInsetsRight, Default.contentInsetsRight)

    if !component.title.isEmpty {
      configureTitleView()
    }

    tableView.sizeToFit()
    scrollView.frame.size.width = size.width
    scrollView.frame.size.height = tableView.frame.height + scrollView.contentInsets.top + scrollView.contentInsets.bottom
  }

  open func setup(_ size: CGSize) {
    component.items.enumerated().forEach {
      component.items[$0.offset].size.width = size.width
    }

    tableView.delegate = listAdapter
    tableView.dataSource = listAdapter
    tableView.target = self
    tableView.addTableColumn(tableColumn)
    tableView.action = #selector(self.action(_:))
    tableView.doubleAction = #selector(self.doubleAction(_:))
    tableView.sizeToFit()

    if !component.title.isEmpty {
      scrollView.addSubview(titleView)
      if component.meta(Key.titleSeparator, Default.titleSeparator) {
        scrollView.addSubview(lineView)
      }
      configureTitleView()
    }

    layout(size)
    ListSpot.configure?(tableView)
  }

  fileprivate func configureTitleView() {
    titleView.stringValue = component.title
    titleView.font = NSFont.systemFont(ofSize: component.meta(Key.titleFontSize, Default.titleFontSize))
    titleView.sizeToFit()
    titleView.isEnabled = false
    titleView.frame.origin.x = tableView.frame.origin.x + component.meta(Key.titleLeftInset, Default.titleLeftInset)
    scrollView.contentInsets.top += titleView.frame.size.height * 2
    titleView.frame.origin.y = titleView.frame.size.height / 2

    lineView.frame.size.width = scrollView.frame.size.width - (component.meta(Key.titleLeftInset, Default.titleLeftInset) * 2)
    lineView.frame.origin.x = component.meta(Key.titleLeftInset, Default.titleLeftInset)
    lineView.frame.origin.y = titleView.frame.maxY + 8
  }

  open func register() {
    for (identifier, item) in type(of: self).views.storage {
      switch item {
      case .classType(_): break
      case .nib(let nib):
        self.tableView.register(nib, forIdentifier: identifier)
      }
    }
  }
}
