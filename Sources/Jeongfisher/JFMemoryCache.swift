//
//  JFMemoryCache.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

/// 캐시 정책
/// - LRU: 오래 사용하지 않은 데이터 삭제
/// - LFU: 적게 사용한 데이터 삭제
public enum JFCachePolicy {
    /// 오래 사용하지 않은 데이터 삭제
    case LRU
    /// 적게 사용한 데이터 삭제
    case LFU
//    case Custom(compareRule: ((_ oldItem: any JFCacheItemable, _ newItem: any JFCacheItemable) -> Bool))
}

/// 메모리 캐싱을 담당하는 클래스
open class JFMemoryCache<Item: JFCacheItemable>: JFCacheable {
    public typealias Key = String
    public typealias Value = Item
    
    private final class Node {
        var prev, next: Node?
        var key: Key
        var value: Value
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private var cache: [Key: Node] = [:]
    private var head, tail: Node? //양방향 링크드 리스트
    
    private(set) var maxHitCount: Int = 0, minHitCount: Int = 0
    
    private(set) var currentCachedCost: Int64 = 0 //capacity 이상이 되면 정책에 따라 캐시 정리
    private(set) var capacity: JFDataSize //메모리캐시 최대 용량
    private(set) var cacheDataSizeLimit: JFDataSize //메모리캐시에 저장할 수 있는 데이터 최대 사이즈
    private(set) var cachePolicy: JFCachePolicy //중간에 바꾸지 못함
    
    private let lock = NSLock()
    
    public init(
        capacity: JFDataSize = .MB(8192), //NSCache와 동일한 capacity
        cacheDataSizeLimit: JFDataSize = .Infinity,
        cachePolicy: JFCachePolicy = .LRU)
    {
        self.capacity = capacity
        self.cacheDataSizeLimit = cacheDataSizeLimit
        self.cachePolicy = cachePolicy
    }
    
    private func initHeadTail(item: Item) {
        var item = item
        item.hitCount = -1
        self.head = Node(key: "", value: item)
        self.tail = Node(key: "", value: item)
        
        self.head?.next = tail
        self.tail?.prev = head
    }
    
    public func getData(key: String) -> Item? {
        defer { lock.unlock() }
        lock.lock()
        
        //아이템이 없으면 nil 반환
        guard let cacheNode = cache[key] else { return nil }

        //맨 앞으로 노드 옮기기
        removeNode(cacheNode)
        let hitNode = hit(node: cacheNode)
        addNode(hitNode)
        
        return hitNode.value
    }
    
    //새로운 데이터 크기가 (메모리캐시 용량 || 아이템 크기 제한)보다 크면 저장 못함
    internal func isLessSizeThanDataSizeLimit(size: JFDataSize) -> Bool {
        return cacheDataSizeLimit.byte >= size.byte
    }
    
    //캐시 데이터 저장
    public func saveCache(key: String, data: Item, overwrite: Bool = true) throws {
        defer { lock.unlock() }
        lock.lock()

        if head == nil && tail == nil {
            initHeadTail(item: data)
        }
        
        if cache[key] != nil && !overwrite {
            throw JFCacheError.saveError
        }
        
        //이미 있는 데이터면 Cost 빼기
        if let cacheNode = cache[key] {
            currentCachedCost -= cacheNode.value.size.byte
        }
        
        //Cost 체크 => 새로운 데이터 들어올 수 있을 때까지 오래된 노드 삭제
        while let oldestNode = tail?.prev,
              capacity.byte <= currentCachedCost + data.size.byte {
            deleteCache(key: oldestNode.key)
            currentCachedCost -= oldestNode.value.size.byte
        }
        
        //노드 추가
        if let cacheNode = cache[key] {
            //hit
            removeNode(cacheNode)
            
            let hitNode = hit(node: cacheNode, update: data)
            addNode(hitNode)
            cache[key] = hitNode
        } else {
            //miss
            let newNode: Node = Node(key: key, value: data)
            addNode(newNode)
            cache[key] = newNode
        }
        
        //Cost 추가
        currentCachedCost += data.size.byte
    }
    
    //캐시 데이터 삭제
    @discardableResult
    public func deleteCache(key: String) -> Item? {
        defer { lock.unlock() }
        lock.lock()
        
        guard let cacheNode = cache[key] else { return nil }
        
        removeNode(cacheNode)
        cache[key] = nil
        
        return cacheNode.value
    }
    
    private func hit(node: Node, update: Item? = nil) -> Node {
        node.value.hitCount += 1
        
        if let updateData = update {
            node.value.data = updateData.data
            node.value.lastHitTimeInterval = updateData.lastHitTimeInterval
        } else {
            node.value.lastHitTimeInterval = Date().timeIntervalSince1970
        }
        
        return node
    }
    
    private func addNode(_ newNode: Node) {
        switch cachePolicy {
        case .LRU:
            //새로 들어온 노드는 항상 최신
            insertFront(newNode)
        case .LFU:
            addNodeForLFU(newNode: newNode)
        }
    }
    
    private func addNodeForLFU(newNode: Node) {
        if let nextHead = head?.next, nextHead.value.hitCount < 0 {
            insertFront(newNode)
            updateMaxMinHitCount()
            return
        }
        
        //hitCount로 정렬
        let newHitCount = newNode.value.hitCount

        let distanceFromHead = abs(maxHitCount - newHitCount)
        let distanceFromTail = abs(minHitCount - newHitCount)
        
        if distanceFromHead <= distanceFromTail {
            //head와 가까운 경우 head부터 탐색
            var curr = head
            while curr?.next != nil {
                if let node = curr, let nextNode = node.next,
                   nextNode.value.hitCount <= newHitCount { //만약 같다면 오래전에 들어온 데이터가 먼저 삭제되도록
                    node.next = newNode
                    newNode.prev = node
                    newNode.next = nextNode
                    nextNode.prev = newNode
                    break
                }
                
                curr = curr?.next
            }
        } else {
            //tail와 가까운 경우 tail부터 탐색
            var curr = tail
            while curr?.prev != nil {
                if let node = curr, let prevNode = node.prev,
                   prevNode.value.hitCount > newHitCount { //만약 같다면 오래전에 들어온 데이터가 먼저 삭제되도록
                    node.prev = newNode
                    newNode.next = node
                    newNode.prev = prevNode
                    prevNode.next = newNode
                    break
                }
                
                curr = curr?.next
            }
        }
        
        updateMaxMinHitCount()
    }
    
    private func insertFront(_ newNode: Node) {
        let front = head?.next
        head?.next = newNode
        newNode.prev = head
        newNode.next = front
        front?.prev = newNode
    }
    
    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        
        switch cachePolicy {
        case .LFU:
            updateMaxMinHitCount()
        default: break
        }
    }
    
    private func updateMaxMinHitCount() {
        if let front = head?.next, let back = tail?.prev {
            maxHitCount = front.value.hitCount
            minHitCount = back.value.hitCount
        }
    }
    
    @discardableResult
    public func cleanExpiredData() -> Int {
        var deleteCount: Int = 0
        
        //head, tail 제외
        var curr = head?.next
        while curr?.next != nil {
            if let node = curr, node.value.isExpired {
                deleteCache(key: node.key)
                deleteCount += 1
            }
            curr = curr?.next
        }
        
        return deleteCount
    }
    
    open func printNode() {
        var curr = head
        while curr != nil {
            if let node = curr {
                print("[Memory Cache] node value: \(node.value)")
            }
            curr = curr?.next
        }
    }
}
