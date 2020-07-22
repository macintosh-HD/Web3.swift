//
//  File.swift
//  
//
//  Created by Julian Gentges on 22.07.20.
//

import Foundation
import Dispatch
import fd

public struct Web3IPCProvider: Web3Provider {
    let listener: Listener
    let connection: UNIXConnection
    
    let queue: DispatchQueue
    
    init(path: URL? = nil) throws {
        if path == nil {
            guard let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
                throw Web3Error(kind: .wrongIPCPath)
            }
            
            path = dir
                .appendingPathComponent("Ethereum", isDirectory: true)
                .appendingPathComponent("geth.ipc")
        }
        
        listener = try UNIXClientSocket(path: path!)
        connection = try connection.accept()
        
        self.queue = DispatchQueue(label: "Web3IPCProvider", attributes: .concurrent)
    }
    
    public func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        queue.async {
            guard let data = try? JSONEncoder().encode(request) else {
                let err = Web3Response<Result>(error: .requestFailed(error))
                response(err)
                return
            }
            
            do {
                let write = try connection.write(data)
                guard write != -1 else {
                    let err = Web3Response<Result>(error: .requestFailed(nil))
                    response(err)
                    return
                }
                
                let responseData = try connection.readAll()
                let rpcResponse = try JSONDecoder().decode(RPCResponse<Result>.self, from: responseData)
                
                if let error = response.error {
                    let err = Web3Response<Result>(error: .decodingError(nil))
                    response(err)
                    return
                }
                
                let res = Web3Response(rpcResponse: rpcResponse)
                response(res)
            } catch {
                let err = Web3Response<Result>(error: .serverError(nil))
                response(err)
                return
            }
        }
    }
}
