//
//  Network.swift
//  iGithub
//
//  Created by yfm on 2019/1/4.
//  Copyright © 2019年 com.yfm.www. All rights reserved.
//

import Foundation
import Moya
import RxSwift

let tokenPlugin = AccessTokenPlugin { () -> String in
    return AuthManager.share.token ?? ""
}

let requestClosure = { (endpoint: Endpoint, done: @escaping MoyaProvider<MultiTarget>.RequestResultClosure) in
    do {
        var urlRequest = try endpoint.urlRequest()
        urlRequest.timeoutInterval = 30
        done(.success(urlRequest))
    } catch MoyaError.requestMapping(let url) {
        done(.failure(MoyaError.requestMapping(url)))
    } catch MoyaError.parameterEncoding(let error) {
        done(.failure(MoyaError.parameterEncoding(error)))
    } catch {
        done(.failure(MoyaError.underlying(error, nil)))
    }
}

let endpointClosure = { (target: MultiTarget) -> Endpoint in
    var defaultEndpoint = MoyaProvider<MultiTarget>.defaultEndpointMapping(for: target)
    return defaultEndpoint.adding(newHTTPHeaderFields: ["Authorization": AuthManager.share.token ?? ""])
}

let activityPlugin = NetworkActivityPlugin { (type, target) in
    switch type {
    case .began:
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    case .ended:
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}

let provider = MoyaProvider(endpointClosure: endpointClosure,
                            requestClosure: requestClosure,
                            stubClosure: MoyaProvider.neverStub,
                            callbackQueue: nil,
                            manager: MoyaProvider<MultiTarget>.defaultAlamofireManager(),
                            plugins: [NetworkLogPlugin(),
                                      activityPlugin,
                                      tokenPlugin])

class Network {

    static var isAlertShow = false

    /// network request
    ///
    /// - Parameter target: target
    /// - Returns: Observable<Response>
    static func request(_ target: GithubTarget) -> Observable<Response> {
        return Observable.create({ (observer) -> Disposable in
            provider.request(MultiTarget(target), completion: { result in
                switch result {
                case .success(let response):
                    do {
                        // filter http status code
                        let response = try response.filterSuccessfulStatusCodes()
                        observer.onNext(response)
                        observer.onCompleted()
                    } catch {
                        // http request fails
//                        #if DEBUG
//                        let responseData = try? JSONSerialization.jsonObject(with: response.data)
//                        var message = ""
//                        if let responseData = responseData as? [String : Any] {
//                            message = responseData["message"] as? String ?? ""
//                        }
//                        if !isAlertShow {
//                            isAlertShow = !isAlertShow
//                            self.showAlert(String(describing: response.statusCode), message: message, action: {
//                                isAlertShow = false
//                            })
//                        }
//                        #endif
                        observer.onError(error)
                    }
                case .failure(let error):
//                    #if DEBUG
//                    if !isAlertShow {
//                        isAlertShow = !isAlertShow
//                        self.showAlert(String(describing: error.response?.statusCode ?? -1), message: error.localizedDescription, action: {
//                            isAlertShow = false
//                        })
//                    }
//                    #endif
                    observer.onError(error)
                }
            })
            return Disposables.create()
        })
    }

    static func showAlert(_ title: String = "",
                          message: String,
                          action: @escaping ()->()) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "confirm", style: .default) { _ in
            alert.dismiss(animated: true, completion: nil)
            action()
        }
        alert.addAction(confirmAction)
        if let vc = UIApplication.shared.keyWindow?.rootViewController {
            vc.present(alert, animated: true, completion: nil)
        }
    }
}
