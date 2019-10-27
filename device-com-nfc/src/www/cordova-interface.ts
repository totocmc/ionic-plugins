//
//  Copyright 2018 IoTize SAS Inc.  Licensed under the MIT license. 
//
//  cordova-interface.ts
//  device-com-ble.cordova BLE Cordova Plugin
//
/**
 * Partial typings for phonegap nfc cordova interface class
 */
export interface CordovaInterface {
        
    /**
     * Close current nfc tag
     */
    close(): Promise<void>;

    /**
     * Connect to current nfc tag
     */
    connect(tech: string, timeout: number): Promise<void>;

    /**
     * Transeive data using 
     * @param data ArrayBuffer or string of hex data for transcieve
     */
    transceive(data: ArrayBuffer | string): Promise<string>;
}