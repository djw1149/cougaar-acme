package org.cougaar.tools.csmart.plugins.mem;


import java.util.Iterator;

import org.cougaar.core.service.EventService;
import org.cougaar.core.plugin.ComponentPlugin;

/**
 * @author dixon-pd
 *
 * This plugin will allocate a pre-determined block of 
 * memory, and periodically reference it to keep it in
 * memory.
 */
public class MemoryWasterPlugin 
	extends ComponentPlugin
{
	private EventService evt;
	private int size = 0;
	private int frequency = 0;
	private int stddev = 0;
	
	private boolean init = false;
	
	private String communityName;
	
	public MemoryWasterPlugin() {
	}
	
	public void setEventService( EventService evt ) {
		this.evt = evt;
	}
	
	public EventService getEventService() {
		return this.evt;
	}
	
	protected void setupSubscriptions() {
		Iterator i = this.getParameters().iterator();
		size = Integer.parseInt( i.next().toString() );
		frequency = Integer.parseInt( i.next().toString() );
		stddev = Integer.parseInt( i.next().toString() );
		
		this.getAlarmService().addRealTimeAlarm(new RefreshAlarm(size, frequency, stddev));
	}
	
	/**
	 * @see org.cougaar.core.blackboard.BlackboardClientComponent#execute()
	 */
	protected void execute() {
	}
}
