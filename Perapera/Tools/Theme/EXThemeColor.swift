//
//  EXThemeColor.swift
//  Perapera
//
//  Adapted for Perapera
//

import UIKit
import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .system: return "settings_theme_system".localized()
        case .light: return "settings_theme_light".localized()
        case .dark: return "settings_theme_dark".localized()
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Models

private struct ThemeColorDefinition: Codable {
    let name: String
    let color: String?
    let colors: [String]?
    let redirect: String?
    let alpha: String?
    let category: String?
    let desc: String?
    let version: String?
}

// MARK: - Theme Store

private class ThemeStore {
    static let shared = ThemeStore()
    
    private var lightColors: [String: ThemeColorDefinition] = [:]
    private var darkColors: [String: ThemeColorDefinition] = [:]
    
    private init() {
        loadColors()
    }
    
    private func loadColors() {
        lightColors = loadJSON("EXThemeColorLight.json")
        darkColors = loadJSON("EXThemeColorDark.json")
    }
    
    private func loadJSON(_ filename: String) -> [String: ThemeColorDefinition] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) ??
                        Bundle.main.url(forResource: filename.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            print("[ThemeStore] Warning: Could not find \(filename) in main bundle.")
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([ThemeColorDefinition].self, from: data)
            return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
        } catch {
            print("[ThemeStore] Error loading \(filename): \(error)")
            return [:]
        }
    }
    
    func uiColor(named name: String, isDark: Bool) -> UIColor {
        let map = isDark ? darkColors : lightColors
        return resolveColor(named: name, in: map, isDark: isDark)
    }
    
    private func resolveColor(named name: String, in map: [String: ThemeColorDefinition], isDark: Bool, visited: Set<String> = []) -> UIColor {
        if visited.contains(name) {
            print("[ThemeStore] Circular redirect detected for \(name)")
            return .clear
        }
        
        guard let definition = map[name] else {
            return .clear
        }
        
        if let redirect = definition.redirect {
            var newVisited = visited
            newVisited.insert(name)
            return resolveColor(named: redirect, in: map, isDark: isDark, visited: newVisited)
        }
        
        if let hex = definition.color {
            let color = UIColor(hex: hex)
            if let alphaString = definition.alpha, let alpha = Double(alphaString) {
                return color.withAlphaComponent(CGFloat(alpha))
            }
            return color
        }
        
        if let colors = definition.colors, let first = colors.first {
             return UIColor(hex: first)
        }
        
        return .clear
    }
    
    func gradient(named name: String, isDark: Bool) -> [Color] {
        let map = isDark ? darkColors : lightColors
        guard let definition = map[name] else { return [] }
        
        if let colors = definition.colors {
            return colors.map { Color(UIColor(hex: $0)) }
        }
        
        if let redirect = definition.redirect {
            return gradient(named: redirect, isDark: isDark)
        }
        
        if definition.color != nil {
            return [Color(uiColor(named: name, isDark: isDark))]
        }
        
        return []
    }
}

// MARK: - Extensions

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(white: 0, alpha: 0)
            return
        }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            a = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            r = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
             self.init(white: 0, alpha: 0)
             return
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    static func ex(_ name: String) -> Color {
        Color(UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            return ThemeStore.shared.uiColor(named: name, isDark: isDark)
        })
    }
    
    static func exGradient(_ name: String, scheme: ColorScheme) -> [Color] {
        return ThemeStore.shared.gradient(named: name, isDark: scheme == .dark)
    }
}

// MARK: - Adaptation Helpers
private struct EXThemeAdaptor {
    static var isKLineTrendReversed: Bool = false
}

public extension UIColor {
    enum Ex: Int, CaseIterable, Codable {
        /// Module of global
        case global
        /// Module of kLine
        case kLine
        
        /// In Perapera, we default to system appearance, but this structure is kept for compatibility.
        public var color: Color {
            // For now, return .unspecified to follow system
            return .unspecified
        }
        
        public var isDark: Bool { color.isDark }
        public static var isDark: Bool { global.isDark }
    }
}

