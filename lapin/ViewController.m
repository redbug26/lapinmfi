//
//  ViewController.m
//  lapin
//
//  Created by Miguel Vanhove on 11/11/2022.
//

#import "ViewController.h"
#import <GameController/GameController.h>
#import <CoreHaptics/CoreHaptics.h>

#include "ds3activate.h"

ViewController *globalViewController;


@interface ViewController ()
{
    IBOutlet UITextView *textView;
    NSMutableArray *controllers;

    int maxid;
    NSMutableDictionary *ids;

    IBOutlet UIToolbar *toolbar;
    CHHapticEngine* engine;

}

@end

@implementation ViewController

- (NSString *) getIDForController:(GCController *)myController {

    if ([[ids allKeysForObject:myController] count] == 0) {
        maxid++;
        [ids setObject:myController forKey:[NSString stringWithFormat:@"#%02X", maxid]];
    }

    return [ids allKeysForObject:myController][0];
}

- (NSInteger) getIntegerIDForController:(GCController *)myController {
    unsigned result = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[self getIDForController:myController]];
    
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&result];
    
    return result;
}

#if TARGET_OS_MACCATALYST

- (IBAction)activateDS:(id)sender {
    [self log:@"Asking to activate DS3"];
    
    ds3activate_main();
}

#endif

#pragma mark - Haptic

- (IBAction)doHaptic:(id)sender {
    UIBarButtonItem *item = sender;
        
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction *action) {}];

    [alert addAction:defaultAction];

    NSString * resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString * documentsPath = [resourcePath stringByAppendingPathComponent:@"AHAP"];

    NSError * error;
    NSArray * directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsPath error:&error];
    
    
    for(NSString *ahapFile in directoryContents) {
        
        NSRange range = [ahapFile rangeOfString:@".ahap"];
        
        if (range.location != NSNotFound) {
            NSString *title =[ahapFile stringByReplacingCharactersInRange:range withString:@""];
            
            
            UIAlertAction *downloadFileAction = [UIAlertAction actionWithTitle:title
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction *action) {
               
                
                NSString *filename = [documentsPath stringByAppendingFormat:@"/%@.ahap", action.title];

                
                NSError *error = nil;
                
                GCController *controller = [self->ids objectForKey:[NSString stringWithFormat:@"#%02X", (int)item.tag]];
                
                self->engine = [controller.haptics createEngineWithLocality:GCHapticsLocalityDefault];
                
                [self->engine playPatternFromURL:[NSURL fileURLWithPath:filename] error:&error];
                 if (error) {
                     [self log:@"%@", error.localizedDescription];
                 }
                
                [self->engine startAndReturnError:&error];

                
                [self log:@"Run %@ on #%02X", action.title, item.tag];
                //        [self downloadFile];
            }];
            
            
            [alert addAction:downloadFileAction];
        }
    }

    [self presentViewController:alert animated:true completion:nil];

}

#pragma mark - GamePad

- (void) gameControllerLoad
{
    NSString *dateStr = [NSString stringWithUTF8String:__DATE__];
    NSString *timeStr = [NSString stringWithUTF8String:__TIME__];

    controllers = [[NSMutableArray alloc] initWithCapacity:5];
    ids = [[NSMutableDictionary alloc] initWithCapacity:5];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidConnectNotification:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidDisconnectNotification:) name:GCControllerDidDisconnectNotification object:nil];

    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];

    [self setupControllers:self];

    maxid = 0;

    [self log:@"Lapin GameController testing machine v0.2 (%@ %@)", dateStr, timeStr];
    [self log:@"  by RedBug/Kyuran"];
    [self log:@""];

    [self log:@"Waiting for controller"];
} /* gameControllerLoad */

- (void) gameControllerUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GCControllerDidDisconnectNotification object:nil];

}

// - (void)gcPressed:(BOOL)pressed forKey:(SPHeroMove)key forPlayer:(NSInteger)player
// {
//    if (self->gcTouchStatus[player][key] != pressed) {
//        self->gcTouchStatus[player][key] = pressed;
//        [self keyPress:pressed forKey:key forPlayer:player];
//
//        if (key == SPHMBtnMenu) {
//            self->gcTouchStatus[player][key] = false;
//            [self keyPress:false forKey:key forPlayer:player];
//        }
//    }
// }

- (void) controllerDidConnectNotification:(id)sender {
    [textView insertText:@"Connection\n"];

    [self setupControllers:self];

}

