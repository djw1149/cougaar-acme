/*
 * linux_cpu
 *
 * JNI Implementation.
 */

#include <jni.h>
#include <sched.h>
#include <errno.h>
#include <string.h>

#include "cpu_sucker.h"

void throwCPUException( JNIEnv *env, int RC )
{
  jclass utbExcept =
    (*env)->FindClass(env, "org.cougaar.tools.utb.exception.UTBException");

  (*env)->ThrowNew(env, utbExcept, strerror( RC ));
}

jint JNICALL Java_org_cougaar_tools_utb_hardware_linux_LinuxCPUControl_suckCPU
(JNIEnv *env, jobject this, jint onTime, jint offTime)
{
  int RC;

  RC = fork();
  if (RC == 0) {
    RC = cpu_sucker( onTime, offTime );
    
    if (RC != 0) {
      throwCPUException( env, RC );
    }
  } else {
    sleep(1);
    return RC;
  }
}

void JNICALL Java_org_cougaar_tools_utb_hardware_linux_LinuxCPUControl_stopSucking
(JNIEnv *env, jobject this, jint modPID)
{
  stop_cpu_sucker( modPID );
}
