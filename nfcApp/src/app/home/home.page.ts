import { Component } from '@angular/core';
import { Platform } from '@ionic/angular';

import { NFC, Ndef, NdefEvent } from '@ionic-native/nfc/ngx';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
})
export class HomePage {

  data: NdefEvent;

  constructor(
    private platform: Platform,
    private nfc: NFC,
    private ndef: Ndef
    ) {}

  ngOnInit() 
  {
    this.platform.ready().then(() => {
    console.log('ngoninit home');   

    this.nfc.addTagDiscoveredListener((res) => {
      console.log('successfully attached tag listener : '  + JSON.stringify(res));
    }, (err) => {
      console.log('error attaching tag listener : ' +  + JSON.stringify(err));
    }).subscribe((event) => {
      console.log('received tag message. the tag is: ', event.tag);
      console.log('decoded tag id', this.nfc.bytesToHexString(event.tag.id));
      this.data = event;

      setTimeout(() => {
        this.nfc.addNdefListener((res) => {
          console.log('successfully attached ndef listener : '  + JSON.stringify(res));
        }, (err) => {
          console.log('error attaching ndef listener : ' +  + JSON.stringify(err));
        }).subscribe((event) => {
          console.log('received ndef message. the tag contains: ', event.tag);
          //console.log('decoded tag id', this.nfc.bytesToHexString(event.tag.id));
          this.data = event;
        });
      }, 0);

    });
    
    });
  }

  scan(event)
  {
    console.log('scan' + event);   

    this.nfc.read().then(
    (res) => 
    {
      console.log('tag read : ', res);
    },
    (err) => 
    {
      console.log('tag read fail : ', err);
    });
  }

  write(event)
  {
    //console.log('write : ' + event + ' data : ' + this.data.tag);   

    let payload = new Array<number>();
        payload.push(2);
        payload.push(10);
        // payload = payload.concat(this.data.tag.ndefMessage[0].id);
        // payload = payload.concat(this.data.tag.ndefMessage[0].tnf);
        // payload = payload.concat(this.data.tag.ndefMessage[0].type);
        // payload = payload.concat(this.data.tag.ndefMessage[0].payload);

        console.log('connect : ' + payload);

        let message = [this.ndef.record(4, 'toto', '', payload), this.ndef.record(4, 'titi', '', payload)];
        console.log('payload : ' + JSON.stringify(message));

        this.nfc.write(message)
        .then(
        (event) =>
        {
          console.log('write promise ok : ', event);
    
        },
        (error) =>
        {
          console.log('write promise fail : ', error);
        });
    
  }
}
