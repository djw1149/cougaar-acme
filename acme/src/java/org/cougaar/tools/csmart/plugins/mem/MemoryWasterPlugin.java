package org.cougaar.tools.csmart.plugins.mem;


import java.io.PrintStream;
import java.io.PrintWriter;
import java.util.Iterator;
import java.util.List;

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
		
		public MWServlet( AlarmService alarmSvc, int freq, int std ) {
			this.current = new RefreshAlarm( new byte[0], freq, std );
			this.alarmSvc = alarmSvc;	
			this.freq = freq;
			this.stddev = std;
		}
		
		public void wasteMemory() {
			current.setData( new byte[size * 1024]);
		}	
		
		public void execute( HttpServletRequest request,
							  HttpServletResponse response ) 
			throws ServletException
		{
			try {
				response.setContentType("text/xml");
				
				String sizeStr = request.getParameter("size");
				if (sizeStr != null) {
					size = Integer.parseInt(sizeStr);
					wasteMemory();
				}
								
				PrintWriter out = response.getWriter();
				out.println("<?xml version=\"1.0\"?>");
				
				out.println("<memory-waster time=\"" + 
					System.currentTimeMillis() + "\">");
				out.println("\t<jvm-memory " +
								" free=\"" + Runtime.getRuntime().freeMemory() + "\"" +
								" total=\"" + Runtime.getRuntime().totalMemory() + "\"" + 
								" max=\"" + Runtime.getRuntime().maxMemory() + "\"/>");
				out.println("\t<wasted size=\"" + size * 1024 + "\" />");
				out.println("\t<refresh period=\"" + freq + "\"" +
									  " deviation=\"" + stddev + "\"/>");
				out.println("</memory-waster>");
			} catch (Exception e) {
				throw new ServletException(e);
			}		
		}
		
		public void doPost( HttpServletRequest request,
							HttpServletResponse response ) 
			throws ServletException
		{
			execute( request, response );
		}
		
		public void doGet( HttpServletRequest request,
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
		try {
			
			List params = (List) getParameters();
			String servletName = (String) params.get( 0 );
			String freqStr = (String) params.get( 1 );
			String stdStr = (String) params.get( 2 );
			
			int freq = Integer.parseInt( freqStr );
			int std = Integer.parseInt( stdStr );
			
			ServiceBroker broker = getBindingSite().getServiceBroker();
			ServletService srv =
				(ServletService) broker.getService(this, ServletService.class, null);
			
			srv.register(servletName, new MWServlet( getAlarmService(), freq, std));
		} catch (Exception e) {
			throw new RuntimeException(e);	
		}
	}
	
	/**
	 * @see org.cougaar.core.blackboard.BlackboardClientComponent#execute()
	 */
	protected void execute() {
	}
}
