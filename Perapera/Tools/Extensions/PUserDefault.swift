import Foundation
import UIKit

open class PUserDefault: NSObject {
    public class func getCoinIcon(coin: String) -> UIImage? {
        guard let imgDict = PUserDefault.getVauleForKey(key: "kCoinImageKeyValues") as? [String: Data] else { return nil }
        if let imageData = imgDict[coin] {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    public class func setCoinIcon(coin: String, image: UIImage) {
        if let imgData = image.pngData() {
            var imgDict = PUserDefault.getVauleForKey(key: "kCoinImageKeyValues") as? [String: Data]
            if imgDict != nil {
                imgDict![coin] = imgData
            } else {
                imgDict = [coin: imgData]
            }
            PUserDefault.setValueForKey(imgDict, key: "kCoinImageKeyValues")
        }
    }
    
    public class func setValueForKey(_ value: Any?, key: String) {
        if value == nil || value is NSNull { return }
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    public class func getVauleForKey(key: String) -> Any {
        return UserDefaults.standard.object(forKey: key) ?? ""
    }
    
    public class func originalVauleForKey<T>(key: String) -> T? {
        UserDefaults.standard.object(forKey: key) as? T
    }
    
    public class func removeKey(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    public class func clearAll() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
    
    public class func clearLocalLanguageDefaultsData() {
        let userDefaults = UserDefaults.standard
        let list = userDefaults.dictionaryRepresentation()
        for dic in list {
            let key = dic.key
            let prefix = "dl_"
            if key.starts(with: prefix) {
                userDefaults.removeObject(forKey: key)
                userDefaults.synchronize()
            }
        }
    }
}

