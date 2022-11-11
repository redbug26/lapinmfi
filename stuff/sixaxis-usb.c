/*
 * sixaxis-usb
 *
 * PLAYSTATION 3 "SIXAXIS" USB tool for Mac OS X
 *
 * Shinichiro Oba <ooba@bricklife.com>
 *
 * 2007-06-05  v0.1
 */
                
#include <stdio.h>

#include <mach/mach.h>

#include <CoreFoundation/CFNumber.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#define SIXAXIS_VENDOR_ID       0x054c
#define SIXAXIS_PRODUCT_ID      0x0268

#define SIXAXIS_USB_MODE        0x03f2
#define SIXAXIS_BT_ADDR         0x03f5

#define USB_MODE        0
#define BT_R_MODE       1
#define BT_W_MODE       2

int             mode = USB_MODE;
unsigned int    mac[6];

mach_port_t     masterPort = 0; // requires <mach/mach.h>
char            outBuf[8096];
char            inBuf[8096];

void dealWithInterface(io_service_t usbInterfaceRef)
{
    IOReturn                    err;
    IOCFPlugInInterface         **iodev;    // requires <IOKit/IOCFPlugIn.h>
    IOUSBInterfaceInterface     **intf;
    SInt32                      score;

    err = IOCreatePlugInInterfaceForService(usbInterfaceRef, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    if (err || !iodev) {
        printf("dealWithInterface: unable to create plugin. ret = %08x, iodev = %p\n", err, iodev);
        return;
    }
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID)&intf);
    IODestroyPlugInInterface(iodev);    // done with this
    
    if (err || !intf) {
        printf("dealWithInterface: unable to create a device interface. ret = %08x, intf = %p\n", err, intf);
        return;
    }

    ////////////////////////////////////////
    // send request commands to SIXAXIS
    ////////////////////////////////////////
    if (mode == USB_MODE) {
        IOUSBDevRequest     req;
        unsigned char       buf[17];
        
        req.bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBInterface);
        req.bRequest = 1;
        req.wValue   = SIXAXIS_USB_MODE;
        req.wIndex   = 0;
        req.wLength  = sizeof(buf);
        req.wLenDone = 0;
        req.pData    = buf;

        err = (*intf)->ControlRequest(intf, 0, &req);
        if (err) {
            printf("SIXAXIS_USB_MODE Err = %X\n", err);
        } else {
            printf("set usb-mode\n");
        }
    }
    
    if (mode == BT_R_MODE || mode == BT_W_MODE) {
        IOUSBDevRequest     req;
        unsigned char       buf[8];
        
        req.bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBInterface);
        req.bRequest = 1;
        req.wValue   = SIXAXIS_BT_ADDR;
        req.wIndex   = 0;
        req.wLength  = sizeof(buf);
        req.wLenDone = 0;
        req.pData    = buf;
        
        err = (*intf)->ControlRequest(intf, 0, &req);
        if (err) {
            printf("SIXAXIS_BT_ADDR(R) Err = %X\n", err);
        } else {
            printf("current bluetooth address: %02x-%02x-%02x-%02x-%02x-%02x\n",
                buf[2], buf[3], buf[4], buf[5], buf[6], buf[7]);
        } 
    }
    
    if (mode == BT_W_MODE) {
        IOUSBDevRequest     req;
        unsigned char       msg[8] = {0x01, 0x00, mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]};
        
        req.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBClass, kUSBInterface);
        req.bRequest = 9;
        req.wValue   = SIXAXIS_BT_ADDR;
        req.wIndex   = 0;
        req.wLength  = sizeof(msg);
        req.wLenDone = 0;
        req.pData    = msg;
        
        err = (*intf)->ControlRequest(intf, 0, &req);
        if (err) {
            printf("SIXAXIS_BT_ADDR(W) Err = %X\n", err);
        } else {
            printf("set bluetooth address:     %02x-%02x-%02x-%02x-%02x-%02x\n",
                mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        } 
    }
    ////////////////////////////////////////
        
    err = (*intf)->Release(intf);
    if (err) {
        printf("dealWithInterface: unable to release interface. ret = %08x\n", err);
        return;
    }
}


