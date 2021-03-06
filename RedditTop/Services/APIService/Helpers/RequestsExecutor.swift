//
//  RequestsExecutor.swift
//  RedditTop
//
//  Created by Vladyslav Skintiyan on 12.04.2020.
//  Copyright © 2020 Vladyslav Skintiyan. All rights reserved.
//

import Foundation

enum APIError: Error {
    case general(descriprion: String)
    case parsing
    case invalidStatusCode
}

struct Response<T> {
    let value: T
    let response: URLResponse
}

typealias HandllerType<T> = Result<Response<T>, Error>
typealias DataHandllerType = Result<Response<Data>, Error>

protocol RequestsExecutor {
    @discardableResult
    func execute<T: Decodable>(url: URL, handler: @escaping (HandllerType<T>) -> ()) -> Cancellable
    
    @discardableResult
    func executeData(url: URL, handler: @escaping (DataHandllerType) -> ()) -> Cancellable
}

final class RequestsExecutorImpl: RequestsExecutor {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    @discardableResult
    func execute<T: Decodable>(url: URL, handler: @escaping (HandllerType<T>) -> ()) -> Cancellable {
        return executeData(url: url) { result in
            switch result {
            case let .success(response):
                if let responseValue = try? JSONDecoder().decode(T.self, from: response.value) {
                    handler(.success(Response(value: responseValue, response: response.response)))
                }
            case let .failure(error):
                handler(.failure(error))
            }
        }
    }
    
    @discardableResult
    func executeData(url: URL, handler: @escaping (DataHandllerType) -> ()) -> Cancellable {
        let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
            guard error == nil else {
                return handler(.failure(APIError.general(descriprion: String(describing: error))))
            }
            
            guard let response = (response as? HTTPURLResponse), 200...299 ~= response.statusCode else {
                return handler(.failure(APIError.invalidStatusCode))
            }
            
            guard let data = data else {
                return handler(.failure(APIError.general(descriprion: "No data in response")))
            }
            
            handler(.success(Response(value: data, response: response)))
        })
        
        task.resume()
        return task
    }
}
