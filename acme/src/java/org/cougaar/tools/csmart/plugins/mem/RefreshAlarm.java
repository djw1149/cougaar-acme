package org.cougaar.tools.csmart.plugins.mem;

import java.util.Random;

import org.cougaar.core.agent.service.alarm.PeriodicAlarm;

/**
 * @author dixon-pd
 *
 * This alarm will read a random byte from the byte array when
 * it gets triggered.  This is to keep the byte array from being
 * swapped out of memory.
 * 
 */
public class RefreshAlarm implements PeriodicAlarm {
	private byte lastRead = 0;
	private byte data[];
	private long expiry;
	private int period;
	private int stddev;
	
	private boolean doIt = true;
	private boolean doneIt = false;
	private Random random = new Random();
		
	public RefreshAlarm( int size, int period, int stddev ) {
		data = new byte[size];
		random.nextBytes(data);
		
		this.period = period;
		this.stddev = stddev;
	}
	
	/**
	 * @see org.cougaar.core.agent.service.alarm.Alarm#getExpirationTime()
	 */
	public long getExpirationTime() {
		return expiry;
	}

	/**
	 * @see org.cougaar.core.agent.service.alarm.Alarm#expire()
	 */
	public void expire() {
		if (doIt) {
			int i = random.nextInt( data.length );
			lastRead = data[i];
			doneIt = true;
		}
	}

	/**
	 * @see org.cougaar.core.agent.service.alarm.Alarm#hasExpired()
	 */
	public boolean hasExpired() {
		return doneIt;
	}

	/**
	 * @see org.cougaar.core.agent.service.alarm.Alarm#cancel()
	 */
	public boolean cancel() {
		if (!doIt || doneIt) 		
			return false;
		
		doIt = false;
		return true;
	}	
	
	public void reset( long currentTime ) {
		long next = 
			new Double( period + (stddev * random.nextGaussian()) ).longValue();
		doIt = true;
			
		doneIt = false;
		
		expiry = currentTime + next;	
	}

}
