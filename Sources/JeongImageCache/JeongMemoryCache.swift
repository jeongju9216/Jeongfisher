//
//  JeongMemoryCache.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

///캐시 정책
///- LRU: 오래 사용하지 않은 데이터 삭제
///- LFU: 적게 사용한 데이터 삭제
public enum JeongCachePolicy {
    ///오래 사용하지 않은 데이터 삭제
    case LRU
    ///적게 사용한 데이터 삭제
    case LFU
    case Custom(compareRule: ((_ oldItem: any JeongCacheItemable, _ newItem: any JeongCacheItemable) -> Bool))
}

///메모리 캐싱을 담당하는 클래스
open class JeongMemoryCache<Item: JeongCacheItemable>: JeongCacheable {
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
    private(set) var capacity: JeongDataSize //메모리캐시 최대 용량
    private(set) var cacheDataSizeLimit: JeongDataSize //메모리캐시에 저장할 수 있는 데이터 최대 사이즈
    private(set) var cachePolicy: JeongCachePolicy //중간에 바꾸지 못함
    
    private var isLocking: Bool = false //연속 lock 방지
    private let lock = NSLock()
    
    public init(capacity: JeongDataSize = .MB(10),
                cacheDataSizeLimit: JeongDataSize = .KB(200),
                cachePolicy: JeongCachePolicy = .LRU) {
        self.capacity = capacity
        self.cacheDataSizeLimit = cacheDataSizeLimit
        self.cachePolicy = cachePolicy
    }
    
    private func initHeadTail(item: Item) {
        JICLogger.log("[Memory Cache] initHeadTail")
        var item = item
        item.hitCount = -1
        self.head = Node(key: "", value: item)
        self.tail = Node(key: "", value: item)
        
        self.head?.next = tail
        self.tail?.prev = head
    }
    
    public func getData(key: String) -> Item? {
        defer {
            unlockThread()
        }
        
        if !isLocking {
            lockThread()
        }
        
        //아이템이 없으면 nil 반환
        guard let cacheNode = cache[key] else {
            unlockThread()
            return nil
        }

        JICLogger.log("[Memory Cache] Get: \(key)")

        //맨 앞으로 노드 옮기기
        removeNode(cacheNode)
        let hitNode = hit(node: cacheNode)
        addNode(hitNode)
        
        unlockThread()
        return hitNode.value
    }
    
    //새로운 데이터 크기가 (메모리캐시 용량 || 아이템 크기 제한)보다 크면 저장 못함
    internal func isLessSizeThanDataSizeLimit(size: JeongDataSize) -> Bool {
        return cacheDataSizeLimit.byte >= size.byte
    }
    
    //캐시 데이터 저장
    public func saveCache(key: String, data: Item, overwrite: Bool = true) throws {
        defer {
            unlockThread()
        }
        JICLogger.log("[Memory Cache] Capacity: \(capacity.byte) / current: \(currentCachedCost) / size limit: \(cacheDataSizeLimit.byte) / data size: \(data.size.byte)")
        if head == nil && tail == nil {
            initHeadTail(item: data)
        }
        
        if !isLocking {
            lockThread()
        }
        
        if cache[key] != nil && !overwrite {
            unlockThread()
            throw JeongCacheError.saveError
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
            JICLogger.log("[Memory Cache] Update: \(key)")
            removeNode(cacheNode)
            
            let hitNode = hit(node: cacheNode, update: data)
            addNode(hitNode)
            cache[key] = hitNode
        } else {
            //miss
            JICLogger.log("[Memory Cache] Save: \(key)")
            let newNode: Node = Node(key: key, value: data)
            addNode(newNode)
            cache[key] = newNode
        }
        unlockThread()
        
        //Cost 추가
        currentCachedCost += data.size.byte
    }
    
    //캐시 데이터 삭제
    @discardableResult
    public func deleteCache(key: String) -> Item? {
        defer {
            unlockThread()
        }
        
        if !isLocking {
            lockThread()
        }
        
        guard let cacheNode = cache[key] else {
            unlockThread()
            return nil
        }
        
        JICLogger.log("[Memory Cache] Delete: \(key)")
        removeNode(cacheNode)
        
        cache[key] = nil
        unlockThread()
        
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
        case .Custom(let compareRule):
            var curr = head
            while curr?.next != nil {
                if let node = curr, let nextNode = node.next,
                   compareRule(node.value, newNode.value) {
                    node.next = newNode
                    newNode.prev = node
                    newNode.next = nextNode
                    nextNode.prev = newNode
                    break
                }
                
                curr = curr?.next
            }
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
        JICLogger.log("[Memory Cache] maxHitCount: \(maxHitCount) / minHitCount: \(minHitCount) / newHitCount: \(newHitCount)")

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
        JICLogger.log("[Memory Cache] Clean Expired Data")
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

extension JeongMemoryCache {
    private func lockThread() {
        while isLocking {
            usleep(10) //0.00001초 //busy waiting일 때 CPU 부담 줄임
            JICLogger.log("[Memory Cache] Locking")
        }
        
        if !isLocking {
            isLocking = true
            lock.lock()
        }
    }
    
    private func unlockThread() {
        lock.unlock()
        isLocking = false
    }
}
