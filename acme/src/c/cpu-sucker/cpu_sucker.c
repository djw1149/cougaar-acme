/*
 * cpu_sucker
 *
 * Takes up a percentage of the CPU.
 */

#include <unistd.h>
#include <sched.h>
#include <errno.h>
#include <error.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <sys/time.h>

int suckerOn = 1;
int childPid;
int modPid;
int stopSucker = 0;

//////// Signal Handlers
// usr1 - Turns off the CPU Sucker.
void suck_usr1_handle( int signum ) {
  suckerOn = 0;
}

// usr2 - Turns the sucker back on.
void suck_usr2_handle( int signum ) {
  suckerOn = 1;
}

void mod_usr1_handle( int signum ) {
  stopSucker = 1;
}

/////////// Helper Functions.
void u_sleep( int sec, int usec ) {
  fd_set *A = NULL;
  fd_set *B = NULL;
  fd_set *C = NULL;

  struct timeval tt;

  tt.tv_sec = sec;
  tt.tv_usec = usec;

  select(0, A, B, C, &tt);

}

// Set the Absolute Priority Schedule
int set_schedule( int pid, int level )
{
  struct sched_param sp;
  int RC;

  sp.sched_priority = level;
  
  return sched_setscheduler( pid, SCHED_RR, &sp );
}

// Cause CPU Sucker to go between ON and OFF.
void modulate( int pid, int on_time, int off_time )
{
    int RC;
    signal( SIGUSR1, mod_usr1_handle );
    while ( stopSucker == 0 ) {
	u_sleep(0, on_time);
	kill( childPid, SIGUSR1 );
	
	u_sleep(0, off_time);
	kill( childPid, SIGUSR2 );
    }

    kill( childPid, SIGKILL );
}

// Suck CPU
void suck_cpu() {
  int i = 0;

  signal( SIGUSR1, suck_usr1_handle );
  signal( SIGUSR2, suck_usr2_handle );

  while (1) {
    if (suckerOn) {
      i++;
      if (((i % 5000) == 0) && suckerOn) {
	sched_yield();
      }
    } else {
      u_sleep(0, 100);
    }
  }
}

// This kicks everything off
int cpu_sucker( int on_time, int off_time ) 
{
  int pid, child_pid;

  pid = getpid();
  modPid = getpid();

  if (child_pid = fork()) {
    int RC;
    RC = set_schedule( modPid, 2 );
    if (RC != 0) {
      kill( child_pid, SIGKILL );
      return RC;
    }

    childPid = child_pid;
    RC = set_schedule( childPid, 1);
    if (RC != 0) {
      kill( childPid, SIGKILL );
      return RC;
    }

    modulate( childPid, on_time, off_time );
    return 0;
  } else {
    suck_cpu();
    return 0;
  }
}

int cpu_sucker_ruby( int on_time, int off_time ) {
  int RC;

  RC = fork();
  if (RC == 0) {
    RC = cpu_sucker( on_time, off_time );
    exit( 0 );
  } 

  return RC;
}
void stop_cpu_sucker( int modPID ) {
  kill( modPID, SIGUSR1 );
}

