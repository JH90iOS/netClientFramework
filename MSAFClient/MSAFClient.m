//
//  MSAFClient.m
//  mySteeliphone
//
//  Created by 金华 on 14-5-16.
//  Copyright (c) 2014年 mysteel. All rights reserved.
//

#import "MSAFClient.h"
#import "Reachability.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>


#define MSDefaultBaseURL @"http://192.168.0.0:8080/"

//缓存空间
#define Capacity 1*1024*1024

@interface MSAFClient()
@end

@implementation MSAFClient

+(MSAFClient*)sharedClient{
    static MSAFClient* _sharedClient = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[MSAFClient alloc]initWithBaseURL:[NSURL URLWithString:MSDefaultBaseURL]];
    });
    return _sharedClient;
}


-(id)initWithBaseURL:(NSURL *)url{
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    //注册json解析器
    //    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    
    //accept HTTP header,参照w3文档
    //    [self setDefaultHeader:@"Accept" value:@"application/json"];
    
    //设置SSL策略
    self.defaultSSLPinningMode = AFSSLPinningModeNone;
    
    return  self;
}



//调用：get方式提交
-(void)RequestByGetWithPath:(NSString*)path Parameters:(NSDictionary*)parameters Delegate:(id<MSAFClientDelegate>)delegate SerialNum:(int)serialNum IfUserCache:(BOOL)ifUserCache{
   
    if (self.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        [delegate RequsetFail:@"没有网络，无法连接" SerialNum:serialNum];
        return;
    }

    //baseurl 和 path 拼接时直接拼接，不会加/
    //get的path后如果有参数path ＝ path? ,参数的 valueforkey = key&value
    NSMutableURLRequest *MutableRequest = [self requestWithMethod:@"GET" path:path parameters:parameters];
    
    //1.如果使用缓存
    if (ifUserCache) {
        NSURLCache* urlCache = [NSURLCache sharedURLCache];
        [urlCache setMemoryCapacity:Capacity];
        
        //设置缓存策略
        [MutableRequest setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
        NSURLRequest* request = MutableRequest;
        
        NSCachedURLResponse* response = [urlCache cachedResponseForRequest:request];
        
        //1.0有缓存使用缓存
        if (response != nil) {
            NSString* responseString = [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding];
            NSLog(@"------%@",responseString);

            NSError* error = nil;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:response.data options:NSJSONReadingAllowFragments error:&error];
            
            //成功回调
            [delegate RequestSuccess:(NSDictionary*)jsonObject SerialNum:serialNum];
            
        }
        //1.1没有缓存发送请求
        else{
            
            AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //成功回调
                NSLog(@"=====%@",operation.responseString);
                [delegate RequestSuccess:[self transformToDictionaryFromString:operation.responseString] SerialNum:serialNum];

                
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                //失败回调
                NSLog(@"===%@",[error localizedDescription]);
                [delegate RequsetFail:[error localizedDescription] SerialNum:serialNum];

            }];
            
            [self enqueueHTTPRequestOperation:operation];
        }
        
    }
    
    
    //2.不使用cache直接请求
    else{
        
        [MutableRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        NSURLRequest* request = MutableRequest;
        
        AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
            //成功回调
            NSLog(@"=====%@",operation.responseString);

            [delegate RequestSuccess:[self transformToDictionaryFromString:operation.responseString] SerialNum:serialNum];
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            //失败回调
            [delegate RequsetFail:[error localizedDescription] SerialNum:serialNum];
        }];
        
        [self enqueueHTTPRequestOperation:operation];
    }
    
}



-(NSDictionary*)transformToDictionaryFromString:(NSString*)string{
    
    NSData* jsonData = [string dataUsingEncoding:NSUTF8StringEncoding];

    NSError* error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
    return (NSDictionary*)jsonObject;
    
}

#define encodingType CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)

