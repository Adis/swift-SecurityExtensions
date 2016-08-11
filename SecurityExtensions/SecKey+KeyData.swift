import Foundation

extension SecKey {

    /**
     * Provides the raw key data. Wraps `SecItemCopyMatching()`. Only works if the key is
     * available in the keychain. One common way of using this data is to derive a hash
     * of the key, which then can be used for other purposes.
     *
     * The format of this data is not documented. There's been some reverse-engineering:
     * https://devforums.apple.com/message/32089#32089
     * Apparently it is a DER-formatted sequence of a modulus followed by an exponent.
     * This can be converted to OpenSSL format by wrapping it in some additional DER goop.
     *
     * - returns: the key's raw data if it could be retrieved from the keychain, or `nil`
     */
    public var keyData: [UInt8]? {
        let query = [ kSecValueRef as String : self, kSecReturnData as String : true ]
        var out: AnyObject?
        guard errSecSuccess == SecItemCopyMatching(query, &out) else {
            return nil
        }
        guard let data = out as? NSData else {
            return nil
        }

        var bytes = [UInt8](count: data.length, repeatedValue: 0)
        data.getBytes(&bytes, length:data.length)
        return bytes
    }

    /**
     * Creates a SecKey based on its raw data, as provided by `keyData`. The key is also
     * imported into the keychain. If the key already existed in the keychain, it will simply
     * be returned.
     *
     * - parameter data: the raw key data as returned by `keyData`
     * - returns: the key if it was successfully created and imported, or nil
     */
    static public func create(withData data: [UInt8]) -> SecKey? {
        let tag = SecKey.keychainTag(withData: data)
        let cfData = CFDataCreate(kCFAllocatorDefault, data, data.count)

        let query: Dictionary<String, AnyObject> = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag,
                kSecValueData as String: cfData,
                kSecReturnPersistentRef as String: true]

        var persistentRef: AnyObject?
        let status = SecItemAdd(query, &persistentRef)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            return nil
        }

        return SecKey.loadFromKeychain(tag: tag)
    }
}
