//
//  Storage+Certificate.swift
//  AshteMobile
//
//  Created by samara on 16.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator
import ZsignSwift

// MARK: - Class extension: certificate
extension Storage {
    func addCertificate(
        uuid: String,
        password: String? = nil,
        nickname: String? = nil,
        ppq: Bool = false,
        expiration: Date,
        isDefault: Bool = false,
        completion: @escaping (Error?) -> Void
    ) {
        // 💡 چارەسەری کراش: هێنانە ناو Main Thread بۆ ڕێگریکردن لە کراشی UI و CoreData
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .light)
            
            let new = CertificatePair(context: self.context)
            new.uuid = uuid
            new.date = Date()
            new.password = password
            new.ppQCheck = ppq
            new.expiration = expiration
            new.nickname = nickname
            new.isDefault = isDefault
            
            self.saveContext()
            generator.impactOccurred()
            
            // بانگکردنی پشکنینی Zsign پاش ئەوەی دڵنیا بووین فایلەکە خەزن کراوە
            self.revokagedCertificate(for: new)
            
            completion(nil)
        }
    }
    
    func deleteCertificate(for cert: CertificatePair) {
        if let url = getUuidDirectory(for: cert) {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(cert)
        saveContext()
    }
    
    func getCertificate(for index: Int) -> CertificatePair? {
        let fetchRequest: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]

        guard
            let results = try? context.fetch(fetchRequest),
            index >= 0 && index < results.count
        else {
            return nil
        }
        
        return results[index]
    }
    
    func revokagedCertificate(for cert: CertificatePair) {
        guard !cert.revoked else { return }
        
        // 💡 چارەسەری کراشی Zsign: دڵنیابوونەوە لەوەی ڕێڕەوەکان بەتاڵ نین
        guard let provPath = Storage.shared.getFile(.provision, from: cert)?.path, !provPath.isEmpty,
              let p12Path = Storage.shared.getFile(.certificate, from: cert)?.path, !p12Path.isEmpty else {
            return
        }
        
        let pass = cert.password ?? ""
        let objectID = cert.objectID // وەرگرتنی ID بۆ ڕێگریکردن لە تێکەڵبوونی Threadـەکان
        
        Zsign.checkRevokage(
            provisionPath: provPath,
            p12Path: p12Path,
            p12Password: pass
        ) { (status, _, _) in
            if status == 1 {
                DispatchQueue.main.async {
                    // بەکارهێنانی objectID بۆ دۆزینەوەی سەلامەتی فایلەکە
                    if let safeCert = try? self.context.existingObject(with: objectID) as? CertificatePair {
                        safeCert.revoked = true
                        self.saveContext()
                    }
                }
            }
        }
    }
    
    enum FileRequest: String {
        case certificate = "p12"
        case provision = "mobileprovision"
    }
    
    func getFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
        guard let url = getUuidDirectory(for: cert) else {
            return nil
        }
        
        return FileManager.default.getPath(in: url, for: type.rawValue)
    }
    
    func getProvisionFileDecoded(for cert: CertificatePair) -> Certificate? {
        guard let url = getFile(.provision, from: cert) else {
            return nil
        }
        
        let read = CertificateReader(url)
        return read.decoded
    }
    
    func getUuidDirectory(for cert: CertificatePair) -> URL? {
        guard let uuid = cert.uuid else {
            return nil
        }
        
        return FileManager.default.certificates(uuid)
    }
    
    func getAllCertificates() -> [CertificatePair] {
        let fetchRequest: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
        return (try? context.fetch(fetchRequest)) ?? []
    }
}