//上传文件(文件名)
-(void)uploadFileWithFileUrl:(NSString*)fileUrl andParameters:(NSDictionary*)parameters Delegate:(id<MSAFClientDelegate>)delegate{

    NSString* parameterStr = AFQueryStringFromParametersWithEncoding(parameters,encodingType);
    
    NSString* path = [NSString stringWithFormat:@"%@?%@",uploadPath,parameterStr];
    NSLog(@"---%@",path);
    
    NSMutableURLRequest* uploadRequest;
    
    if (fileUrl != nil) {
        
        //解析出文件名
        NSString* fileName = [fileUrl lastPathComponent];
        NSString* name = [fileName stringByDeletingPathExtension];
        
        NSData* data = [NSData dataWithContentsOfFile:fileUrl];
        
        uploadRequest = [self multipartFormRequestWithMethod:@"POST"
                                          path:path
                                    parameters:nil
                     constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                         [formData appendPartWithFileData:data name:name fileName:fileName mimeType:@"multipart/form-data"];
                         
                     }];
    }
    
    else{
        uploadRequest = [self multipartFormRequestWithMethod:@"POST" path:path parameters:nil constructingBodyWithBlock:nil];
    }
    

    NSLog(@"---%@",uploadRequest.URL.absoluteString);
    
    AFHTTPRequestOperation* uploadOperation = [[AFHTTPRequestOperation alloc]initWithRequest:(NSURLRequest*)uploadRequest];
    
    [uploadOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        //成功回调
        NSLog(@"=====%@",operation.responseString);
        [delegate UploadCompeleted:nil];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"=====%@",[error localizedDescription]);
        NSLog(@"------%@",[error.userInfo objectForKey:@"NSLocalizedRecoverySuggestion"]);
        
        [delegate UploadFail:[error localizedDescription]];

    }];
    
//    [uploadOperation start];
    [self enqueueHTTPRequestOperation:uploadOperation];

}


//上传文件(data)
-(void)uploadFileWithData:(NSData*)data andFileName:(NSString*)fileName andParameters:(NSDictionary*)parameters Delegate:(id<MSAFClientDelegate>)delegate{
    
    NSString* parameterStr = AFQueryStringFromParametersWithEncoding(parameters,encodingType);
    
    NSString* path = [NSString stringWithFormat:@"%@?%@",uploadPath,parameterStr];
    NSLog(@"---%@",path);
    
    NSMutableURLRequest* uploadRequest;
    
    if (data != nil) {
        
        //解析出文件名
        NSString* name = [fileName stringByDeletingPathExtension];
        uploadRequest = [self multipartFormRequestWithMethod:@"POST"
                                                        path:path
                                                  parameters:nil
                                   constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                       [formData appendPartWithFileData:data name:name fileName:fileName mimeType:@"multipart/form-data"];
                                       
                                   }];
    }
    
    else{
        uploadRequest = [self multipartFormRequestWithMethod:@"POST" path:path parameters:nil constructingBodyWithBlock:nil];
    }
    
    
    NSLog(@"---%@",uploadRequest.URL.absoluteString);
    
    AFHTTPRequestOperation* uploadOperation = [[AFHTTPRequestOperation alloc]initWithRequest:(NSURLRequest*)uploadRequest];
    
    [uploadOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        //成功回调
        NSLog(@"=====%@",operation.responseString);
        [delegate UploadCompeleted:nil];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"=====%@",[error localizedDescription]);
        NSLog(@"------%@",[error.userInfo objectForKey:@"NSLocalizedRecoverySuggestion"]);
        
        [delegate UploadFail:[error localizedDescription]];
        
    }];
    
    //    [uploadOperation start];
    [self enqueueHTTPRequestOperation:uploadOperation];

}


//下载文件
-(void)downLoadFileWithFileUrl:(NSString*)fileUrl OutPutPath:(NSString*)outPutPath Delegate:(id<MSAFClientDelegate>)delegate{
    
    NSURLRequest *request = [self requestWithMethod:@"GET" path:fileUrl parameters:nil];
    AFHTTPRequestOperation *downLoadOpration = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    
    downLoadOpration.outputStream = [NSOutputStream outputStreamToFileAtPath:outPutPath append:NO];

    [downLoadOpration setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        
        NSLog(@"---%lld",totalBytesRead);
    }];
    
    [downLoadOpration setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"=====%@",operation.responseString);
        [delegate downLoadCompeleted:nil];

        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"=====%@",[error localizedDescription]);
        [delegate downLoadFail:[error localizedDescription]];

    }];
    
    [self enqueueHTTPRequestOperation:downLoadOpration];

}

@end
