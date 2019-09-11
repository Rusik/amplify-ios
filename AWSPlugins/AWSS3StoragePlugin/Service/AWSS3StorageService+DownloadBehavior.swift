//
// Copyright 2018-2019 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import Amplify

public typealias DownloadTaskCreatedHandler = (AWSTask<AWSS3TransferUtilityDownloadTask>) -> Any?

extension AWSS3StorageService {
    public func download(serviceKey: String,
                         fileURL: URL?,
                         onEvent: @escaping StorageDownloadOnEventHandler) {

        let downloadTaskCreatedHandler = AWSS3StorageService.makeDownloadTaskCreatedHandler(onEvent: onEvent)
        let expression = AWSS3TransferUtilityDownloadExpression()
        expression.progressBlock = AWSS3StorageService.makeOnDownloadProgressHandler(onEvent: onEvent)
        let onDownloadCompletedHandler = AWSS3StorageService.makeDownloadCompletedHandler(onEvent: onEvent)

        if let fileURL = fileURL {
            transferUtility.download(to: fileURL,
                                     bucket: bucket,
                                     key: serviceKey,
                                     expression: expression,
                                     completionHandler: onDownloadCompletedHandler)
                .continueWith(block: downloadTaskCreatedHandler)
        } else {
            transferUtility.downloadData(fromBucket: bucket,
                                         key: serviceKey,
                                         expression: expression,
                                         completionHandler: onDownloadCompletedHandler)
                .continueWith(block: downloadTaskCreatedHandler)

        }
    }

    private static func makeDownloadTaskCreatedHandler(
        onEvent: @escaping StorageDownloadOnEventHandler) -> DownloadTaskCreatedHandler {

        let block: DownloadTaskCreatedHandler = { (task: AWSTask<AWSS3TransferUtilityDownloadTask>) -> Any? in
            guard task.error == nil else {
                let error = task.error! as NSError
                let innerMessage = StorageErrorHelper.getInnerMessage(error)
                let errorDescription = StorageErrorHelper.getErrorDescription(innerMessage: innerMessage)
                onEvent(StorageEvent.failed(StorageGetError.unknown(errorDescription, "Recovery Message")))

                return nil
            }

            guard let downloadTask = task.result else {
                onEvent(StorageEvent.failed(StorageGetError.unknown("No ContinuationBlock data", "")))
                return nil
            }

            onEvent(StorageEvent.initiated(StorageOperationReference(downloadTask)))
            return nil
        }

        return block
    }

    private static func makeOnDownloadProgressHandler(
        onEvent: @escaping StorageDownloadOnEventHandler) -> AWSS3TransferUtilityProgressBlock {

        let block: AWSS3TransferUtilityProgressBlock = {(task, progress) in
            onEvent(StorageEvent.inProcess(progress))
        }

        return block
    }

    private static func makeDownloadCompletedHandler(
        onEvent: @escaping StorageDownloadOnEventHandler) -> AWSS3TransferUtilityDownloadCompletionHandlerBlock {

        let block: AWSS3TransferUtilityDownloadCompletionHandlerBlock = { (task, location, data, error ) in
            guard let response = task.response else {
                onEvent(StorageEvent.failed(StorageGetError.unknown("Missing HTTP Status", "")))
                return
            }

            guard response.statusCode == 200 else {
                // TODO HttpStatus Mapper
                // TODO any retry logic based on status code?
                if response.statusCode == 404 {
                    onEvent(StorageEvent.failed(StorageGetError.notFound(
                        StorageErrorConstants.KeyNotFound.errorDescription,
                        StorageErrorConstants.KeyNotFound.recoverySuggestion)))

                } else {
                    onEvent(StorageEvent.failed(StorageGetError.httpStatusError(
                        "status code \(response.statusCode)", "Check the status code")))
                }

                return
            }

            guard error == nil else {
                let error = error! as NSError

                onEvent(StorageEvent.failed(StorageGetError.unknown("Error with code: \(error.code) ", "")))
                return
            }

            onEvent(StorageEvent.completed(StorageGetResult(data: data)))
        }

        return block
    }
}