public extension UIColor.Ex {
    
    static var ai_bg: UIColor { global.ai_bg }
    var ai_bg: UIColor { named(.ai_bg) }
    

    static var buttonTitle: UIColor { global.buttonTitle }
    var buttonTitle: UIColor { named(.buttonTitle) }

    static var tabbar_bg: UIColor { global.tabbar_bg }
    var tabbar_bg: UIColor { named(.tabbar_bg) }

    static var bg1: UIColor { global.bg1 }
    var bg1: UIColor { named(.bg1) }

    static var bg2: UIColor { global.bg2 }
    var bg2: UIColor { named(.bg2) }

    static var bg3: UIColor { global.bg3 }
    var bg3: UIColor { named(.bg3) }

    static var bg4: UIColor { global.bg4 }
    var bg4: UIColor { named(.bg4) }
    
    static var homepagebg: UIColor { global.homepagebg }
    var homepagebg: UIColor { named(.homepagebg)}
    
    static var fill1: UIColor { global.fill1 }
    var fill1: UIColor { named(.fill1) }

    static var toast_shadow: UIColor { global.toast_shadow }
    var toast_shadow: UIColor { named(.toast_shadow) }


    static var toast_bg: UIColor { global.toast_bg }
    var toast_bg: UIColor { named(.toast_bg) }


    /// 背景灰色
    ///
    /// 类别:填充色Fill
    static var secondaryG100: UIColor { global.secondaryG100 }
    var secondaryG100: UIColor { named(.secondaryG100) }
    
    static var secondaryG80: UIColor { global.secondaryG80 }
    var secondaryG80: UIColor { named(.secondaryG80) }
    
    
    static var secondaryG50: UIColor { global.secondaryG50 }
    var secondaryG50: UIColor { named(.secondaryG50) }
    
    /// 卡片色一
    ///
    /// 类别:填充色Fill
    static var fill2: UIColor { global.fill2 }
    var fill2: UIColor { named(.fill2) }
    
    /// 卡片色二
    ///
    /// 类别:填充色Fill
    static var fill3: UIColor { global.fill3 }
    var fill3: UIColor { named(.fill3) }
    
    /// 间隔色
    ///
    /// 类别:填充色Fill
    static var fill4: UIColor { global.fill4 }
    var fill4: UIColor { named(.fill4) }
    
    /// 二级按钮点击色
    ///
    /// 类别:填充色Fill
    static var fill5: UIColor { global.fill5 }
    var fill5: UIColor { named(.fill5) }
    
    /// 弹窗背景
    ///
    /// 类别:填充色Fill
    static var fill6: UIColor { global.fill6 }
    var fill6: UIColor { named(.fill6) }
    
    /// 黑色遮罩色
    ///
    /// 类别:填充色Fill
    static var fill7: UIColor { global.fill7 }
    var fill7: UIColor { named(.fill7) }
    
    /// Toast提示背景色
    ///
    /// 类别:填充色Fill
    static var fill8: UIColor { global.fill8 }
    var fill8: UIColor { named(.fill8) }
    
    /// 标签背景色
    ///
    /// 类别:填充色Fill
    static var fill9: UIColor { global.fill9 }
    var fill9: UIColor { named(.fill9) }
    /// 标签背景色
    ///
    /// 类别:填充色Fill
    static var fill10: UIColor { global.fill10 }
    var fill10: UIColor { named(.fill10) }
    
    static var fill11: UIColor { global.fill11 }
    var fill11: UIColor { named(.fill11) }
    
    static var fill12: UIColor { global.fill12 }
    var fill12: UIColor { named(.fill12) }

    static var fill13: UIColor { global.fill13 }
    var fill13: UIColor { named(.fill13) }

    static var fill14: UIColor { global.fill14 }
    var fill14: UIColor { named(.fill14) }
    
    
    /// 一级颜色
    ///
    /// 类别:文字色Text
    static var text1: UIColor { global.text1 }
    var text1: UIColor { named(.text1) }
    
