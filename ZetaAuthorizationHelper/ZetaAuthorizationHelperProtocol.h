//
//  ZetaAuthorizationHelperProtocol.h
//  ZetaWatch
//
//  Created by cbreak on 18.01.01.
//  Copyright © 2018 the-color-black.net. All rights reserved.
//

#define kHelperToolMachServiceName @"net.the-color-black.ZetaAuthorizationHelper"

@protocol ZetaAuthorizationHelperProtocol

@required

- (void)getVersionWithReply:(void(^)(NSError * error, NSString * version))reply;

- (void)importPools:(NSDictionary *)importData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;

- (void)importablePoolsWithAuthorization:(NSData*)authData withReply:(void(^)(NSError * error, NSDictionary * importablePools))reply;

- (void)exportPools:(NSDictionary *)exportData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;

- (void)mountFilesystems:(NSDictionary *)mountData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;

- (void)unmountFilesystems:(NSDictionary *)mountData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;

- (void)loadKeyForFilesystem:(NSDictionary *)mountData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;

- (void)scrubPool:(NSDictionary *)poolData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply;

@end
