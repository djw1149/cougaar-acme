
#include <windows.h>
#include <list>
#include <iostream>
#include <queue>

using namespace std ;

#define BUFSIZE 4096 
typedef queue<char>  CHARQUEUE;

class ProcBuffers {
public:
	ProcBuffers(char *cmdline);
	~ProcBuffers();
	void Start();
	int isRunning();
	int hasData();
	int getErrData(char *buf, int bytes);
	int getOutData(char *buf, int bytes);
private:
	static DWORD WINAPI StderrReader(LPVOID arg);
	static DWORD WINAPI StdoutReader(LPVOID arg);
	void ReadBuffer(HANDLE stream, CHARQUEUE *queue);
	BOOL CreateChildProcess();
	char *cmdline;
	DWORD outThread;
	DWORD errThread;
	CHARQUEUE outQueue;
	CHARQUEUE errQueue;
    HANDLE hChildStderrRd, hChildStderrWr, hChildStderrRdDup, 
       hChildStdoutRd, hChildStdoutWr, hChildStdoutRdDup, 
       hSaveStderr, hSaveStdout; 
    PROCESS_INFORMATION piProcInfo; 
};
 
ProcBuffers::ProcBuffers(char *cmdline) {
	this->cmdline = strdup(cmdline);
}
ProcBuffers::~ProcBuffers() {
	free(cmdline);
}

int ProcBuffers::hasData() {
	return !outQueue.empty() || !errQueue.empty();
}

int ProcBuffers::isRunning() {
	return outThread && errThread;
}

int ProcBuffers::getOutData(char *buf, int bytes) {
	int ret = 0;
	while (ret < bytes) {
		if (outQueue.empty()) break;
		buf[ret++] = outQueue.front();
		outQueue.pop();
	}
	return ret;
}

int ProcBuffers::getErrData(char *buf, int bytes) {
	int ret = 0;
	while (ret < bytes) {
		if (errQueue.empty()) break;
		buf[ret++] = errQueue.front();
		errQueue.pop();
	}
	return ret;
}

DWORD WINAPI ProcBuffers::StdoutReader(LPVOID arg) {
	ProcBuffers *obj = (ProcBuffers *)arg;
	obj->ReadBuffer(obj->hChildStdoutRdDup, &obj->outQueue);
	obj->outThread = NULL;
	return 0;
}
DWORD WINAPI ProcBuffers::StderrReader(LPVOID arg) {
	ProcBuffers *obj = (ProcBuffers *)arg;
	obj->ReadBuffer(obj->hChildStderrRdDup, &obj->errQueue);
	obj->errThread = NULL;
	return 0;
}

LPTSTR ErrorDescription(DWORD p_dwError)
{
   static char error[1024];
   HLOCAL hLocal = NULL;

   if (!FormatMessage(
      FORMAT_MESSAGE_ALLOCATE_BUFFER |
      FORMAT_MESSAGE_FROM_SYSTEM |
      FORMAT_MESSAGE_IGNORE_INSERTS,
      NULL,
      p_dwError,
      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
      (LPTSTR)&hLocal,
      0,
      NULL))
   {
      printf("Unable for format error\n");
   }
   sprintf(error,(LPTSTR)hLocal);
   LocalFree(hLocal);
   error[strlen(error)-2]=0;
   return (LPTSTR)error;
}
#include <stdio.h> 
#include <windows.h> 
 
 
VOID ErrorExit(LPTSTR); 
VOID ErrMsg(LPTSTR, BOOL); 
 