    /// 二级颜色
    ///
    /// 类别:文字色Text
    static var text2: UIColor { global.text2 }
    var text2: UIColor { named(.text2) }
    
    /// 三级颜色
    ///
    /// 类别:文字色Text
    static var text3: UIColor { global.text3 }
    var text3: UIColor { named(.text3) }
    
    /// 四级颜色
    ///
    /// 类别:文字色Text
    static var text4: UIColor { global.text4 }
    var text4: UIColor { named(.text4) }
    
    /// 五级颜色
    ///
    /// 类别:文字色Text
    static var text5: UIColor { global.text5 }
    var text5: UIColor { named(.text5) }
    
    static var textStateSuccess1: UIColor { global.textStateSuccess1 }
    var textStateSuccess1: UIColor { named(.textStateSuccess1) }
    
    /// 背景色
    ///
    /// 类别:特殊色Special
    static var special1: UIColor { global.special1 }
    var special1: UIColor { named(.special1) }
    
    /// 背景色
    ///
    /// 类别:特殊色Special
    static var special2: UIColor { global.special2 }
    var special2: UIColor { named(.special2) }
    
    /// 卡片色一
    ///
    /// 类别:特殊色Special
    static var special3: UIColor { global.special3 }
    var special3: UIColor { named(.special3) }
    
    /// 类别:特殊色Special
    static var special4: UIColor { global.special4 }
    var special4: UIColor { named(.special4) }
    
    /// 蓝色常规
    ///
    /// 类别:主色
    ///

    static var main: UIColor { global.main }
    var main: UIColor { named(.main) }
    
    
    static var main1: UIColor { global.main1 }
    var main1: UIColor { named(.main1) }
    
    /// 按钮点击
    ///
    /// 类别:主色
    static var main2: UIColor { global.main2 }
    var main2: UIColor { named(.main2) }
    
    /// 标签背景色
    ///
    /// 类别:主色
    static var main3: UIColor { global.main3 }
    var main3: UIColor { named(.main3) }
    
    /// 文字按钮色
    ///
    /// 类别:主色
    static var main4: UIColor { global.main4 }
    var main4: UIColor { named(.main4) }
    
    /// 上涨绿色
    ///
    /// 类别:辅助色/涨跌色
    static var rise1: UIColor { global.rise1 }
    var rise1: UIColor { named(.rise1) }
    
    /// 按钮点击
    ///
    /// 类别:辅助色/涨跌色
    static var rise2: UIColor { global.rise2 }
    var rise2: UIColor { named(.rise2) }
    
    /// 绿色图表色
    ///
    /// 类别:辅助色/涨跌色
    static var rise3: UIColor { global.rise3 }
    var rise3: UIColor { named(.rise3) }
    
    /// 下跌红色
    ///
    /// 类别:辅助色/涨跌色
    static var fall1: UIColor { global.fall1 }
    var fall1: UIColor { named(.fall1) }
    
    /// 标签背景色
    ///
    /// 类别:辅助色/涨跌色
    static var fall2: UIColor { global.fall2 }
    var fall2: UIColor { named(.fall2) }
    
    /// 红色图表色
    ///
    /// 类别:辅助色/涨跌色
    static var fall3: UIColor { global.fall3 }
    var fall3: UIColor { named(.fall3) }
    
    /// 行情列表红色
    ///
    /// 类别:辅助色/涨跌色
    static var fall4: UIColor { global.fall4 }
    var fall4: UIColor { named(.fall4) }
    
    /// 警示/提醒色
    ///
    /// 类别:辅助色/功能色
    static var warning1: UIColor { global.warning1 }
    var warning1: UIColor { named(.warning1) }
    
    /// 黄色警示图表色
    ///
    /// 类别:辅助色/功能色
    static var warning2: UIColor { global.warning2 }
    var warning2: UIColor { named(.warning2) }
    
    /// 红色错误提示
    ///
    /// 类别:辅助色/功能色
    static var error1: UIColor { global.error1 }
    var error1: UIColor { named(.error1) }
    
