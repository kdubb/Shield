//
//  SecCertificateTests.swift
//  Shield
//
//  Copyright © 2021 Outfox, inc.
//
//
//  Distributed under the MIT License, See LICENSE for details.
//

@testable import Shield
import XCTest

class SecCertificateTests: XCTestCase {

  static let outputEnabled = false
  static var keyPair: SecKeyPair!

  override class func setUp() {
    // Keys are comparatively slow to generate... so we do it once
    guard let keyPair = try? SecKeyPair.Builder(type: .rsa, keySize: 2048).generate(label: "Test") else {
      return XCTFail("Key pair generation failed")
    }
    Self.keyPair = keyPair
  }

  override class func tearDown() {
    try? keyPair.delete()
  }

  func testCertificateProperties() throws {

    let subjectName = try NameBuilder()
      .add("Unit Testing", forTypeName: "CN")
      .add("123456", forTypeName: "UID")
      .name

    let issuerName = try NameBuilder()
      .add("Test Issuer", forTypeName: "CN")
      .name

    let certData =
      try Certificate.Builder()
        .subject(name: subjectName)
        .issuer(name: issuerName)
        .publicKey(keyPair: Self.keyPair, usage: [.keyCertSign, .cRLSign])
        .valid(for: 86400 * 5)
        .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
        .encoded()

    output(certData)

    let cert = try SecCertificate.from(data: certData)

    XCTAssertTrue(subjectName == cert.subjectName!)
    XCTAssertTrue(issuerName == cert.issuerName!)
  }

  func testGetPublicKey() throws {

    let subjectName = try NameBuilder()
      .add("Unit Testing", forTypeName: "CN")
      .add("123456", forTypeName: "UID")
      .name

    let issuerName = try NameBuilder()
      .add("Test Issuer", forTypeName: "CN")
      .name

    let certData =
      try Certificate.Builder()
        .subject(name: subjectName)
        .issuer(name: issuerName)
        .publicKey(keyPair: Self.keyPair, usage: [.keyCertSign, .cRLSign])
        .valid(for: 86400 * 5)
        .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
        .encoded()

    output(certData)

    let cert = try SecCertificate.from(data: certData)

    XCTAssertEqual(try cert.publicKey?.encode(), try Self.keyPair.publicKey.encode())
  }

  func testValidatedPublicKey() throws {

    let rootName = try NameBuilder().add("Unit Testing Root", forTypeName: "CN").name
    let rootID = try Random.generate(count: 10)
    let rootSerialNumber = try Certificate.Builder.randomSerialNumber()
    let rootKeyHash = try Digester.digest(Self.keyPair.encodedPublicKey(), using: .sha1)
    let rootCertData =
    try Certificate.Builder()
      .serialNumber(rootSerialNumber)
      .subject(name: rootName, uniqueID: rootID)
      .subjectAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.ca"))
      .publicKey(keyPair: Self.keyPair, usage: [.keyCertSign, .cRLSign])
      .subjectKeyIdentifier(rootKeyHash)
      .issuer(name: rootName)
      .issuerAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.ca"))
      .basicConstraints(ca: true)
      .valid(for: 86400 * 5)
      .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
      .encoded()
    output(rootCertData)

    let rootCert = try SecCertificate.from(data: rootCertData)

    let certKeyPair = try SecKeyPair.Builder(type: .ec, keySize: 256).generate()
    defer { try? certKeyPair.delete() }

    let certName = try NameBuilder().add("Unit Testing", forTypeName: "CN").name
    let certID = try Random.generate(count: 10)

    let certData =
    try Certificate.Builder()
      .serialNumber(Certificate.Builder.randomSerialNumber())
      .subject(name: certName, uniqueID: certID)
      .subjectAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.cert"))
      .publicKey(keyPair: certKeyPair, usage: [.keyEncipherment, .digitalSignature])
      .computeSubjectKeyIdentifier()
      .issuer(name: rootName)
      .issuerAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.ca"))
      .authorityKeyIdentifier(rootKeyHash, certIssuer: [.directoryName(rootName)], certSerialNumber: rootSerialNumber)
      .valid(for: 86400 * 5)
      .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
      .encoded()
    output(certData)


    let cert = try SecCertificate.from(data: certData)

    let publicKey = try cert.publicKeyValidated(trustedCertificates: [rootCert])

    XCTAssertEqual(try publicKey.encode(), try certKeyPair.publicKey.encode())
  }

