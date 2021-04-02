#import "WifiWizard2.h"
#include <ifaddrs.h>
#import <net/if.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>  
#include <sys/socket.h>
#include <netinet/in.h> 

@implementation WifiWizard2

- (id)fetchSSIDInfo {
    // see http://stackoverflow.com/a/5198968/907720
    NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    NSLog(@"Supported interfaces: %@", ifs);
    NSDictionary *info;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        NSLog(@"%@ => %@", ifnam, info);
        if (info && [info count]) { break; }
    }
    return info;
}

- (BOOL) isWiFiEnabled {
    // see http://www.enigmaticape.com/blog/determine-wifi-enabled-ios-one-weird-trick
    NSCountedSet * cset = [NSCountedSet new];

    struct ifaddrs *interfaces = NULL;
    // retrieve the current interfaces - returns 0 on success
    int success = getifaddrs(&interfaces);
    if(success == 0){
        for( struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
            if ( (interface->ifa_flags & IFF_UP) == IFF_UP ) {
                [cset addObject:[NSString stringWithUTF8String:interface->ifa_name]];
            }
        }
    }

    freeifaddrs(interfaces);

    return [cset countForObject:@"awdl0"] > 1 ? YES : NO;
}

- (void)iOSConnectNetwork:(CDVInvokedUrlCommand*)command {
    
    __block CDVPluginResult *pluginResult = nil;

	NSString * ssidString;
	NSString * passwordString;
	NSDictionary* options = [[NSDictionary alloc]init];

	options = [command argumentAtIndex:0];
	ssidString = [options objectForKey:@"Ssid"];
	passwordString = [options objectForKey:@"Password"];

    if([self isVPNOn]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Using VPN"];
        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
        return;
    }

	if (@available(iOS 11.0, *)) {
	    if (ssidString && [ssidString length]) {
			NEHotspotConfiguration *configuration = [[NEHotspotConfiguration
				alloc] initWithSSID:ssidString 
					passphrase:passwordString 
						isWEP:(BOOL)false];

			configuration.joinOnce = false;
            
            [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
                
                NSDictionary *r = [self fetchSSIDInfo];
                
                NSString *ssid = [r objectForKey:(id)kCNNetworkInfoKeySSID]; //@"SSID"
                
                if ([ssid isEqualToString:ssidString]){
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:ssidString];
                }else{
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
                }
                [self.commandDelegate sendPluginResult:pluginResult
                                            callbackId:command.callbackId];
            }];


		} else {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"SSID Not provided"];
            [self.commandDelegate sendPluginResult:pluginResult
                                        callbackId:command.callbackId];
		}
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS 11+ not available"];
        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
	}


}

- (void)iOSConnectOpenNetwork:(CDVInvokedUrlCommand*)command {

    __block CDVPluginResult *pluginResult = nil;

    NSString * ssidString;
    NSDictionary* options = [[NSDictionary alloc]init];

    options = [command argumentAtIndex:0];
    ssidString = [options objectForKey:@"Ssid"];

    if (@available(iOS 11.0, *)) {
        if (ssidString && [ssidString length]) {
            NEHotspotConfiguration *configuration = [[NEHotspotConfiguration
                    alloc] initWithSSID:ssidString];

            configuration.joinOnce = false;

            [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {

                NSDictionary *r = [self fetchSSIDInfo];

                NSString *ssid = [r objectForKey:(id)kCNNetworkInfoKeySSID]; //@"SSID"

                if ([ssid isEqualToString:ssidString]){
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:ssidString];
                }else{
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
                }
                [self.commandDelegate sendPluginResult:pluginResult
                                            callbackId:command.callbackId];
            }];


        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"SSID Not provided"];
            [self.commandDelegate sendPluginResult:pluginResult
                                        callbackId:command.callbackId];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS 11+ not available"];
        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
    }


}

- (void)iOSDisconnectNetwork:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;

	NSString * ssidString;
	NSDictionary* options = [[NSDictionary alloc]init];

	options = [command argumentAtIndex:0];
	ssidString = [options objectForKey:@"Ssid"];

	if (@available(iOS 11.0, *)) {
	    if (ssidString && [ssidString length]) {
			[[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssidString];
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:ssidString];
		} else {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"SSID Not provided"];
		}
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS 11+ not available"];
	}

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)getConnectedSSID:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    NSDictionary *r = [self fetchSSIDInfo];

    NSString *ssid = [r objectForKey:(id)kCNNetworkInfoKeySSID]; //@"SSID"

    if (ssid && [ssid length]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:ssid];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not available"];
    }

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)getConnectedBSSID:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    NSDictionary *r = [self fetchSSIDInfo];
    
    NSString *bssid = [r objectForKey:(id)kCNNetworkInfoKeyBSSID]; //@"SSID"
    
    if (bssid && [bssid length]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:bssid];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not available"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)isWifiEnabled:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    NSString *isWifiOn = [self isWiFiEnabled] ? @"1" : @"0";

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:isWifiOn];

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)setWifiEnabled:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)scan:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

