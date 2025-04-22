//
//  ServerTimeUtil.swift
//  ToDo
//
//  Created by Hold Apps on 18/4/2025.
//


import Foundation


public class ServerTimeUtil: NSObject{
    
    public static func getServerTime(completionHandler:@escaping (_ getResDate: Date?) -> Void) {

        let url = NSURL(string: "https://www.google.com")
        let task = URLSession.shared.dataTask(with: url! as URL) {(data, response, error) in
            if let httpResponse = response as? HTTPURLResponse{
                if let contentType = httpResponse.allHeaderFields["Date"] as? String {

                    let dFormatter = DateFormatter()
                    dFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                    dFormatter.locale = Locale(identifier: "en-US")
                    if let serverTime = dFormatter.date(from: contentType) {
                        completionHandler(serverTime)
                    } else {
                        completionHandler(nil)
                    }
                }
            }else{
                completionHandler(nil)
            }
            
        }

        task.resume()
    }
}
