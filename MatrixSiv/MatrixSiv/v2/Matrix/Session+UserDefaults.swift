//
//  Session+UserDefaults.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/14/25.
//

import Foundation
import MatrixRustSDK

extension Session {
    static let userDefaultsKey = "matrixSession"
    func saveToUserDefaults() {
        UserDefaults.standard.removeObject(forKey: Session.userDefaultsKey)
        let session = SessionUserDefault(session: self)
        do {
            let encoded = try JSONEncoder().encode(session)
            UserDefaults.standard.setValue(encoded, forKey: Session.userDefaultsKey)
        } catch {
            print("ERROR: unable to encode to UserDefaults \(error)")
        }
    }
    
    static func loadFromUserDefaults() -> Session? {
        if let data =  UserDefaults.standard.data(forKey: Session.userDefaultsKey) {
            do {
                let userDefaultsSession = try JSONDecoder().decode(SessionUserDefault.self, from: data)
                return userDefaultsSession.toMatrixSession()
            } catch {
                print("Error decoding from UserDefaults: \(error)")
            }
            
        }
        return nil
        
    }
    
    struct SessionUserDefault: Codable {
        let accessToken: String
        let refreshToken: String?
        let userId: String
        let deviceId: String
        let homeserverUrl: String
        let oidcData: String?
        
        init(session: Session) {
            self.accessToken = session.accessToken
            self.refreshToken = session.refreshToken
            self.userId = session.userId
            self.deviceId = session.deviceId
            self.homeserverUrl = session.homeserverUrl
            self.oidcData = session.oidcData
        }
        
        func toMatrixSession() -> Session {
            Session(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userId: userId,
                deviceId: deviceId,
                homeserverUrl: homeserverUrl,
                oidcData: oidcData,
                slidingSyncVersion: .native
            )
        }
    }
}
