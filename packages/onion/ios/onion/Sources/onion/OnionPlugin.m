#import "OnionPlugin.h"

@import IPtProxy;

static NSString *const OnionSnowflakeChannel = @"com.bullbitcoin.onion/snowflake";
static NSLock *OnionSnowflakeLock;
static IPtProxyController *OnionSnowflakeController;
static NSUInteger OnionSnowflakeLeases;

@interface OnionPlugin ()
@property(nonatomic, assign) BOOL acquired;
@end

@implementation OnionPlugin

+ (void)initialize {
  if (self == [OnionPlugin class]) {
    OnionSnowflakeLock = [[NSLock alloc] init];
  }
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:OnionSnowflakeChannel
            binaryMessenger:registrar.messenger];
  OnionPlugin *instance = [[OnionPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"start"]) {
    [self start:result];
  } else if ([call.method isEqualToString:@"stop"]) {
    [self releaseLease];
    result(nil);
  } else if ([call.method isEqualToString:@"version"]) {
    result(IPtProxySnowflakeVersion());
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)dealloc {
  [self releaseLease];
}

- (void)start:(FlutterResult)result {
  [OnionSnowflakeLock lock];
  @try {
    if (self.acquired) {
      long port = [OnionSnowflakeController port:IPtProxySnowflake];
      if ([self validPort:port]) {
        result(@(port));
      } else {
        result([FlutterError errorWithCode:@"snowflake_not_running"
                                   message:@"Snowflake is not running"
                                   details:nil]);
      }
      return;
    }

    if (OnionSnowflakeController == nil) {
      NSURL *support = [[[NSFileManager defaultManager]
          URLsForDirectory:NSApplicationSupportDirectory
                 inDomains:NSUserDomainMask] firstObject];
      NSURL *stateDir = [support URLByAppendingPathComponent:@"onion_pt"
                                                isDirectory:YES];
      NSError *directoryError = nil;
      if (![[NSFileManager defaultManager] createDirectoryAtURL:stateDir
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:&directoryError]) {
        result([FlutterError errorWithCode:@"snowflake_storage"
                                   message:@"Snowflake storage is unavailable"
                                   details:nil]);
        return;
      }

      // Built once per process: IPtProxy registers its transports globally,
      // so a second controller cannot be constructed.
      IPtProxyController *candidate = [[IPtProxyController alloc]
          init:stateDir.path
          enableLogging:NO
          unsafeLogging:NO
          logLevel:@"ERROR"
          transportEvents:nil];
      if (candidate == nil) {
        result([FlutterError errorWithCode:@"snowflake_start_failed"
                                   message:@"Snowflake could not be started"
                                   details:nil]);
        return;
      }
      // A failed Go constructor still yields an object, with no Go value
      // behind it: probe it so the @catch below rejects it instead of keeping
      // it for the rest of the process.
      [candidate port:IPtProxySnowflake];
      OnionSnowflakeController = candidate;
    }

    long port = [OnionSnowflakeController port:IPtProxySnowflake];
    if (![self validPort:port]) {
      NSError *startError = nil;
      if (![OnionSnowflakeController start:IPtProxySnowflake proxy:@"" error:&startError]) {
        result([FlutterError errorWithCode:@"snowflake_start_failed"
                                   message:@"Snowflake could not be started"
                                   details:nil]);
        return;
      }
      port = [OnionSnowflakeController port:IPtProxySnowflake];
      if (![self validPort:port]) {
        [OnionSnowflakeController stop:IPtProxySnowflake];
        result([FlutterError errorWithCode:@"snowflake_start_failed"
                                   message:@"Snowflake did not bind a local port"
                                   details:nil]);
        return;
      }
    }
    OnionSnowflakeLeases++;
    self.acquired = YES;
    result(@(port));
  } @catch (NSException *exception) {
    if (OnionSnowflakeLeases == 0) {
      @try {
        [OnionSnowflakeController stop:IPtProxySnowflake];
      } @catch (__unused NSException *stopException) {
        // Best-effort: the next start begins from a fresh listener.
      }
    }
    result([FlutterError errorWithCode:@"snowflake_start_failed"
                               message:@"Snowflake could not be started"
                               details:nil]);
  } @finally {
    [OnionSnowflakeLock unlock];
  }
}

- (void)releaseLease {
  [OnionSnowflakeLock lock];
  @try {
    if (!self.acquired) {
      return;
    }
    self.acquired = NO;
    OnionSnowflakeLeases--;
    if (OnionSnowflakeLeases == 0 && OnionSnowflakeController != nil) {
      @try {
        [OnionSnowflakeController stop:IPtProxySnowflake];
      } @catch (__unused NSException *exception) {
        // Teardown is best-effort during engine detachment; the controller
        // is kept for the next start.
      }
    }
  } @finally {
    [OnionSnowflakeLock unlock];
  }
}

- (BOOL)validPort:(long)port {
  return port > 0 && port <= UINT16_MAX;
}

@end
