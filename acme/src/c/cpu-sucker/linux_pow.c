/*
 * linux_pow
 *
 * JNI Implementation
 */

#include <jni.h>
#include <sched.h>
#include <errno.h>
#include <string.h>

#include "power_off.h"

void throwPowerException( JNIEnv *env )
{
  jclass utbExcept =
    (*env)->FindClass(env, "org.cougaar.tools.utb.exception.UTBException");

  (*env)->ThrowNew( env, utbExcept, strerror( errno ));
}

JNIEXPORT void JNICALL 
Java_org_cougaar_tools_utb_hardware_linux_LinuxPowerControl_powerOff( JNIEnv *env, jobject this ) 
{
  if (power_off() != 0) {
    throwPowerException( env );
  }
}

JNIEXPORT void JNICALL
Java_org_cougaar_tools_utb_hardware_linux_LinuxPowerControll_restart( JNIEnv *env, jobject this )
{
  if (restart() != 0) {
    throwPowerException( env );
  }
}
