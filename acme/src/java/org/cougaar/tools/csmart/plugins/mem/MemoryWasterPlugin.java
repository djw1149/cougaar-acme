package org.cougaar.tools.csmart.plugins.mem;


import java.io.PrintWriter;
import java.util.List;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.cougaar.core.service.AlarmService;
import org.cougaar.core.service.EventService;
import org.cougaar.core.service.ServletService;
import org.cougaar.tools.csmart.plugins.LAlarm;
import org.cougaar.core.component.ServiceBroker;
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
    protected boolean doLog = false;
    	
	private String communityName;

	public int getSize() { return size; }
	public void setSize( int i ) { this.size = i; }
	public int getFrequency() { return frequency; }
	public int getDeviation() { return stddev; }
		
	private class MWServlet 
		extends HttpServlet
	{
		private AlarmService alarmSvc = null;
		private RefreshAlarm current = null;
		private MemoryWasterPlugin plugin = null;
		
		public MWServlet( MemoryWasterPlugin plugin,
							AlarmService alarmSvc) {
			this.current = new RefreshAlarm( new byte[0], 
												plugin.getFrequency(), 
												plugin.getDeviation() );
			this.alarmSvc = alarmSvc;	
			this.plugin = plugin;
		}
		
		public void wasteMemory() {
			current.setData( new byte[plugin.getSize() * 1024]);
		}	
		
		public void execute( HttpServletRequest request,
							  HttpServletResponse response ) 
			throws ServletException
		{
			try {
				response.setContentType("text/xml");
				
				String sizeStr = request.getParameter("size");
				if (sizeStr != null) {
					plugin.setSize(Integer.parseInt(sizeStr));
					wasteMemory();
				}
				
				String logEnabled = request.getParameter("log");
				if (logEnabled != null) {
					if (logEnabled.equals("enable")) {
						plugin.doLog = true;	
					} else if (logEnabled.equals("disable")) {
						plugin.doLog = false;
					}
				}
							
				PrintWriter out = response.getWriter();
				out.println("<?xml version=\"1.0\"?>");
				
				out.println("<memory-waster time=\"" + 
					System.currentTimeMillis() + "\">");
				out.println("\t<jvm-memory " +
								" free=\"" + Runtime.getRuntime().freeMemory() + "\"" +
								" total=\"" + Runtime.getRuntime().totalMemory() + "\"" + 
								" max=\"" + Runtime.getRuntime().maxMemory() + "\"/>");
				out.println("\t<wasted size=\"" + plugin.getSize() * 1024 + "\" />");
				out.println("\t<refresh period=\"" + plugin.getFrequency() + "\"" +
									  " deviation=\"" + plugin.getDeviation() + "\"/>");
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
			
			frequency = Integer.parseInt( (String) params.get( 1 ) );
			stddev = Integer.parseInt( (String) params.get( 2 ) );
			
			ServiceBroker broker = getBindingSite().getServiceBroker();
			ServletService srv =
				(ServletService) broker.getService(this, ServletService.class, null);
			
			srv.register(servletName, new MWServlet( this, getAlarmService()));
			
			LAlarm alarm = new LAlarm( getBlackboardService(), alarmService,
				                       30 * 1000L, 30 * 1000L );
    	    alarmService.addRealTimeAlarm( alarm );
		} catch (Exception e) {
			throw new RuntimeException(e);	
		}
	}
	
	/**
	 * @see org.cougaar.core.blackboard.BlackboardClientComponent#execute()
	 */
	protected void execute() {
		if (doLog) {
			evt.event("type=MEMORY\tagent=" + getAgentIdentifier() + "\t" +
			          "real-time=" + System.currentTimeMillis() + "\t" +
			          "sim-time=" + alarmService.currentTimeMillis() + "\t" +
		    	      "free=" + Runtime.getRuntime().freeMemory() + "\t" +
		        	  "total=" + Runtime.getRuntime().totalMemory() + "\t" +
		          	  "max=" + Runtime.getRuntime().maxMemory() + "\t" +
		          	  "wasted=" + getSize() * 1024);
		}
	}
}
