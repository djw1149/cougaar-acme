/*
 * linux_drv
 *
 * JNI Implementation of Drive Mounting commands.
 */

#include <jni.h>
#include <sched.h>
#include <errno.h>
#include <string.h>

#include "drive.h"

void throwDriveException( JNIEnv *env )
{
  jclass utbExcept =
    (*env)->FindClass(env, "org.cougaar.tools.utb.exception.UTBException");

  (*env)->ThrowNew( env, utbExcept, strerror( errno ));
}


JNIEXPORT void JNICALL Java_org_cougaar_tools_utb_hardware_linux_LinuxDriveControl_unmount( JNIEnv *env, jobject this, jstring directory ) 
{
  jboolean iscopy;
  const char *dir = (*env)->GetStringUTFChars(env, directory, &iscopy);

  if (unmount( dir ) != 0) 
    throwDriveException(env);
}

JNIEXPORT void JNICALL Java_org_cougaar_tools_utb_hardware_linux_LinuxDriveControl_mount( JNIEnv *env, jobject this, jstring directory ) 
{
  throwDriveException(env);
}

