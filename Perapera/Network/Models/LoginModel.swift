//
//  LoginModel.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import HandyJSON

class LoginModel: HandyJSON, ResponseStatusable {
    var access_token: String = ""
    var token_type: String = ""
    var statusCode: Int?
    
    required init() {}
}

class UserInfoModel: HandyJSON {
    var email: String = ""
    var username: String = ""
    var uuid: String = ""
    var is_active: Bool = false
    var created_at: String = ""
    var annual_expire_at: String?
    var monthly_expire_at: String?
    var point_card_minutes: Int = 0
    var monthly_card_minutes: Int = 0
    
    required init() {}

    var resolvedProExpirationDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        let dates = [annual_expire_at, monthly_expire_at]
            .compactMap { $0 }
            .compactMap { raw in
                formatter.date(from: raw) ?? fallbackFormatter.date(from: raw)
            }

        return dates.max()
    }

    var hasActivePro: Bool {
        guard let expiration = resolvedProExpirationDate else { return false }
        return expiration > Date()
    }

    /// Returns the currently active Pro plan type: "Yearly" (年卡) or "Monthly" (月卡).
    /// Yearly takes priority when both are still valid.
    var activeProPlanType: String? {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        func parse(_ raw: String?) -> Date? {
            guard let raw = raw, !raw.isEmpty else { return nil }
            return formatter.date(from: raw) ?? fallbackFormatter.date(from: raw)
        }

        if let annual = parse(annual_expire_at), annual > now {
            return "Yearly"
        }
        if let monthly = parse(monthly_expire_at), monthly > now {
            return "Monthly"
        }
        return nil
    }

    func remainingProTimeDescription(referenceDate: Date = Date()) -> String? {
        guard let expiration = resolvedProExpirationDate, expiration > referenceDate else {
            return nil
        }

        let remaining = Int(expiration.timeIntervalSince(referenceDate))
        let days = remaining / 86400
        let hours = (remaining % 86400) / 3600
        let minutes = (remaining % 3600) / 60

        if days > 0 {
            return "\(days)天\(hours)小时"
        }
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(max(minutes, 1))分钟"
    }

    /// 分钟数展示规则：
    /// - 满 1 小时：仅显示剩余小时数（例如 1740 -> 29 小时）
    /// - 不满 1 小时：显示具体分钟数（例如 45 -> 45 分钟）
    private func formattedRemainingMinutes(_ minutes: Int) -> String {
        let normalizedMinutes = max(minutes, 0)
        if normalizedMinutes >= 60 {
            return String(format: "%d hr".localized(), normalizedMinutes / 60)
        }
        return String(format: "%d min".localized(), normalizedMinutes)
    }

    var currentMonthRemainingDescription: String {
        if monthly_card_minutes > 0 {
            return "Current month remaining".localized() + " " + formattedRemainingMinutes(monthly_card_minutes)
        }
        return "Point card remaining".localized() + " " + formattedRemainingMinutes(point_card_minutes)
    }
}
