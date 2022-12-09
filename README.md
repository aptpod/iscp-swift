# iSCP 2.0 Client Library for Swift

iSCP Client for Swift は、iSCP version 2 を用いたリアルタイムAPIにアクセスするためのクライアントライブラリです。

## Requirements

- iOS 13 or later
- macOS 10.15 (Catalina) or later
- Xcode 13.0 (13A233) or later

## Installation

iscp-swiftは [CocoaPods](https://cocoapods.org/) から入手可能です。
`Podfile` に、iscp-swiftと依存ライブラリ [SwiftProtobuf](https://github.com/apple/swift-protobuf) を追加してください。

```
target '{YOUR_APP_SCHEME}' do
  ...
  pod 'iSCP'
  pod 'SwiftProtobuf', '~> 1.0'
  ...
end

# Please add at the end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end
```

## Implementation

### *Connect To intdash API*

このサンプルではiscp-swiftを使ってintdash APIに接続します。

```swift
// このサンプルではiscp-goを使ってintdash APIに接続します。
// iSCPをインポート
import iSCP

/// 接続するintdashサーバー
var targetServer: String = "https://example.com"
/// ノードUUID（ここで指定されたノードとして送受信を行います。
/// intdash APIでノードを生成した際に発行されたノードUUIDを指定します。）
var nodeID: String = "00000000-0000-0000-0000-000000000000"
/// アクセストークン
///
/// intdash APIで取得したアクセストークンを設定して下さい。
var accessToken: String = ""
/// コネクション
var connection: Connection?

extension ExampleViewController {
    
    func connect() {
        // 接続情報のセットアップをします。
        let urls = kTargetServer.components(separatedBy: "://")
        var address: String
        var enableTLS = false
        if urls.count == 1 {
            address = urls[0]
        } else {
            enableTLS = urls[0] == "https"
            address = urls[1]
        }
        // WebSocketを使って接続するように指定します。
        let transportConfig: ITransportConfig = Transport.WebSocket.Config(
            enableTLS: enableTLS
        )
        Connection.connect(
            address: address,
            transportConfig: transportConfig,
            tokenSource: { token in
                // アクセス用のトークンを指定します。接続時に発生するイベントにより使用されます。
                // ここでは固定のトークンを返していますが随時トークンの更新を行う実装にするとトークンの期限切れを考える必要がなくなります。
                token(accessToken)
            },
            nodeID: nodeID) { [weak self] con, error in
            guard let con = con else {
                // 接続失敗。
                return
            }
            // 接続成功。
            connection = con
            connection?.delegate = self // ConnectionDelegate
            // 以降、openUpstreamやopenDownstreamなどが実行可能になります。
        }
    }
}

extension ExampleViewController : ConnectionDelegate {
    
    func didReconnect(connection: Connection) {
        // Connectionが再オープンされた際にコールされます。
    }
    
    func didDisconnect(connection: Connection) {
        // Connectionがクローズされた際にコールされます。
    }
    
    func didFailWithError(connection: Connection, error: Error) {
        // Connection内部で何らかのエラーが発生した際にコールされます。
    }
    
}
```

### *Start Upstream*

アップストリームの送信サンプルです。このサンプルでは、基準時刻のメタデータと、文字列型のデータポイントをiSCPサーバーへ送信しています。

```swift
/// 送信するデータを永続化するかどうか
var upstreamPersist: Bool = false
/// オープンしたストリーム一覧
var upstreams: [Upstream] = []

extension ExampleViewController {
    
    func startUpstream() {
        // セッションIDを払い出します。
        let sessionID = UUID().uuidString.lowercased()
        
        // Upstreamをオープンします。
        connection?.openUpstream(sessionID: sessionID,
                                 persist: upstreamPersist,
                                 completion: { [weak self] upstream, error in
            guard let upstream = upstream else {
                // オープン失敗。
                return
            }
            // オープン成功。
            upstreams.append(upstream)
            
            // 送信するデータポイントを保存したい場合や、アップストリームのエラーをハンドリングしたい場合はデリゲートを設定します。
            upstream.delegate = self // UpstreamDelegate
            
            let baseTime = Date().timeIntervalSince1970 // 基準時刻です。
            
            // 基準時刻をiSCPサーバーへ送信します。
            connection?.sendBaseTime(
                baseTime: BaseTime(
                    sessionID: sessionID,
                    name: "manual",
                    priority: 1000,
                    elapsedTime: 0,
                    baseTime: baseTime),
                persist: upstreamPersist) { error in
                    if error != nil {
                        // 基準時刻の送信に失敗。
                        return
                    }
                    // 基準時刻の送信に成功。
                
                    // 文字列型のデータポイントをiSCPサーバーへ送信します。
                    upstream.writeDataPoint(
                        dataID: DataID(
                            name: "greeting",
                            type: "string"),
                        dataPoint: DataPoint(
                            elapsedTime: Date().timeIntervalSince1970-baseTime, // 基準時刻からの経過時間をデータポイントの経過時間として打刻します。
                            payload: "hello".data(using: .utf8) ?? Data())
                    )
                }
        })
    }
    
}

extension ExampleViewController : UpstreamDelegate {
    
    func didGenerateChunk(upstream: Upstream, message: UpstreamChunk) {
        // バッファへ書き込んだデータポイントが実際に送信される直前にコールされます。
    }
    
    func didReceiveAck(upstream: Upstream, message: UpstreamChunkAck) {
        // データポイントの送信後に返却されるACKを受信できた場合にコールされます。
    }
    
    func didFailWithError(upstream: Upstream, error: Error) {
        // 内部でエラーが発生した場合にコールされます。
    }
    
    func didCloseWithError(upstream: Upstream, error: Error) {
        // 何らかの理由でストリームがクローズした場合にコールされます。
        // 再度アップストリームをオープンしたい場合は、 `Connection.reopenUpstream()` を使用することにより、ストリームの設定を引き継いで別のストリームを開くことが可能です。
    }
    
    func didResume(upstream: Upstream) {
        // 自動再接続機能が働き、再接続が行われた場合にコールされます。
    }
    
}
```

### *Start Downstream*

前述のアップストリームで送信されたデータをダウンストリームで受信するサンプルです。

このサンプルでは、アップストリーム開始のメタデータ、基準時刻のメタデータ、 文字列型のデータポイントを受信しています。

```swift
/// 受信したいデータを送信している送信元ノードのUUID
/// （アップストリームを行っている送信元でConnection.Configで設定したnodeIDを指定してください。）
var targetDownstreamNodeID: String = "00000000-0000-0000-0000-000000000000"
/// オープンしたダウンストリーム一覧
var downstreams: [Downstream] = []

extension ExampleViewController {
    
    func startDownstream() {
        // ダウンストリームをオープンします。
        connection?.openDownstream(
            downstreamFilters: [
                DownstreamFilter(
                    sourceNodeID: targetDownstreamNodeID, // 送信元ノードのIDを指定します。
                    dataFilters: [
                        DataFilter(
                            name: "#", type: "#" // 受信したいデータを名称と型で指定します。この例では、ワイルドカード `#` を使用して全てのデータを取得します。
                        )
                    ])
                ],
            completion: { downstream, error in
            guard let downstream = downstream else {
                // オープン失敗。
                return
            }
            // オープン成功。
            downstreams.append(downstream)
            // 受信データを取り扱うためにデリゲートを設定します。
            downstream.delegate = self // DownstreamDelegate
        })
    }
}