// Android functions

- (void)addNetwork:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)removeNetwork:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)androidConnectNetwork:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)androidDisconnectNetwork:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)listNetworks:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)getScanResults:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)startScan:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)disconnect:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)isConnectedToInternet:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)canConnectToInternet:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)canPingWifiRouter:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)canConnectToRouter:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not supported"];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)iOSNetworkPermission:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    NSString *result = [self triggerLocalNetworkPrivacyAlertObjC] ? @"1" : @"0";

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:result];

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

static NSArray<NSData *> * addressesOfDiscardServiceOnBroadcastCapableInterfaces(void) {
    struct ifaddrs * addrList = NULL;
    int err = getifaddrs(&addrList);
    if (err != 0) {
        return @[];
    }
    NSMutableArray<NSData *> * result = [NSMutableArray array];
    for (struct ifaddrs * cursor = addrList; cursor != NULL; cursor = cursor->ifa_next) {
        if ( (cursor->ifa_flags & IFF_BROADCAST) &&
             (cursor->ifa_addr != NULL)
           ) {
            switch (cursor->ifa_addr->sa_family) {
            case AF_INET: {
                struct sockaddr_in sin = *(struct sockaddr_in *) cursor->ifa_addr;
                sin.sin_port = htons(9);
                NSData * addr = [NSData dataWithBytes:&sin length:sizeof(sin)];
                [result addObject:addr];
            } break;
            case AF_INET6: {
                struct sockaddr_in6 sin6 = *(struct sockaddr_in6 *) cursor->ifa_addr;
                sin6.sin6_port = htons(9);
                NSData * addr = [NSData dataWithBytes:&sin6 length:sizeof(sin6)];
                [result addObject:addr];
            } break;
            default: {
                // do nothing
            } break;
            }
        }
    }
    freeifaddrs(addrList);
    return result;
}
- (BOOL)  triggerLocalNetworkPrivacyAlertObjC {
    int sock4 = socket(AF_INET, SOCK_DGRAM, 0);
    int sock6 = socket(AF_INET, SOCK_DGRAM, 0);
    
    if ((sock4 >= 0) && (sock6 >= 0)) {
        char message = '!';
        NSArray<NSData *> * addresses = addressesOfDiscardServiceOnBroadcastCapableInterfaces();
        for (NSData * address in addresses) {
            int sock = ((const struct sockaddr *) address.bytes)->sa_family == AF_INET ? sock4 : sock6;
            (void) sendto(sock, &message, sizeof(message), MSG_DONTWAIT, address.bytes, (socklen_t) address.length);
        }
    }
}

- (BOOL)isVPNOn
{
    BOOL flag = NO;
    NSString *version = [UIDevice currentDevice].systemVersion;
    // need two ways to judge this.
    if (version.doubleValue >= 9.0)
    {
        NSDictionary *dict = CFBridgingRelease(CFNetworkCopySystemProxySettings());
        NSArray *keys = [dict[@"__SCOPED__"] allKeys];
        for (NSString *key in keys) {
            if ([key rangeOfString:@"tap"].location != NSNotFound ||
                [key rangeOfString:@"tun"].location != NSNotFound ||
                [key rangeOfString:@"ipsec"].location != NSNotFound ||
                [key rangeOfString:@"ppp"].location != NSNotFound){
                flag = YES;
                break;
            }
        }
    }
    else
    {
        struct ifaddrs *interfaces = NULL;
        struct ifaddrs *temp_addr = NULL;
        int success = 0;

        // retrieve the current interfaces - returns 0 on success
        success = getifaddrs(&interfaces);
        if (success == 0)
        {
            // Loop through linked list of interfaces
            temp_addr = interfaces;
            while (temp_addr != NULL)
            {
                NSString *string = [NSString stringWithFormat:@"%s" , temp_addr->ifa_name];
                if ([string rangeOfString:@"tap"].location != NSNotFound ||
                    [string rangeOfString:@"tun"].location != NSNotFound ||
                    [string rangeOfString:@"ipsec"].location != NSNotFound ||
                    [string rangeOfString:@"ppp"].location != NSNotFound)
                {
                    flag = YES;
                    break;
                }
                temp_addr = temp_addr->ifa_next;
            }
        }

        // Free memory
        freeifaddrs(interfaces);
    }

    return flag;
}


@end