    /// 指标黄
    ///
    /// 类别:辅助色/K线指标色
    static var line1: UIColor { global.line1 }
    var line1: UIColor { named(.line1) }
    
    /// 指标绿
    ///
    /// 类别:辅助色/K线指标色
    static var line2: UIColor { global.line2 }
    var line2: UIColor { named(.line2) }
    
    /// 指标紫
    ///
    /// 类别:辅助色/K线指标色
    static var line3: UIColor { global.line3 }
    var line3: UIColor { named(.line3) }
    
    /// 指标红
    ///
    /// 类别:辅助色/K线指标色
    static var line4: UIColor { global.line4 }
    var line4: UIColor { named(.line4) }
    
    /// 涨
    static var up1: UIColor { global.up1 }
    var up1: UIColor { EXThemeAdaptor.isKLineTrendReversed ? fall1 : rise1 }
    ///
    static var up2: UIColor { global.up2 }
    var up2: UIColor { EXThemeAdaptor.isKLineTrendReversed ? fall2 : rise2 }
    ///
    static var up3: UIColor { global.up3 }
    var up3: UIColor { EXThemeAdaptor.isKLineTrendReversed ? fall3 : rise3 }
    
    /// 新色值  涨
    static var roseUp: UIColor { global.roseUp }
    var roseUp: UIColor { rise1 } // Simplified for now
    
    /// 跌
    static var down1: UIColor { global.down1 }
    var down1: UIColor { EXThemeAdaptor.isKLineTrendReversed ? rise1 : fall1 }
    ///
    static var down2: UIColor { global.down2 }
    var down2: UIColor { EXThemeAdaptor.isKLineTrendReversed ? rise2 : fall2 }
    ///
    static var down3: UIColor { global.down3 }
    var down3: UIColor { EXThemeAdaptor.isKLineTrendReversed ? rise3 : fall3 }
    
    /// 新色值  跌
    static var roseDown: UIColor { global.roseDown }
    var roseDown: UIColor { fall4 } // Simplified for now
    
    static var  masksegmentbg : UIColor { global.masksegmentbg }
    var masksegmentbg : UIColor { named(.masksegmentbg) }
    
    ///
    static var kLineTrendReversed: Bool { EXThemeAdaptor.isKLineTrendReversed }
    
    static var secondaryWhite : UIColor { global.secondaryWhite }
    var secondaryWhite : UIColor { named(.secondaryWhite) }
    
    static var morebuttonborderColor : UIColor { global.morebuttonborderColor }
    var morebuttonborderColor : UIColor { named(.morebuttonborderColor) }
}

public extension UIColor.Ex {
    ///
    enum Color : Int, CaseIterable, Codable {
        case unspecified = 0
        case light = 1
        case dark = 2
        
        public var isDark: Bool {
            switch self {
            case .dark: return true
            case .light: return false
            case .unspecified:
                // Use system trait collection
                return UITraitCollection.current.userInterfaceStyle == .dark
            }
        }
        
        ///
        public var resolved: Self {
            switch self {
                case .unspecified:
                    return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
                case .light,.dark:
                    return self
            }
        }
        ///
        public static var allCases: [Self] = [.light, .dark]
    }
}

extension UIColor.Ex.Color {
    public static var global: Self { UIColor.Ex.global.color }
    public static var kLine : Self { UIColor.Ex.kLine.color }
}

extension UIColor.Ex {
    
    /// Get color with the specified name and color
    public static func named(_ name:String, color:Color? = nil) -> UIColor {
        return global.named(name, color: color)
    }
    
    public func named(_ name:String, color:Color? = nil) -> UIColor {
        let targetIsDark = (color ?? self.color).isDark
        return ThemeStore.shared.uiColor(named: name, isDark: targetIsDark)
    }
    
    /// Get colors with the specified name, used for gradient views always.
    public static func named(_ name:String, color:Color? = nil) -> [UIColor]? {
        return global.named(name, color: color)
    }
    
