// $Id: BlinkC.nc,v 1.4 2006/12/12 18:22:48 vlahan Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

#include "Timer.h"

module BlinkC {
  uses {
    interface Timer<TMilli> as Timer0;
    interface Leds;
    interface Boot;

    interface SplitControl as AMControl;
    interface AMPacket;
    interface Packet;
    interface AMSend as AttestationRequestSend;
    interface Receive as AttestationResponseReceive;
  }
}

implementation {
  bool busy = FALSE;
  uint32_t time;
  message_t message;

  event void Boot.booted() {
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if(err == SUCCESS) {
      call Timer0.startPeriodic(5000);
    } else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    // nothing
  }

  void sendAttestationRequest(uint32_t nonce) {
    if(!busy) {
      AttestationRequestMsg* request = (AttestationRequestMsg*)(call Packet.getPayload(&message, sizeof(AttestationRequestMsg)));

      request->nonce = nonce;

      if(call AttestationRequestSend.send(AM_BROADCAST_ADDR, &message, sizeof(AttestationRequestMsg)) == SUCCESS) {
        busy = TRUE;

        time = call Timer0.getNow();
      }
    }
  }

  event void Timer0.fired() {
    sendAttestationRequest(0xf3a107c4);
  }

  event void AttestationRequestSend.sendDone(message_t* msg, error_t error) {
    if(&message == msg) {
      // nothing
    }
  }

  event message_t* AttestationResponseReceive.receive(message_t* msg, void* payload, uint8_t len) {
    if(len == sizeof(AttestationResponseMsg)) {
      AttestationResponseMsg* in = (AttestationResponseMsg*)payload;

      if(in->checksum != 0x552bbe2296e34189) {
        call Leds.led0Toggle();
      } else {
        call Leds.led1Toggle();
      }

      busy = FALSE;
    }

    return msg;
  }
}

