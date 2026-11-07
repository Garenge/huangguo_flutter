import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    if let window = window, privacyCover == nil {
      let cover = UIView(frame: window.bounds)
      cover.backgroundColor = UIColor(red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1)
      cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      let label = UILabel(frame: cover.bounds)
      label.text = "Flutter Demo"
      label.textColor = .white
      label.textAlignment = .center
      label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      cover.addSubview(label)
      window.addSubview(cover)
      privacyCover = cover
    }
    super.sceneWillResignActive(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    DispatchQueue.main.async { [weak self] in
      self?.privacyCover?.removeFromSuperview()
      self?.privacyCover = nil
    }
  }
}
