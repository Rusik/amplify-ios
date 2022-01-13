//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSPluginsCore
import Foundation

struct AuthTokenURLRequestInterceptor: URLRequestInterceptor {

    let authTokenProvider: AuthTokenProvider

    init(authTokenProvider: AuthTokenProvider) {
        self.authTokenProvider = authTokenProvider
    }

    func intercept(_ request: URLRequest) throws -> URLRequest {

        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            throw APIError.unknown("Could not get mutable request", "")
        }
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = AWSAPIPluginsCore.AWSDateISO8601DateFormat2
        let amzDate = dateFormatter.string(from: date)
        
        mutableRequest.setValue(amzDate,
                                forHTTPHeaderField: URLRequestConstants.Header.xAmzDate)
        mutableRequest.setValue(URLRequestConstants.ContentType.applicationJson,
                                forHTTPHeaderField: URLRequestConstants.Header.contentType)
        mutableRequest.setValue(AWSAPIPluginsCore.baseUserAgent(),
                                forHTTPHeaderField: URLRequestConstants.Header.userAgent)

        let tokenResult = authTokenProvider.getToken()
        guard case let .success(token) = tokenResult else {
            if case let .failure(error) = tokenResult {
                throw APIError.operationError("Failed to retrieve authorization token.", "", error)
            }

            return mutableRequest as URLRequest
        }
        mutableRequest.setValue(token, forHTTPHeaderField: "authorization")
        return mutableRequest as URLRequest
    }
}
