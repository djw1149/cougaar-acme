package org.cougaar.tools.csmart.plugins.mem;


import java.io.PrintStream;
import java.io.PrintWriter;
import java.util.Iterator;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.cougaar.core.service.AlarmService;
import org.cougaar.core.service.EventService;
import org.cougaar.core.service.ServletService;
import org.cougaar.core.component.ServiceBroker;
import org.cougaar.core.component.ServiceRevokedListener;
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
	
	private class MWServlet 
		extends HttpServlet
	{
		private AlarmService alarmSvc = null;
		private RefreshAlarm current = null;
		
		private int size, freq, stddev = 0;
		
		public MWServlet( AlarmService alarmSvc ) {
			this.alarmSvc = alarmSvc;	
		}
		
		public void wasteMemory() {
			if (current != null) {
				current.cancel();
				current.free();
				current = null; // Try and force G.C.	
			}
			
			if (size > 0) {
				current = new RefreshAlarm(size, frequency, stddev);
				alarmSvc.addRealTimeAlarm(current);	
			}
		}	
		
		public void execute( HttpServletRequest request,
							  HttpServletResponse response ) 
			throws ServletException
		{
			try {
				String sizeStr = request.getParameter("size");
				if (sizeStr != null) 
					size = Integer.parseInt(sizeStr);
					
				String freqStr = request.getParameter("freq");
				if (freqStr != null)
					freq = Integer.parseInt(freqStr);
					
				String stdStr = request.getParameter("stddev");
				if (stdStr != null) 
					stddev = Integer.parseInt(stdStr);

				if (size > 0) 
					wasteMemory();
					
				PrintWriter out = response.getWriter();
				out.println("<HTML><HEAD>");
				
				out.println("<TABLE>");
				out.println("<TR><TD>SIZE: </TD><TD>" + size + "</TD></TR>");
				out.println("<TR><TD>FREQ: </TD><TD>" + freq + "</TD></TR>");
				out.println("<TR><TD>STDDEV: </TD><TD>" + stddev + "</TD></TR>");
				out.println("</TABLE>");
				
				out.println("</HEAD></HTML>");
				
			} catch (Exception e) {
				throw new ServletException(e);
			}		
		}
		
		public void post( HttpServletRequest request,
							HttpServletResponse response ) 
			throws ServletException
		{
			execute( request, response );
		}
		
		public void get( HttpServletRequest request,
							HttpServletResponse response ) 
			throws ServletException
		{
			execute( request, response );
		}		
	}
	
	public MemoryWasterPlugin() {
	}
	
	public void setEventService( EventService evt ) {
		this.evt = evt;
	}
	
	public EventService getEventService() {
		return this.evt;
	}
	
	protected void setupSubscriptions() {
		ServiceBroker broker = getBindingSite().getServiceBroker();
		ServletService srv =
			(ServletService) broker.getService(this, ServletService.class, null);
			
		srv.register("/mem-waster", new MWServlet( getAlarmService()));
	}
	
	/**
	 * @see org.cougaar.core.blackboard.BlackboardClientComponent#execute()
	 */
	protected void execute() {
	}
}
