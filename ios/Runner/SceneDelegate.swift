import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let securityChannelName = "ph.boardmaster.app_review_center/screen_security"
  private var screenSecurityManager: IOSScreenSecurityManager?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    let methodChannel = FlutterMethodChannel(
      name: securityChannelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )

    screenSecurityManager = IOSScreenSecurityManager()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "Security manager unavailable", details: nil))
        return
      }

      switch call.method {
      case "enableSecure":
        self.screenSecurityManager?.enable(on: self.window)
        result(true)
      case "disableSecure":
        self.screenSecurityManager?.disable(on: self.window)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class IOSScreenSecurityManager: NSObject {
  private var isEnabled = false
  private weak var secureTextField: UITextField?
  private weak var overlayView: UIView?

  func enable(on window: UIWindow?) {
    guard !isEnabled else { return }
    isEnabled = true
    installSecureRendering(on: window)
    observeCaptureChanges()
    updateOverlay(on: window)
  }

  func disable(on window: UIWindow?) {
    guard isEnabled else { return }
    isEnabled = false
    removeObservers()
    removeOverlay()
    removeSecureRendering(on: window)
  }

  private func observeCaptureChanges() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func removeObservers() {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleCaptureChanged() {
    updateOverlay(on: keyWindow())
  }

  @objc private func handleAppWillResignActive() {
    guard isEnabled else { return }
    showOverlay(on: keyWindow())
  }

  @objc private func handleAppDidBecomeActive() {
    updateOverlay(on: keyWindow())
  }

  private func updateOverlay(on window: UIWindow?) {
    guard isEnabled else {
      removeOverlay()
      return
    }
    guard UIScreen.main.isCaptured else {
      removeOverlay()
      return
    }
    showOverlay(on: window)
  }

  private func showOverlay(on window: UIWindow?) {
    guard let targetWindow = window else { return }

    if let view = overlayView {
      view.frame = targetWindow.bounds
      view.isHidden = false
      targetWindow.bringSubviewToFront(view)
      return
    }

    let view = UIView(frame: targetWindow.bounds)
    view.backgroundColor = .black
    view.isUserInteractionEnabled = false
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    targetWindow.addSubview(view)
    targetWindow.bringSubviewToFront(view)
    overlayView = view
  }

  private func removeOverlay() {
    overlayView?.removeFromSuperview()
  }

  private func installSecureRendering(on window: UIWindow?) {
    guard let targetWindow = window else { return }
    guard secureTextField == nil else { return }

    let textField = UITextField(frame: .zero)
    textField.isSecureTextEntry = true
    textField.isUserInteractionEnabled = false
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.alpha = 0.01
    targetWindow.addSubview(textField)
    NSLayoutConstraint.activate([
      textField.centerXAnchor.constraint(equalTo: targetWindow.centerXAnchor),
      textField.centerYAnchor.constraint(equalTo: targetWindow.centerYAnchor),
      textField.widthAnchor.constraint(equalToConstant: 1),
      textField.heightAnchor.constraint(equalToConstant: 1),
    ])

    // This pushes the window render tree behind a secure text layer.
    if let superLayer = targetWindow.layer.superlayer,
      let secureLayer = textField.layer.sublayers?.first
    {
      superLayer.addSublayer(textField.layer)
      secureLayer.addSublayer(targetWindow.layer)
    }

    secureTextField = textField
  }

  private func removeSecureRendering(on window: UIWindow?) {
    guard let targetWindow = window else { return }
    guard let textField = secureTextField else { return }

    if let superLayer = textField.layer.superlayer {
      superLayer.addSublayer(targetWindow.layer)
    }
    textField.removeFromSuperview()
    textField.layer.removeFromSuperlayer()
    secureTextField = nil
  }

  private func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }
}