void ProcBuffers::Start() {
   SECURITY_ATTRIBUTES saAttr; 
   BOOL fSuccess; 
 
   hSaveStdout = GetStdHandle(STD_OUTPUT_HANDLE); 
 
// Create a pipe for the child process's STDOUT. 
   saAttr.nLength = sizeof(SECURITY_ATTRIBUTES); 
   saAttr.bInheritHandle = TRUE; 
   saAttr.lpSecurityDescriptor = NULL; 
   if (! CreatePipe(&hChildStdoutRd, &hChildStdoutWr, &saAttr, 0)) 
      ErrorExit("Stdout pipe creation failed\n"); 
 
// Set a write handle to the pipe to be STDOUT. 
   if (! SetStdHandle(STD_OUTPUT_HANDLE, hChildStdoutWr)) 
      ErrorExit("Redirecting STDOUT failed"); 
 
// Create noninheritable read handle and close the inheritable read 
// handle. 
    fSuccess = DuplicateHandle(GetCurrentProcess(), hChildStdoutRd,
        GetCurrentProcess(), &hChildStdoutRdDup , 0,
        FALSE,
        DUPLICATE_SAME_ACCESS);
    if( !fSuccess )
        ErrorExit("DuplicateHandle failed");
    CloseHandle(hChildStdoutRd);

   hSaveStdout = GetStdHandle(STD_OUTPUT_HANDLE); 
 
// Create a pipe for the child process's STDERR. 
   saAttr.nLength = sizeof(SECURITY_ATTRIBUTES); 
   saAttr.bInheritHandle = TRUE; 
   saAttr.lpSecurityDescriptor = NULL; 
   if (! CreatePipe(&hChildStderrRd, &hChildStderrWr, &saAttr, 0)) 
      ErrorExit("Stderr pipe creation failed\n"); 
 
// Set a write handle to the pipe to be STDOUT. 
   if (! SetStdHandle(STD_ERROR_HANDLE, hChildStderrWr)) 
      ErrorExit("Redirecting STDERR failed"); 
 
// Create noninheritable read handle and close the inheritable read 
// handle. 
    fSuccess = DuplicateHandle(GetCurrentProcess(), hChildStderrRd,
        GetCurrentProcess(), &hChildStderrRdDup , 0,
        FALSE,
        DUPLICATE_SAME_ACCESS);
    if( !fSuccess )
        ErrorExit("DuplicateHandle failed");
    CloseHandle(hChildStderrRd);
 
// Now create the child process. 
   
   fSuccess = CreateChildProcess();
   if (! fSuccess) 
      ErrorExit("Create process failed"); 
 
// After process creation, restore the saved STDERR and STDOUT. 
 
   if (! SetStdHandle(STD_ERROR_HANDLE, hSaveStderr)) 
      ErrorExit("Re-redirecting Stderr failed\n"); 
 
   if (! SetStdHandle(STD_OUTPUT_HANDLE, hSaveStdout)) 
      ErrorExit("Re-redirecting Stdout failed\n"); 
 
 
// Close the write end of the pipe before reading from the 
// read end of the pipe. 
   if (!CloseHandle(hChildStdoutWr)) 
      ErrorExit("Closing handle failed"); 
   if (!CloseHandle(hChildStderrWr)) 
      ErrorExit("Closing handle failed"); 
// Read from pipe that is the standard output for child process. 

   CreateThread(NULL, 0, ProcBuffers::StdoutReader, this, 0, &this->outThread);
   CreateThread(NULL, 0, ProcBuffers::StderrReader, this, 0, &this->errThread);

#if 1
   fSuccess = ResumeThread(piProcInfo.hThread);
   if (fSuccess < 0) {
	   printf("ResumeThread: %s\n", ErrorDescription(GetLastError()));
   }
#endif 0
   CloseHandle(piProcInfo.hProcess);
   CloseHandle(piProcInfo.hThread);

 
}

 
BOOL ProcBuffers::CreateChildProcess() 
{ 
   STARTUPINFO siStartInfo;
   BOOL bFuncRetn = FALSE; 
 
// Set up members of the PROCESS_INFORMATION structure. 
 
   ZeroMemory( &piProcInfo, sizeof(PROCESS_INFORMATION) );
 
// Set up members of the STARTUPINFO structure. 
 
   ZeroMemory( &siStartInfo, sizeof(STARTUPINFO) );
   siStartInfo.cb = sizeof(STARTUPINFO); 
 
// Create the child process. 
    
   bFuncRetn = CreateProcess(NULL, 
      cmdline,       // command line 
      NULL,          // process security attributes 
      NULL,          // primary thread security attributes 
      TRUE,          // handles are inherited 
      CREATE_SUSPENDED,// creation flags 
      NULL,          // use parent's environment 
      NULL,          // use parent's current directory 
      &siStartInfo,  // STARTUPINFO pointer 
      &piProcInfo);  // receives PROCESS_INFORMATION 
   
   if (bFuncRetn == 0) {
      ErrorExit("CreateProcess failed\n");
      return 0;
   } else {
      return bFuncRetn;
      }
   }

  
 
VOID ProcBuffers::ReadBuffer(HANDLE stream, CHARQUEUE *queue) {

   DWORD dwRead; 
   CHAR chBuf[BUFSIZE]; 
 
// Read output from the child process, and write the queue. 
   for (;;) 
   { 
    //printf("reading...\n");
	  DWORD status = ReadFile( stream, chBuf, BUFSIZE, &dwRead, NULL);
    if( !status || dwRead == 0) break; 
	  chBuf[dwRead] = 0;
    //printf("read %s\n", chBuf);
	  for (unsigned int i=0; i<dwRead; i++) {
		  queue->push(chBuf[i]);
	  }
   } 
} 
 
VOID ErrorExit (LPTSTR lpszMessage) 
{ 
   fprintf(stderr, "%s\n", lpszMessage); 
   ExitProcess(0); 
} 



extern "C" {
void *SpawnProcess(char *cmdline) {
   ProcBuffers *pb = new ProcBuffers(cmdline);
   pb->Start();
   return pb;
}

int IsActive(void *proc) {
	ProcBuffers *pb = (ProcBuffers *)proc;
	return pb->isRunning() || pb->hasData();
}

int GetStderr(void *proc, char *buf, int size) {
	ProcBuffers *pb = (ProcBuffers *)proc;
	return pb->getErrData(buf, size);
}
int GetStdout(void *proc, char *buf, int size) {
	ProcBuffers *pb = (ProcBuffers *)proc;
	return pb->getOutData(buf, size);
}
void FreeProcess(void *proc) {
	ProcBuffers *pb = (ProcBuffers *)proc;
	delete pb;
}
}


DWORD main(int argc, char *argv[]) 
{ 
   //ProcBuffers *pb = new ProcBuffers("python -u output.py");
#if 0
   ProcBuffers *pb = new ProcBuffers("java -version");
   pb->Start();
   do {
	   char buf[1024];
	   int bytes = pb->getOutData(buf, sizeof(buf));
	   buf[bytes] = 0;
	   if (bytes)
	     printf("STDOUT: [%s]\n", buf);
	   bytes = pb->getErrData(buf, sizeof(buf));
	   buf[bytes] = 0;
	   if (bytes)
         printf("STDERR: [%s]\n", buf);
	   Sleep(1000);
   } while (pb->isRunning() || pb->hasData());
   delete pb;
#else
	void *proc = SpawnProcess("java -version");
	do {
	   char buf[1024];
	   int bytes = GetStdout(proc, buf, sizeof(buf));
	   buf[bytes] = 0;
	   if (bytes)
	     printf("STDOUT: [%s]\n", buf);
	   bytes = GetStderr(proc, buf, sizeof(buf));
	   buf[bytes] = 0;
	   if (bytes)
         printf("STDERR: [%s]\n", buf);
	   Sleep(1000);
   } while (IsActive(proc));
   FreeProcess(proc);
#endif
} 
