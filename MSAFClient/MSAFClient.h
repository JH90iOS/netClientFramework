//
//  MSAFClient.h
//  mySteeliphone
//
//  Created by 金华 on 14-5-16.
//  Copyright (c) 2014年 mysteel. All rights reserved.
//

#import "AFHTTPClient.h"

#define POST @"post"
#define GET @"get"

@protocol MSAFClientDelegate

//成功回调
@optional -(void)RequestSuccess:(NSDictionary*)responceDic SerialNum:(int)serialNum;

//失败回调
@optional -(void)RequsetFail:(NSString*)errorString SerialNum:(int)serialNum;

//上传文件失败
@optional -(void)UploadFail:(NSString*)errorString;

//上传文件成功
@optional -(void)UploadCompeleted:(NSString*)result;

//下载文件成功
@optional -(void)downLoadCompeleted:(NSString*)result;

//下载文件失败
@optional -(void)downLoadFail:(NSString*)errorString;
@end


@interface MSAFClient : AFHTTPClient

@property (weak) id<MSAFClientDelegate> delegate;
@property (nonatomic)BOOL hasNetWork;

+(MSAFClient*)sharedClient;


//发送请求调用，get方式
-(void)RequestByGetWithPath:(NSString*)path Parameters:(NSDictionary*)parameters Delegate:(id<MSAFClientDelegate>)delegate SerialNum:(int)serialNum IfUserCache:(BOOL)ifUserCache;

//上传文件(路径)
-(void)uploadFileWithFileUrl:(NSString*)fileUrl andParameters:(NSDictionary*)parameters Delegate:(id<MSAFClientDelegate>)delegate;

//上传文件(data)
-(void)uploadFileWithData:(NSData*)data andFileName:(NSString*)name andParameters:(NSDictionary*)parameters Delegate:(id<MSAFClientDelegate>)delegate;

//下载文件
-(void)downLoadFileWithFileUrl:(NSString*)fileUrl OutPutPath:(NSString*)outPutPath Delegate:(id<MSAFClientDelegate>)delegate;

@end
