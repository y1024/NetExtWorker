//
//  ViewController.m
//  NetExtWorker
//
//  Created by Xuan Liu on 6/29/16.
//  Copyright © 2016 App Annie. All rights reserved.
//

#import "ViewController.h"
#import "NetWorkService.h"
#import "CocoaAsyncSocket.h"
#import "AFNetworking.h"

@interface ViewController () <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>
// UI components
@property (weak, nonatomic) IBOutlet UIButton *testHTTPButton;
@property (weak, nonatomic) IBOutlet UIButton *testTCPButton;
@property (weak, nonatomic) IBOutlet UIButton *testUDPButton;
@property (weak, nonatomic) IBOutlet UIButton *testAllButton;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;

// button handlers
- (IBAction)testHTTPHandler:(id)sender;
- (IBAction)testUDPHandler:(id)sender;
- (IBAction)testTCPHandler:(id)sender;
- (IBAction)testALLHandler:(id)sender;
- (IBAction)stopHandler:(id)sender;

// properties
@property (strong, nonatomic) GCDAsyncSocket *tcpSocket;
@property (strong, nonatomic) GCDAsyncUdpSocket *udpSocket;
@property (strong, nonatomic) AFHTTPSessionManager *manager;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
//@property (strong, atomic) BOOL stop;

@end

@implementation ViewController {
    BOOL _stop;
    NSInteger _httpCount;
    NSInteger _tcpCount;
    NSInteger _udpCount;
    NSInteger _maxCount;
}

//@synthesize stop = _stop;

- (void)dealloc {
    [self disconnectAll];
}

- (void)disconnectAll {
    [self.tcpSocket disconnect];
    [self.udpSocket close];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self createClients];
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateFormat = @"hh:mm:ss";
    _stop = false;
    _maxCount = 1;
    _httpCount = 0;
    _tcpCount = 0;
    _udpCount = 0;
}

- (void)createClients {
    self.tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
}

- (NSData *)dataFromMessage:(NSString *)message {
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)stringFromData:(NSData *)data {
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)displayMessage:(NSString *)message {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.messageLabel.text = message;
    });
}

- (IBAction)testHTTPHandler:(id)sender {
    if (_stop) {
        _stop = false;
    }
    if (_httpCount < _maxCount) {
        [self testHTTPTraffic];
        _httpCount += 1;
    }
}

- (void)testHTTPTraffic {
    __weak typeof(self) weakSelf = self;
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    NSURL * url = [NSURL URLWithString:@"http://192.168.1.195:8080"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!_stop) {
            @autoreleasepool {
                [weakSelf sendHTTPGet:defaultSession url:url];
                sleep(2);
            }
        }
    });
}

- (void)sendHTTPGet:(NSURLSession *)session url:(NSURL *)url
{
    NSURLSessionDataTask * dataTask = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
        if(error == nil) {
            [self displayMessage:[NSString stringWithFormat:@"[%@]: receive HTTP GET", dateString]];
        } else {
            [self displayMessage:[NSString stringWithFormat:@"[%@]: HTTP GET Error: %@", dateString, error]];
        }
    }];
    [dataTask resume];
}

- (IBAction)testTCPHandler:(id)sender {
    if (_stop)
        _stop = NO;
    if (_tcpCount < _maxCount) {
        [self testTCPTraffic];
        _tcpCount += 1;
    }
}

- (void)testTCPTraffic {
    NSData *data = [self dataFromMessage:@"hello world"];
    __weak typeof(self) weakSelf = self;
    NSError *error = nil;
    if (!self.tcpSocket.isConnected) 
        [weakSelf.tcpSocket connectToHost:@"192.168.1.195" onPort:31500 error:&error];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!_stop) {
            [weakSelf.tcpSocket writeData:data withTimeout:-1 tag:0];
            [weakSelf.tcpSocket readDataWithTimeout:-1 tag:0];
            sleep(2);
        }
    });
}

- (IBAction)testUDPHandler:(id)sender {
    if (_stop)
        _stop = NO;
    if (_udpCount < _maxCount) {
        [self testUDPTraffic];
        _udpCount += 1;
    }
}

- (void)testUDPTraffic {
    NSData *data = [self dataFromMessage:@"hello world"];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!_stop) {
            [weakSelf.udpSocket sendData:data toHost:@"192.168.1.195" port:31600 withTimeout:-1 tag:0];
            NSError *reError = nil;
            [weakSelf.udpSocket receiveOnce:&reError];
            sleep(2);
        }
    });
}

- (IBAction)testALLHandler:(id)sender {
    [self testHTTPHandler:nil];
    [self testTCPHandler:nil];
    [self testUDPHandler:nil];
}

- (IBAction)stopHandler:(id)sender {
    _stop = true;
    _httpCount = 0;
    _tcpCount = 0;
    _udpCount = 0;
    [self disconnectAll];
}

#pragma mark - GCDAsyncSocketDelegate
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *dataString = [self stringFromData:data];
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    [self displayMessage:[NSString stringWithFormat:@"[%@]: receive TCP: %@", dateString, dataString]];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    [self displayMessage:[NSString stringWithFormat:@"[%@]: %@", dateString, err]];
}

#pragma mark - GCDAsyncUdpSocketDelegate
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    NSString *dataString = [self stringFromData:data];
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    [self displayMessage:[NSString stringWithFormat:@"[%@]: receive UDP: %@", dateString, dataString]];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    [self displayMessage:[NSString stringWithFormat:@"[%@]: %@", dateString, error]];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    [self displayMessage:[NSString stringWithFormat:@"[%@]: %@", dateString, error]];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    [self displayMessage:[NSString stringWithFormat:@"[%@]: %@", dateString, error]];
}

@end
