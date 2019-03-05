//
//  ViewController.m
//  Coobjc
//
//  Created by Kira on 2019/3/3.
//  Copyright © 2019 Kira. All rights reserved.
//

#import "ViewController.h"
#import <coobjc/coobjc.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self testForLaunch];
//    [self testForChannelWithNoCache];
//    [self testForAwaitPromise];
//    [self testForAwaitChan];
//    [self testForRandomGenerator];
//    [self testForActor];
}

#pragma mark Launch

- (void)testForLaunch {
    co_launch(^{
        NSLog(@"deal things in coroutine 1");
    });
    
    co_launch_now(^{
        NSLog(@"deal things in coroutine now");
    });
    
    co_launch(^{
        NSLog(@"deal things in coroutine 2");
    });
    NSLog(@"testForLaunch");
}

#pragma mark Channel
- (void)testForChannelWithNoCache {
    COChan *ch1 = [COChan chan];
    
    co_launch(^{
        NSLog(@"deal things before in coroutine 1");
        // 如果使用 receive/send？
        id ret = [ch1 receive];
        NSLog(@"get value from chanel 1: %d",[ret intValue]);
        NSLog(@"deal things after in coroutine 1");
    });
    
    co_launch(^{
        NSLog(@"deal things before in coroutine 2");
        [ch1 send:@(1)];
        NSLog(@"write value to chanel 2");
        NSLog(@"deal things after in coroutine 2");
    });
    
    NSLog(@"testForChannelWithNoCache");
}


#pragma mark Await

/// COPromise
- (COPromise<id> *)co_fetchSomethingAsynchronous {
    
    return [COPromise promise:^(COPromiseFullfill  _Nonnull fullfill, COPromiseReject  _Nonnull reject) {
        NSError *error = nil;
        int number = arc4random() % 2;
        if (number) {
            NSLog(@"result is %d,spend some time to deal it..",number);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                fullfill(@(number));
            });
        } else {
            NSLog(@"result is %d,throw out an error.",number);
            error = [NSError errorWithDomain:@"error" code:10000 userInfo:nil];
            reject(error);
        }
    } onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (void)testForAwaitPromise {
    co_launch(^{
        id ret = await([self co_fetchSomethingAsynchronous]);
        NSError *error = co_getError();
        
        if (error) {
            NSLog(@"get an error in testForAwait, error: %@",error);
        } else {
            NSLog(@"get the result in testForAwait,value:%d",[ret intValue]);
        }
    });
}


/// COChan
- (COChan<id> *)co_fetchSomething {
    COChan *chan = [COChan chan];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        int number = arc4random() % 2;
        if (number) {
            NSLog(@"result is %d",number);
            //??? 如果使用send？
            [chan send_nonblock:@(number)];
        } else {
            NSLog(@"result is %d,throw out an error.",number);
            error = [NSError errorWithDomain:@"error" code:10000 userInfo:nil];
            [chan send_nonblock:error];
        }
    });
    return chan;
}

- (COChan<id> *)co_fetchSomething1 {
    COChan *chan = [COChan chan];
    co_launch(^{
        NSError *error = nil;
        int number = arc4random() % 2;
        if (number) {
            NSLog(@"result is %d",number);
            //??? 如果使用send？
            [chan send:@(number)];
        } else {
            NSLog(@"result is %d,throw out an error.",number);
            error = [NSError errorWithDomain:@"error" code:10000 userInfo:nil];
            [chan send:error];
        }
    });
    return chan;
}

- (void)testForAwaitChan {
    co_launch(^{
        id ret = await([self co_fetchSomething]);
        if ([ret isKindOfClass:[NSError class]]) {
            NSLog(@"get an error in testForAwaitChan, error: %@",ret);
        } else {
            NSLog(@"get the result in testForAwaitChan,value:%d",[ret intValue]);
        }
    });
}

#pragma mark Generator

- (void)testForRandomGenerator {
    COCoroutine *generator = co_sequence(^{
        NSArray *array = @[@"🍎",@"🐶",@"🤖️",@"✈️"];
        while(1){
            int index = arc4random() % array.count;
            NSString *result = [array objectAtIndex:index];
            NSLog(@"this is a %@",result);
            yield_val(result);
        }
    });
    
    [generator setFinishedBlock:^{
        NSLog(@"generator is killed!");
    }];
    
    co_launch(^{
        for(int i = 0; i < 10; i++){
            NSString *whatIsThis = [generator next];
            NSLog(@"look, what I get in the box! %@",whatIsThis);
        }
        [generator cancel];
    });
}


#pragma mark Actor

- (void)testForActor {
    COActor *countActor = co_actor(^(COActorChan * _Nonnull channel) {
        //定义actor的状态变量
        int count = 0;
        for (COActorMessage *message in channel) {
            //处理消息
            if ([[message stringType] isEqualToString:@"inc"]) {
                count++;
                NSLog(@"the count is %d now.", count);
            }
            else if ([[message stringType] isEqualToString:@"get"]) {
                message.complete(@(count));
                NSLog(@"get the count %d", count);
            }
        }
    });
    
//     给 actor 发送消息
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [countActor sendMessage:@"inc"];
        [countActor sendMessage:@"inc"];
//    });

    id value = [countActor sendMessage:@"get"].value;
    NSLog(@"the Actor count now is %d",[value intValue]);

//    co_launch(^{
//        id ret = await([countActor sendMessage:@"get"]);
//        NSLog(@"the Actor count now is %d",[ret intValue]);
//    });
}

@end