extension ExampleViewController : DownstreamDelegate {
    
    func didReceiveChunk(downstream: Downstream, message: DownstreamChunk) {
        // データポイントを読み込むことができた際にコールされます。
        print("Received dataPoints sequenceNumber[\(message.sequenceNumber)], sessionId[\(message.upstreamInfo.sessionID)]")
        for g in message.dataPointGroups {
            for dp in g.dataPoints {
                print("Received a dataPoint dataName[\(g.dataID.name)], dataType[\(g.dataID.type)], payload[\(String(data: dp.payload, encoding: .utf8) ?? "")]")
            }
        }
    }
    
    func didReceiveMetadata(downstream: Downstream, message: DownstreamMetadata) {
        // メタデータを受信した際にコールされます。
        print("Received a metadata sourceNodeID[\(message.sourceNodeID)], metadataType:\(String(describing: message.metadata))")
        switch message.metadata {
        case .baseTime(let baseTime):
            print("Received baseTime[\(Date(timeIntervalSince1970: baseTime.baseTime))], priority[\(baseTime.priority)], name[\(baseTime.priority)]")
        default: break
        }
    }
    
    func didFailWithError(downstream: Downstream, error: Error) {
        // 内部でエラーが発生した場合にコールされます。
    }
    
    func didCloseWithError(downstream: Downstream, error: Error) {
        // 何らかの理由でストリームがクローズした場合にコールされます。
        // 再度ダウンストリームをオープンしたい場合は、 `Connection.reopenDownstream()` を使用することにより、ストリームの設定を引き継いで別のストリームを開くことが可能です。
    }
    
    func didResume(downstream: Downstream) {
        // 自動再接続機能が働き、再接続が行われた場合にコールされます。
    }
    
}
```

## References
- [APIリファレンス](https://docs.intdash.jp/api/intdash-sdk/swift/latest/)
  - 過去のバージョンのリファレンスは [こちら](https://docs.intdash.jp/api/intdash-sdk/swift-versions)
- [Github](https://github.com/aptpod/iscp-swift)