    public func named(_ name:String, color:Color? = nil) -> [UIColor]? {
        let targetIsDark = (color ?? self.color).isDark
        let swiftUIColors = ThemeStore.shared.gradient(named: name, isDark: targetIsDark)
        if swiftUIColors.isEmpty { return nil }
        return swiftUIColors.map { UIColor($0) }
    }
}

extension UIColor.Ex {
    /// default colors
    public var defaultColors: [UIColor] { named(.default) ?? [] }
    public static var defaultColors: [UIColor] { global.defaultColors }
    
    // skeleton
    public var skeleton: [UIColor] { named(.skeleton)! }
    public static var skeleton: [UIColor] { global.skeleton }
    
    public var marketAi: [UIColor] { named(.marketAi)! }
    public static var marketAi: [UIColor] { global.marketAi }
    
    public var marketAi2: [UIColor] { named(.marketAi2)! }
    public static var marketAi2: [UIColor] { global.marketAi2 }

    /// The default color, resolved to white
    fileprivate static let resolved:UIColor = .white
}

extension UIColor.Ex {
    public struct Name {
        ///
        public enum Color:String {
            case bg1
            case bg2
            case bg3
            case bg4
            case homepagebg
            case fill1
            case fill2
            case fill3
            case fill4
            case fill5
            case fill6
            case fill7
            case fill8
            case fill9
            case fill10
            case fill11
            case fill12
            case fill13
            case fill14
            case text1
            case text2
            case text3
            case text4
            case text5
            case textStateSuccess1
            case buttonTitle
            case special1
            case special2
            case special3
            case special4
            case secondaryG100
            case secondaryG80
            case secondaryG50
            case main
            case main1
            case main2
            case main3
            case main4
            case rise1
            case rise2
            case rise3
            case fall1
            case fall2
            case fall3
            case fall4
            case warning1
            case warning2
            case error1
            case line1
            case line2
            case line3
            case line4
            case masksegmentbg
            case secondaryWhite
            case morebuttonborderColor
            case tabbar_bg
            case ai_bg
            case toast_shadow
            case toast_bg

        }
        ///
        public enum Colors:String {
            case `default` = "gradient.default"
            case skeleton  = "gradient.skeleton"
            case marketAi  = "gradient.marketAi"
            case marketAi2  = "gradient.marketAi2"
        }
    }
    ///
    public func named(_ name:Name.Color, color:Color? = nil) -> UIColor {
        named(name.rawValue, color: color)
    }
    ///
    public static func named(_ name:Name.Color, color:Color? = nil) -> UIColor {
        return named(name.rawValue, color: color)
    }
    ///
    public func named(_ name:Name.Colors, color:Color? = nil) -> [UIColor]? {
        named(name.rawValue, color: color)
    }
    ///
    public static func named(_ name:Name.Colors, color:Color? = nil) -> [UIColor]? {
        named(name.rawValue, color: color)
    }
}

// MARK: - SwiftUI Color Support

public extension Color {
    struct Ex {
        public static var ai_bg: Color { Color.ex("ai_bg") }
        public static var buttonTitle: Color { Color.ex("buttonTitle") }
        public static var tabbar_bg: Color { Color.ex("tabbar_bg") }
        
        public static var bg1: Color { Color.ex("bg1") }
        public static var bg2: Color { Color.ex("bg2") }
        public static var bg3: Color { Color.ex("bg3") }
        public static var bg4: Color { Color.ex("bg4") }
        
        public static var homepagebg: Color { Color.ex("homepagebg") }
        
        public static var fill1: Color { Color.ex("fill1") }
        public static var fill2: Color { Color.ex("fill2") }
        public static var fill3: Color { Color.ex("fill3") }
        public static var fill4: Color { Color.ex("fill4") }
        public static var fill5: Color { Color.ex("fill5") }
        public static var fill6: Color { Color.ex("fill6") }
        public static var fill7: Color { Color.ex("fill7") }
        public static var fill8: Color { Color.ex("fill8") }
        public static var fill9: Color { Color.ex("fill9") }
        public static var fill10: Color { Color.ex("fill10") }
        public static var fill11: Color { Color.ex("fill11") }
        public static var fill12: Color { Color.ex("fill12") }
        public static var fill13: Color { Color.ex("fill13") }
        public static var fill14: Color { Color.ex("fill14") }
        