- (void) controllerDidDisconnectNotification:(id)sender {
    [textView insertText:@"Disconnection\n"];

    [self setupControllers:self];
}


- (void) log:(NSString *)format, ...
{

    va_list args;

    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    [textView insertText:s];
    [textView insertText:@"\n"];

    if (textView.text.length > 0 ) {
        NSRange bottom = NSMakeRange(textView.text.length - 1, 1);
        [textView scrollRangeToVisible:bottom];
    }

}

// - (void)gcPressed:(BOOL)pressed forKey:(SPHeroMove)key forPlayer:(NSInteger)player
// {
//    if (self->gcTouchStatus[player][key] != pressed) {
//        self->gcTouchStatus[player][key] = pressed;
//        [self keyPress:pressed forKey:key forPlayer:player];
//
//        if (key == SPHMBtnMenu) {
//            self->gcTouchStatus[player][key] = false;
//            [self keyPress:false forKey:key forPlayer:player];
//        }
//    }
// }

- (void) setupController:(GCController *)myController {

    // TODO: handle playerindex

    if ([myController extendedGamepad]) {
        myController.extendedGamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad *_Nonnull dpad, float xValue, float yValue) {
            [self log:@"%@ \"%@\" dpad: %f,%f",   [self getIDForController:myController], dpad.localizedName, xValue, yValue];
        };

        myController.extendedGamepad.buttonA.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonA:%d %f", [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.buttonB.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonB:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.buttonX.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonX:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.buttonY.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonY:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.buttonMenu.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonMenu:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.buttonOptions.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonOptions:%d %f", [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.buttonHome.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonHome:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.leftShoulder.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" leftShoulder:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.rightShoulder.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" rightShoulder:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.leftTrigger.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" leftTrigger:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.rightTrigger.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" rightTrigger:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };

        myController.extendedGamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
            [self log:@"%@ \"%@\" leftThumbstick: %f,%f",  [self getIDForController:myController], dpad.localizedName, xValue, yValue];
        };
        myController.extendedGamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
            [self log:@"%@ \"%@\" rightThumbstick: %f,%f",  [self getIDForController:myController], dpad.localizedName, xValue, yValue];
        };
        myController.extendedGamepad.rightThumbstickButton.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" rightThumbstickButton:%d %f", [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.extendedGamepad.leftThumbstickButton.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" leftThumbstickButton:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };

        if ([[myController extendedGamepad] isKindOfClass:[GCDualShockGamepad class]]) {
            GCDualShockGamepad *dualShock = (GCDualShockGamepad *)myController.extendedGamepad;

            dualShock.touchpadButton.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" touchpadButton:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };

            dualShock.touchpadPrimary.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [self log:@"%@ \"%@\" touchpadPrimary: %f,%f",  [self getIDForController:myController], dpad.localizedName, xValue, yValue];
            };

            dualShock.touchpadSecondary.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [self log:@"%@ \"%@\" touchpadSecondary: %f,%f",  [self getIDForController:myController], dpad.localizedName, xValue, yValue];
            };
        }
        if ([[myController extendedGamepad] isKindOfClass:[GCXboxGamepad class]]) {
            GCXboxGamepad *xbox = (GCXboxGamepad *)myController.extendedGamepad;

            xbox.paddleButton1.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" paddleButton1:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };
            xbox.paddleButton2.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" paddleButton2:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };
            xbox.paddleButton3.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" paddleButton3:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };
            xbox.paddleButton4.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" paddleButton4:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };
            xbox.buttonShare.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" buttonShare:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };
        }
        if ([[myController extendedGamepad] isKindOfClass:[GCDualSenseGamepad class]]) {
            GCDualSenseGamepad *dualSense = (GCDualSenseGamepad *)myController.extendedGamepad;

            dualSense.touchpadButton.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
                [self log:@"%@ \"%@\" touchpadButton:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
            };

            dualSense.touchpadPrimary.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [self log:@"%@ \"%@\" touchpadPrimary: %f,%f",  [self getIDForController:myController], dpad.localizedName, xValue, yValue];
            };

            dualSense.touchpadSecondary.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [self log:@"%@ \"%@\" touchpadSecondary: %f,%f",  [self getIDForController:myController], dpad.localizedName, xValue, yValue];
            };
        }

        if ([[myController extendedGamepad] isKindOfClass:[GCDualSenseGamepad class]]) {
            //                [self log:@"DualSenseGamepad"];
        }


        // Micro Gamepad aka Apple TV Remote
    } else if ([myController microGamepad]) {

        myController.microGamepad.dpad.left.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" left:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.microGamepad.dpad.right.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" right:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.microGamepad.dpad.up.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" up:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.microGamepad.dpad.down.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" down:%d %f", [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.microGamepad.buttonA.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonA:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
        myController.microGamepad.buttonX.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonX:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };

        myController.microGamepad.buttonMenu.valueChangedHandler =  ^(GCControllerButtonInput *button, float value, BOOL pressed) {
            [self log:@"%@ \"%@\" buttonMenu:%d %f",  [self getIDForController:myController], button.localizedName, pressed, value];
        };
    }
    ;

    [self log:@"%@ Controller found %@ (%@) - playerIndex:%d ", [self getIDForController:myController], myController.vendorName, myController.productCategory, myController.playerIndex];

    if ([myController extendedGamepad]) {
        [self log:@"  Type extendedGamepad"];
        if ([[myController extendedGamepad] isKindOfClass:[GCDualShockGamepad class]]) {
            [self log:@"  Subtype DualShockGamepad"];
        }
        if ([[myController extendedGamepad] isKindOfClass:[GCXboxGamepad class]]) {
            [self log:@"  Subtype XboxGamepad"];
        }
        if ([[myController extendedGamepad] isKindOfClass:[GCDualSenseGamepad class]]) {
            [self log:@"  Subtype DualSenseGamepad"];
        }
    } else if ([myController microGamepad]) {
        [self log:@"  Type microGamepad"];
    }

    if (myController.haptics != nil) {
        [self log:@"  Haptics found"];
        
        NSString *title = [NSString stringWithFormat:@"%@ Haptic", [self getIDForController:myController]];
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(doHaptic:)];
        item.tag =[self getIntegerIDForController:myController];
        NSMutableArray *items = [[NSMutableArray alloc] initWithArray:toolbar.items];
        [items addObject:item];
        [toolbar setItems:items animated:YES];

    }

    if (myController.light != nil) {
        [self log:@"  Light found (actually: #%02X%02X%02X)", (int)(myController.light.color.red * 255.0), (int)(myController.light.color.green * 255.0), (int)(myController.light.color.blue * 255.0)];
    }


    if (myController.battery != nil) {
        NSString *state = nil;
        if (myController.battery.batteryState == GCDeviceBatteryStateDischarging) {
            state = @"Discharging";
        } else if (myController.battery.batteryState == GCDeviceBatteryStateCharging) {
            state = @"Charging";
        } else if (myController.battery.batteryState == GCDeviceBatteryStateFull) {
            state = @"Full";
        } else {
            state = @"Unknown";
        }

        [self log:@"  Battery level:%d%% state:%@", (int)(myController.battery.batteryLevel * 100.0), state];
    }


} /* setupController */

