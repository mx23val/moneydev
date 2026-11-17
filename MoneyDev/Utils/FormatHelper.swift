import Foundation

public enum FormatHelper {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "en_US")
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        return f
    }()
    
    public static func formatCurrency(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
    
    public static func formatNumber(_ amount: Double) -> String {
        return formatCurrency(amount)
    }
}
