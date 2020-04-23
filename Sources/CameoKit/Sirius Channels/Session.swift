//
//  Cookies.swift
//  Camouflage
//
//  Created by Todd Bruss on 1/20/19.
//

import Foundation


internal func Session(channelid: String) -> String {
    var channelLineUpId = "350" //default to large channel and image set

    let timeInterval = NSDate().timeIntervalSince1970
    let convert = timeInterval * 1000 as NSNumber
    let intTime = Int(truncating: convert)
    let time = String(intTime)

    let endpoint = http + root + "/resume?channelId=" + channelid + "&contentType=live&timestamp=" + time + "&cacheBuster=" + time
    let request =  ["moduleList": ["modules": [["moduleRequest": ["resultTemplate": "web", "deviceInfo": ["osVersion": "Mac", "platform": "Web", "clientDeviceType": "web", "sxmAppVersion": "3.1802.10011.0", "browser": "Safari", "browserVersion": "11.0.3", "appRegion": "US", "deviceModel": "K2WebClient", "player": "html5", "clientDeviceId": "null"]]]]]] as Dictionary
    
    //MARK: - for Sync
    let semaphore = DispatchSemaphore(value: 0)
    let http_method = "POST"
    let time_out = 30
    
    func getURLRequest() -> URLRequest! {
        if let url = URL(string: endpoint) {
            var urlReq = URLRequest(url: url)
            urlReq.httpMethod = http_method
            urlReq.httpBody = try? JSONSerialization.data(withJSONObject: request, options: .prettyPrinted)
            urlReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlReq.httpMethod = http_method
            urlReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.2 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            urlReq.timeoutInterval = TimeInterval(time_out)
            return urlReq
        }
        
        return nil
    }
    
    let task = URLSession.shared.dataTask(with: getURLRequest() ) { ( rData, resp, error ) in
    
        if let r = resp as? HTTPURLResponse {
            if r.statusCode == 200 {
                
                do { let result =
                    try JSONSerialization.jsonObject(with: rData!, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any]
                    
                    let fields = r.allHeaderFields as? [String : String]
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields!, for: r.url!)
                    HTTPCookieStorage.shared.setCookies(cookies, for: r.url!, mainDocumentURL: nil)
                    
                    for cookie in cookies {
                        
                        //This token changes on every pull and expires in about 480 seconds or less
                        if cookie.name == "SXMAKTOKEN" {
                            
                            let t = cookie.value as String
                            if t.count > 44 {
                                let startIndex = t.index(t.startIndex, offsetBy: 3)
                                let endIndex = t.index(t.startIndex, offsetBy: 45)
                                user.token = String(t[startIndex...endIndex])
                                break
                            }
                           
                        }
                    }
                    
                    let dict = result as NSDictionary?
                    /* get patterns and encrpytion keys */
                    let s = dict?.value( forKeyPath: "ModuleListResponse.moduleList.modules" )
                    let p = s as? NSArray
                    let x = p?.firstObject as? NSDictionary
                    
                    //New return the channel lineup Id
                    if let cid = x?.value( forKeyPath: "clientConfiguration.channelLineupId" ) as? String {
                        channelLineUpId = String(cid)
                    }
                    
                    if let customAudioInfos = x?.value( forKeyPath: "moduleResponse.liveChannelData.customAudioInfos" ) as? NSArray,
                       let c = customAudioInfos[0] as? NSDictionary,
                       let chunk = c.value( forKeyPath: "chunks.chunks") as? NSArray,
                       let d = chunk[0] as? NSDictionary,
                       let key = d.value( forKeyPath: "key") as? String,
                       let keyurl = d.value( forKeyPath: "keyUrl") as? String,
                       let consumer = x?.value( forKeyPath: "moduleResponse.liveChannelData.hlsConsumptionInfo" ) as? String {
                       
                        user.key = key
                        user.keyurl = keyurl
                        user.consumer = consumer
                    
                        UserDefaults.standard.set(user.key, forKey: "key")
                        UserDefaults.standard.set(user.keyurl, forKey: "keyurl")
                        UserDefaults.standard.set(user.consumer, forKey: "consumer")
                    }
                    
                } catch {
                    //fail on any errors
                    print(error)
                }
            }
            
        }
        
  
        //MARK - for Sync
        semaphore.signal()
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    
    UserDefaults.standard.set(user.token, forKey: "token")
    
    return String(channelLineUpId)
}