- (void) setupControllers:(id)sender
{
    NSMutableArray *foundControllers = [[NSMutableArray alloc] initWithCapacity:5];


    for (GCController *controller in [GCController controllers]) {
        [foundControllers addObject:controller];

        if ([controllers indexOfObject:controller] == NSNotFound) {
            [controllers addObject:controller];
            [self setupController:controller];
        }
    }
    
    BOOL updateMenu=false;
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:toolbar.items];

    for (GCController *controller in controllers) {
        if ([foundControllers indexOfObject:controller] == NSNotFound) {
            [controllers removeObject:controller];
            
            // Remove haptic from menu
            NSString *title = [NSString stringWithFormat:@"%@ Haptic", [self getIDForController:controller]];
            for (UIBarButtonItem *item in items) {
                if ([item.title isEqualToString:title]) {
                    [items removeObject:item];
                    updateMenu=true;
                }
            }
        }
    }
    
    if (updateMenu) {
        [toolbar setItems:items animated:YES];
    }


} /* setupControllers */


- (void) viewDidLoad {
    [super viewDidLoad];

    globalViewController = self;

#if TARGET_OS_MACCATALYST

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"DS3" style:UIBarButtonItemStylePlain target:self action:@selector(activateDS:)];
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:toolbar.items];
    [items addObject:item];
    [toolbar setItems:items animated:YES];
#endif
    
    [self gameControllerLoad];
    // Do any additional setup after loading the view.
}


@end




void cLog(const char *fmt, ...) {
    
    char tmp[512];

      va_list args;

      va_start(args, fmt);
      vsprintf(tmp, fmt, args);
      va_end(args);

    [globalViewController log:@"%s", tmp];
    
}