void dealWithDevice(io_service_t usbDeviceRef)
{
    IOReturn                        err;
    IOCFPlugInInterface             **iodev;        // requires <IOKit/IOCFPlugIn.h>
    IOUSBDeviceInterface            **dev;
    SInt32                          score;
    IOUSBFindInterfaceRequest       interfaceRequest;
    io_iterator_t                   iterator;
    io_service_t                    usbInterfaceRef;
    
    err = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    if (err || !iodev) {
        printf("dealWithDevice: unable to create plugin. ret = %08x, iodev = %p\n", err, iodev);
        return;
    }
    
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID)&dev);
    IODestroyPlugInInterface(iodev);        // done with this
    if (err || !dev) {
        printf("dealWithDevice: unable to create a device interface. ret = %08x, dev = %p\n", err, dev);
        return;
    }
    
    err = (*dev)->USBDeviceOpen(dev);
    if (err) {
        printf("dealWithDevice: unable to open device. ret = %08x\n", err);
        return;
    }
    
    interfaceRequest.bInterfaceClass    = kIOUSBFindInterfaceDontCare;      // requested class
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;      // requested subclass
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;      // requested protocol
    interfaceRequest.bAlternateSetting  = kIOUSBFindInterfaceDontCare;      // requested alt setting
    
    err = (*dev)->CreateInterfaceIterator(dev, &interfaceRequest, &iterator);
    if (err) {
        printf("dealWithDevice: unable to create interface iterator\n");
        (*dev)->USBDeviceClose(dev);
        (*dev)->Release(dev);
        return;
    }
    
    while (usbInterfaceRef = IOIteratorNext(iterator)) {
        dealWithInterface(usbInterfaceRef);
        IOObjectRelease(usbInterfaceRef);       // no longer need this reference
    }
    
    IOObjectRelease(iterator);
    iterator = 0;

    err = (*dev)->USBDeviceClose(dev);
    if (err) {
        printf("dealWithDevice: error closing device - %08x\n", err);
        (*dev)->Release(dev);
        return;
    }
    
    err = (*dev)->Release(dev);
    if (err) {
        printf("dealWithDevice: error releasing device - %08x\n", err);
        return;
    }
}



int main (int argc, const char * argv[])
{
    kern_return_t               err;
    CFMutableDictionaryRef      matchingDictionary = 0;     // requires <IOKit/IOKitLib.h>
    SInt32                      idVendor  = SIXAXIS_VENDOR_ID;
    SInt32                      idProduct = SIXAXIS_PRODUCT_ID;

    CFNumberRef                 numberRef;
    io_iterator_t               iterator = 0;
    io_service_t                usbDeviceRef;
    
    int     numSIXAXIS = 0;
    
    mode = USB_MODE;
    if (argc > 1 && !strcmp(argv[1], "-b")) {
        if (argc > 2) {
            mode = BT_W_MODE;
            if (sscanf(argv[2], "%x-%x-%x-%x-%x-%x",
                &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]) != 6) {
                printf("usage: sixaxis-usb -b <bluetooth address>\n");
                return -1;
            }
        } else {
            mode = BT_R_MODE;
        }
    }
    
    err = IOMasterPort(MACH_PORT_NULL, &masterPort);                
    if (err) {
        printf("USBSimpleExample: could not create master port, err = %08x\n", err);
        return err;
    }
    
    matchingDictionary = IOServiceMatching(kIOUSBDeviceClassName);      // requires <IOKit/usb/IOUSBLib.h>
    if (!matchingDictionary) {
        printf("USBSimpleExample: could not create matching dictionary\n");
        return -1;
    }
    
    numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &idVendor);
    if (!numberRef) {
        printf("USBSimpleExample: could not create CFNumberRef for vendor\n");
        return -1;
    }
    CFDictionaryAddValue(matchingDictionary, CFSTR(kUSBVendorID), numberRef);
    CFRelease(numberRef);

    numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &idProduct);
    if (!numberRef) {
        printf("USBSimpleExample: could not create CFNumberRef for product\n");
        return -1;
    }
    CFDictionaryAddValue(matchingDictionary, CFSTR(kUSBProductID), numberRef);
    CFRelease(numberRef);

    numberRef = 0;
    
    err = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);
    matchingDictionary = 0;     // this was consumed by the above call
    
    while (usbDeviceRef = IOIteratorNext(iterator)) {
        printf("SIXAXIS[%d]\n", ++numSIXAXIS);
        dealWithDevice(usbDeviceRef);
        IOObjectRelease(usbDeviceRef);      // no longer need this reference
    }
    
    IOObjectRelease(iterator);
    iterator = 0;
    
    mach_port_deallocate(mach_task_self(), masterPort);
    return 0;
}