        public static var toast_shadow: Color { Color.ex("toast_shadow") }
        public static var toast_bg: Color { Color.ex("toast_bg") }
        
        public static var secondaryG100: Color { Color.ex("secondaryG100") }
        public static var secondaryG80: Color { Color.ex("secondaryG80") }
        public static var secondaryG50: Color { Color.ex("secondaryG50") }
        
        public static var special1: Color { Color.ex("special1") }
        public static var special2: Color { Color.ex("special2") }
        public static var special3: Color { Color.ex("special3") }
        public static var special4: Color { Color.ex("special4") }
        
        public static var main : Color { Color.ex("main")  }
        public static var main1: Color { Color.ex("main1") }
        public static var main2: Color { Color.ex("main2") }
        public static var main3: Color { Color.ex("main3") }
        public static var main4: Color { Color.ex("main4") }
        
        public static var rise1: Color { Color.ex("rise1") }
        public static var rise2: Color { Color.ex("rise2") }
        public static var rise3: Color { Color.ex("rise3") }
        
        public static var fall1: Color { Color.ex("fall1") }
        public static var fall2: Color { Color.ex("fall2") }
        public static var fall3: Color { Color.ex("fall3") }
        public static var fall4: Color { Color.ex("fall4") }
        
        public static var warning1: Color { Color.ex("warning1") }
        public static var warning2: Color { Color.ex("warning2") }
        public static var error1: Color { Color.ex("error1") }
        
        public static var line1: Color { Color.ex("line1") }
        public static var line2: Color { Color.ex("line2") }
        public static var line3: Color { Color.ex("line3") }
        public static var line4: Color { Color.ex("line4") }
        
        public static var up1: Color { EXThemeAdaptor.isKLineTrendReversed ? fall1 : rise1 }
        public static var up2: Color { EXThemeAdaptor.isKLineTrendReversed ? fall2 : rise2 }
        public static var up3: Color { EXThemeAdaptor.isKLineTrendReversed ? fall3 : rise3 }
        
        public static var roseUp: Color { rise1 }
        
        public static var down1: Color { EXThemeAdaptor.isKLineTrendReversed ? rise1 : fall1 }
        public static var down2: Color { EXThemeAdaptor.isKLineTrendReversed ? rise2 : fall2 }
        public static var down3: Color { EXThemeAdaptor.isKLineTrendReversed ? rise3 : fall3 }
        
        public static var roseDown: Color { fall4 }
        
        public static var masksegmentbg: Color { Color.ex("masksegmentbg") }
        public static var secondaryWhite: Color { Color.ex("secondaryWhite") }
        public static var morebuttonborderColor: Color { Color.ex("morebuttonborderColor") }
        
        public static var text1: Color { Color.ex("text1") }
        public static var text2: Color { Color.ex("text2") }
        public static var text3: Color { Color.ex("text3") }
        public static var text4: Color { Color.ex("text4") }
        public static var text5: Color { Color.ex("text5") }
        public static var textStateSuccess1: Color { Color.ex("textStateSuccess1") }
        
        public static func skeleton(scheme: ColorScheme) -> [Color] { Color.exGradient("gradient.skeleton", scheme: scheme) }
        public static func marketAi(scheme: ColorScheme) -> [Color] { Color.exGradient("gradient.marketAi", scheme: scheme) }
        public static func marketAi2(scheme: ColorScheme) -> [Color] { Color.exGradient("gradient.marketAi2", scheme: scheme) }
    }
    
    // Allow Color.ex.bg1 syntax (lowercase ex property returning Ex.Type)
    static var ex: Ex.Type { Ex.self }
}
