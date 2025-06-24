//
//  MatrixRegistration.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 6/24/25.
//

import Foundation
struct MatrixRegistrationRequest: Codable {
    let username: String
    let password: String?
    let auth: MatrixAuthStep1Request
    
    func convertToJSON() -> Data? {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(self)
            return jsonData
        } catch {
            print("Error encoding body to JSON: \(error)")
            return nil
        }
    }
    /// Returns username
    func execute() async throws -> String {
        let urlString = "https://\(AppConstants.appServiceURL)/_matrix/client/v3/register"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = self.convertToJSON()
        
        print("MATRIX: Registering user \(username)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw MatrixError.registrationError(desc: "Unable to parse response as HTTPURLResponse")
        }
        
        if response.statusCode == 200 {
            print("Successfully registered user \(username)")
            return username
        } else if response.statusCode == 401 {
            print("Code 401. getting the session for the next phase")
            let unauthorisedResponse = try JSONDecoder().decode(MatrixUnauthorizedResponse.self, from: data)
            let session = unauthorisedResponse.session
                let newBody = MatrixRegistrationRequest(username: self.username, password: self.password, auth: .init(token: self.auth.token, session: session, type: .registrationToken))
                return try await newBody.execute()
        } else {
            let jsonResult = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
            throw MatrixError.registrationError(desc: "Invalid Status Code with data \(jsonResult!)")
        }
    }
}
struct MatrixAuthStep1Request: Codable {
    var token: String = AppConstants.registrationToken
    let session: String?
    let type: MatrixRegistrationType
}
enum MatrixRegistrationType: String, Codable {
    case dummy = "m.login.dummy"
    case registrationToken = "m.login.registration_token"
}
struct MatrixUnauthorizedResponse: Codable {
    let session: String?
}

enum MatrixError: Error, CustomStringConvertible {
    case crowtocracyError
    case loginError(desc: String)
    case otherError(desc: String)
    case roomNotFound(roomId: String)
    case roomPreviewError(desc: String)
    case registrationError(desc: String)

    var description: String {
        switch self {
        case .crowtocracyError:
            return "MERROR: User is not a crowtocracy member."
        case .loginError(let desc):
            return "MERROR: Unable to login. \(desc)"
        case .otherError(let desc):
            return "MERROR: \(desc)"
        case .roomNotFound(let roomId):
            return "MERROR: Room not found: \(roomId)."
        case .roomPreviewError(let desc):
            return "MERROR: Room preview error: \(desc)"
        case .registrationError(let desc):
            return "MERROR: Registration error: \(desc)"
        }
    }
}
