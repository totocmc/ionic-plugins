import { expect } from "chai";
import { NdefRecord } from "./definitions";
import { parseTapNdefMessage } from "./parse-ndef-message";

describe(__filename, function () {

    const VALID_SAMPLE: NdefRecord[] = JSON.parse('[{"tnf":1,"type":[85],"id":[],"payload":[0,104,116,116,112,115,58,47,47,119,119,119,46,109,121,100,111,109,97,105,110,46,99,111,109]},{"tnf":4,"type":[97,110,100,114,111,105,100,46,99,111,109,58,112,107,103],"id":[],"payload":[99,111,109,46,105,111,116,105,122,101,46,100,101,109,111,46,115,101,110,115,111,114,100,101,109,111]},{"tnf":5,"type":[],"id":[],"payload":[64,88,-34,-65,-23,50,-63]},{"tnf":1,"type":[84],"id":[],"payload":[0,83,101,110,115,111,114,32,100,101,109,111,95,48,48,48,48,68]}]');


    describe('with valid NdefRecords', function () {

        it("parsing valid NDefRecords should extract informations", function () {
            let data = parseTapNdefMessage(VALID_SAMPLE);
            expect(data.ssid).to.be.undefined;
            expect(data.aar).to.be.eq("com.iotize.demo.sensordemo");
            expect(data.uri).to.be.eq("https://www.mydomain.com");
            expect(data.name).to.be.eq("Sensor demo_0000D");
            expect(data.macAddress).to.be.eq('C1:32:E9:BF:DE:58');
        })
    });


})