  func testValidatedPublicKeyAsync() async throws {

    let rootName = try NameBuilder().add("Unit Testing Root", forTypeName: "CN").name
    let rootID = try Random.generate(count: 10)
    let rootSerialNumber = try Certificate.Builder.randomSerialNumber()
    let rootKeyHash = try Digester.digest(Self.keyPair.encodedPublicKey(), using: .sha1)
    let rootCertData =
    try Certificate.Builder()
      .serialNumber(rootSerialNumber)
      .subject(name: rootName, uniqueID: rootID)
      .subjectAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.ca"))
      .publicKey(keyPair: Self.keyPair, usage: [.keyCertSign, .cRLSign])
      .subjectKeyIdentifier(rootKeyHash)
      .issuer(name: rootName)
      .issuerAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.ca"))
      .basicConstraints(ca: true)
      .valid(for: 86400 * 5)
      .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
      .encoded()
    output(rootCertData)

    let rootCert = try SecCertificate.from(data: rootCertData)

    let certKeyPair = try SecKeyPair.Builder(type: .ec, keySize: 256).generate()
    defer { try? certKeyPair.delete() }

    let certName = try NameBuilder().add("Unit Testing", forTypeName: "CN").name
    let certID = try Random.generate(count: 10)

    let certData =
    try Certificate.Builder()
      .serialNumber(Certificate.Builder.randomSerialNumber())
      .subject(name: certName, uniqueID: certID)
      .subjectAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.cert"))
      .publicKey(keyPair: certKeyPair, usage: [.keyEncipherment, .digitalSignature])
      .computeSubjectKeyIdentifier()
      .issuer(name: rootName)
      .issuerAlternativeNames(names: .dnsName("io.outfoxx.shield.tests.ca"))
      .authorityKeyIdentifier(rootKeyHash, certIssuer: [.directoryName(rootName)], certSerialNumber: rootSerialNumber)
      .valid(for: 86400 * 5)
      .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
      .encoded()
    output(certData)


    let cert = try SecCertificate.from(data: certData)

    let publicKey = try await cert.publicKeyValidated(trustedCertificates: [rootCert])

    XCTAssertEqual(try publicKey.encode(), try certKeyPair.publicKey.encode())
  }

  func testValidatedPublicKeyWithInvalidCertificate() throws {

    let rootName = try NameBuilder().add("Unit Testing Root", forTypeName: "CN").name

    let rootCert = try SecCertificate.from(data:
      try Certificate.Builder()
        .subject(name: rootName)
        .issuer(name: rootName)
        .publicKey(keyPair: Self.keyPair, usage: [.keyCertSign])
        .valid(for: 86400 * 5)
        .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
        .encoded()
    )

    let certKeyPair = try SecKeyPair.Builder(type: .ec, keySize: 256).generate()
    defer { try? certKeyPair.delete() }

    let certName = try NameBuilder().add("Unit Testing", forTypeName: "CN").name

    let cert = try SecCertificate.from(data:
      try Certificate.Builder()
        .subject(name: certName)
        .issuer(name: rootName)
        .publicKey(keyPair: certKeyPair, usage: [.keyEncipherment])
        .valid(for: 86400 * 5)
        .build(signingKey: certKeyPair.privateKey, digestAlgorithm: .sha256)
        .encoded()
    )

    XCTAssertThrowsError(try cert.publicKeyValidated(trustedCertificates: [rootCert]))
  }

  func testValidatedPublicKeyAsyncWithInvalidCertificate() async throws {

    let rootName = try NameBuilder().add("Unit Testing Root", forTypeName: "CN").name

    let rootCert = try SecCertificate.from(data:
      try Certificate.Builder()
        .subject(name: rootName)
        .issuer(name: rootName)
        .publicKey(keyPair: Self.keyPair, usage: [.keyCertSign])
        .valid(for: 86400 * 5)
        .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
        .encoded()
    )

    let certKeyPair = try SecKeyPair.Builder(type: .ec, keySize: 256).generate()
    defer { try? certKeyPair.delete() }

    let certName = try NameBuilder().add("Unit Testing", forTypeName: "CN").name

    let cert = try SecCertificate.from(data:
      try Certificate.Builder()
        .subject(name: certName)
        .issuer(name: rootName)
        .publicKey(keyPair: certKeyPair, usage: [.keyEncipherment])
        .valid(for: 86400 * 5)
        .build(signingKey: Self.keyPair.privateKey, digestAlgorithm: .sha256)
        .encoded()
    )

    do {
      _ = try await cert.publicKeyValidated(trustedCertificates: [rootCert])
      XCTFail("Should have thrown error")
    }
    catch {
      guard let secError = error as? SecCertificateError, secError == .trustValidationFailed else {
        return XCTFail("Incorrect error received: \(error)")
      }
    }
  }

  func output(_ data: Data) {
    guard Self.outputEnabled else { return }
    print(data.base64EncodedString())
  }

}
