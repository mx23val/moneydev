import Foundation
import UIKit
import SwiftUI

public enum ReportExportHelper {
    
    // MARK: - CSV Export
    
    public static func generateCsv(
        transactions: [Transaction],
        walletName: String,
        currency: String
    ) -> URL? {
        var csv = "ID,Fecha,Concepto,Categoria,Tipo,Monto,Moneda,Notas,Billetera\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        dateFormatter.locale = Locale(identifier: "es_PE")
        
        for tx in transactions {
            let date = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
            let dateStr = dateFormatter.string(from: date)
            let typeStr = tx.type == .income ? "Ingreso" : "Gasto"
            let safeTitle = tx.title.replacingOccurrences(of: ",", with: " ")
            let safeCat = tx.category.replacingOccurrences(of: ",", with: " ")
            let safeNotes = tx.notes.replacingOccurrences(of: ",", with: " ")
            let amountStr = String(format: "%.2f", tx.amount)
            
            csv += "\(tx.id),\"\(dateStr)\",\"\(safeTitle)\",\"\(safeCat)\",\"\(typeStr)\",\(amountStr),\"\(currency)\",\"\(safeNotes)\",\"\(walletName)\"\n"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("MoneyDev_Reporte_\(Int(Date().timeIntervalSince1970)).csv")
        
        do {
            try csv.write(to: fileUrl, atomically: true, encoding: .utf8)
            return fileUrl
        } catch {
            print("ReportExportHelper: Error escribiendo CSV: \(error)")
            return nil
        }
    }
    
    // MARK: - PDF Report Generation
    
    public static func generatePdfReport(
        periodTitle: String,
        isIncome: Bool,
        categories: [CategorySummary],
        transactions: [Transaction],
        totalAmount: Double,
        currencySymbol: String,
        walletName: String
    ) -> Data? {
        let pageWidth: CGFloat = 595.2 // Standard A4 width in points
        let pageHeight: CGFloat = 841.8 // Standard A4 height in points
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            
            // Fondo oscuro elegante Midnight
            cgContext.setFillColor(UIColor(red: 4/255, green: 7/255, blue: 17/255, alpha: 1.0).cgColor)
            cgContext.fill(pageRect)
            
            // Contenedor principal
            let cardRect = CGRect(x: 24, y: 24, width: pageWidth - 48, height: pageHeight - 48)
            cgContext.setFillColor(UIColor(red: 11/255, green: 19/255, blue: 43/255, alpha: 1.0).cgColor)
            cgContext.fill(cardRect)
            
            // Borde sutil
            cgContext.setStrokeColor(UIColor(red: 34/255, green: 58/255, blue: 107/255, alpha: 0.8).cgColor)
            cgContext.setLineWidth(1.5)
            cgContext.stroke(cardRect)
            
            // Encabezado
            let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
            let subTitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .medium)
            
            let accentColor = isIncome ? UIColor(red: 52/255, green: 211/255, blue: 153/255, alpha: 1.0) : UIColor(red: 251/255, green: 113/255, blue: 133/255, alpha: 1.0)
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: accentColor
            ]
            let subject = isIncome ? "Reporte de Ingresos" : "Reporte de Gastos"
            "MoneyDev • \(subject)".draw(at: CGPoint(x: 44, y: 44), withAttributes: titleAttrs)
            
            let subTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: subTitleFont,
                .foregroundColor: UIColor(white: 0.7, alpha: 1.0)
            ]
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
            "Billetera: \(walletName)  |  Período: \(periodTitle)  |  Generado: \(dateStr)".draw(at: CGPoint(x: 44, y: 74), withAttributes: subTitleAttrs)
            
            // Caja de métrica total
            let metricRect = CGRect(x: 44, y: 100, width: pageWidth - 88, height: 50)
            cgContext.setFillColor(UIColor(red: 17/255, green: 29/255, blue: 56/255, alpha: 1.0).cgColor)
            cgContext.fill(metricRect)
            
            let totalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let totalStr = "Total del período: \(currencySymbol) \(FormatHelper.formatCurrency(totalAmount))"
            totalStr.draw(at: CGPoint(x: 58, y: 114), withAttributes: totalAttrs)
            
            // Desglose de categorías
            var currentY: CGFloat = 170
            let catTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor(white: 0.9, alpha: 1.0)
            ]
            "Distribución por Categorías".draw(at: CGPoint(x: 44, y: currentY), withAttributes: catTitleAttrs)
            currentY += 24
            
            for cat in categories.prefix(6) {
                let catAttrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: UIColor.white
                ]
                let percentStr = String(format: "%.1f%%", cat.percentage * 100)
                let text = "• \(cat.categoryName): \(currencySymbol) \(FormatHelper.formatCurrency(cat.totalAmount)) (\(percentStr)) - \(cat.transactionCount) mov."
                text.draw(at: CGPoint(x: 54, y: currentY), withAttributes: catAttrs)
                currentY += 18
            }
            
            // Lista de últimos movimientos
            currentY += 16
            "Detalle de Movimientos Recientes".draw(at: CGPoint(x: 44, y: currentY), withAttributes: catTitleAttrs)
            currentY += 24
            
            let filteredTxs = transactions.filter { $0.type == (isIncome ? .income : .expense) }
            for tx in filteredTxs.prefix(15) {
                let d = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
                let shortDate = DateFormatter.localizedString(from: d, dateStyle: .short, timeStyle: .none)
                let txText = "[\(shortDate)]  \(tx.title)  (\(tx.category)):  \(currencySymbol) \(FormatHelper.formatCurrency(tx.amount))"
                
                let txAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor(white: 0.8, alpha: 1.0)
                ]
                txText.draw(at: CGPoint(x: 54, y: currentY), withAttributes: txAttrs)
                currentY += 16
                if currentY > pageHeight - 60 { break }
            }
            
            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .light),
                .foregroundColor: UIColor(white: 0.5, alpha: 1.0)
            ]
            "MoneyDev App • Tus finanzas personales bajo control".draw(at: CGPoint(x: 44, y: pageHeight - 44), withAttributes: footerAttrs)
        }
        
        return data
    }
}
