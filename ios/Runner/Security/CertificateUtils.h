//
//  CertificateUtils.h
//  FirmaDigital
//
//  Created by administrador on 25/02/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

#define kChosenDigestLength CC_SHA1_DIGEST_LENGTH

@interface CertificateUtils : NSObject {

    SecCertificateRef certificateRef;
    SecKeyRef _publicKey;
    SecKeyRef _privateKey;
    SecIdentityRef _myIdentity;
    NSString *_summaryString;

}

@property (nonatomic) SecKeyRef publicKey;
@property (nonatomic) SecKeyRef privateKey;
@property (nonatomic) SecIdentityRef myIdentity;
@property (retain, nonatomic) NSString *summaryString;
@property (retain, nonatomic) NSData *publicKeyBits;
@property (nonatomic, strong) NSString *selectedCertificateName;
@property (retain, nonatomic) NSString *certificateInBase64;

+ (CertificateUtils *)sharedWrapper;

- (OSStatus)loadCertKeyWithName:(NSString *)certName password:(NSString *)pass fromDocument:(BOOL)saveInDocument;
- (OSStatus)loadCertKeyChainWithName:(NSString *)certName password:(NSString *)pass fromDocument:(BOOL)saveInDocument;
- (BOOL)searchIdentityByName:(NSString *)certificateName;
- (NSData *)getSignatureBytesSHA1:(NSData *)plainText;
- (NSData *)getSignatureBytesSHA256:(NSData *)plainText;
- (NSData *)getSignatureBytesSHA384:(NSData *)plainText;
- (NSData *)getSignatureBytesSHA512:(NSData *)plainText;

@end
