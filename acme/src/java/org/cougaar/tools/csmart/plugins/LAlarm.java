/**
 * <copyright>
 *  Copyright 1997-2002 BBNT Solutions, LLC
 *  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the Cougaar Open Source License as published by
 *  DARPA on the Cougaar Open Source Website (www.cougaar.org).
 *
 *  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
 *  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
 *  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
 *  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
 *  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
 *  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
 *  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 *  PERFORMANCE OF THE COUGAAR SOFTWARE.
 * </copyright>
 *
 * Created on Sep 10, 2002
 */
package org.cougaar.tools.csmart.plugins;

import org.cougaar.core.agent.service.alarm.Alarm;
import org.cougaar.core.service.AlarmService;
import org.cougaar.core.service.BlackboardService;

/**
 * @author dpeugh
 *
 * This is one of those classes you would assume
 * to be written by Cougaar.  Well, here it is.
 */
public class LAlarm implements Alarm {
	private BlackboardService blackboard;
	private AlarmService alarmService;
	
	private long expiry = 0L; //absolute time (milliseconds) that alarm activates
	private long period = -1L; //time interval (milliseconds) between alarm activations
	// if -1, then it is a one-shot alarm.  Otherwise it gets hit many times.

	private boolean expired;  //flag to indicate if alarm has activated or was cancelled
 
	public LAlarm(BlackboardService blackboard,
				  AlarmService alarmService,
				  long delay) {
		this.blackboard = blackboard;
		this.alarmService = alarmService;

		expiry = System.currentTimeMillis() + delay;
		expired = false;
	}

	public LAlarm( BlackboardService blackboard,
				   AlarmService alarmService,
				   long delay, long period ) {
		this.blackboard = blackboard;
		this.alarmService = alarmService;
		this.period = period;			   	
		
		expiry = System.currentTimeMillis() + delay;
		expired = false;
	}	
	
	public boolean cancel() {
		if(expired)
			return false;
		expired = true;
		return expired;
	}

	public long getExpirationTime() {
		return expiry;
	}

	public void expire() {
		blackboard.signalClientActivity();
		
		if (period > 0) {
			alarmService.addRealTimeAlarm( 
					new LAlarm( blackboard,
								alarmService,
								period,
								period ));						
		}
	}
	
	public boolean hasExpired() { return expired; }
}
