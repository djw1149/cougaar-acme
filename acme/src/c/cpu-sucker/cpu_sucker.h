/*
 * cpu_sucker
 *
 * This function will suck the specified
 * amount of CPU from other processes.
 *
 * Must be ROOT to run.
 *
 * on_time + off_time should = 10000
 */

extern int cpu_sucker( int on_time, int off_time );
extern int cpu_sucker_ruby( int on_time, int off_time );
extern void stop_cpu_sucker( int modPID );
