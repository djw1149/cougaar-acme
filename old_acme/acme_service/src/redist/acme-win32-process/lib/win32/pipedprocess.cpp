/*
 * <copyright>  
 *  Copyright 2001-2004 BBN Technologies
 *  Copyright 2001-2004 InfoEther LLC  
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
 */
#include <windows.h>
#include <list>
#include <map>
#include <iostream>
#include <queue>

using namespace std ;

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
	DWORD getPid() {return pid;};
	// send keyboard signals
	void ControlBreak();
	void ControlC();
	// store/retrieve ProcBuffers by PID
	static ProcBuffers *getProcBuffer(DWORD pid);
	static void putProcBuffer(DWORD pid, ProcBuffers *proc);
	// mutex locks
	void lock() {WaitForSingleObject(my_mutex, INFINITE);};
	void unlock() {ReleaseMutex(my_mutex);};
private:
	static DWORD WINAPI StderrReader(LPVOID arg);
	static DWORD WINAPI StdoutReader(LPVOID arg);
	static void ReadBuffer(HANDLE stream, CHARQUEUE *queue);
	int CreateChildProcess();
	char *cmdline;
	DWORD pid;
	DWORD outThread;
	DWORD errThread;
	BOOL outThreadActive, errThreadActive;
	CHARQUEUE *outQueue;
	CHARQUEUE *errQueue;
	HANDLE hChildStderrRd, hChildStderrWr, hChildStderrRdDup, 
		hChildStdoutRd, hChildStdoutWr, hChildStdoutRdDup, 
		hSaveStderr, hSaveStdout; 
	PROCESS_INFORMATION piProcInfo; 
	HANDLE my_mutex;
	HANDLE outThreadHandle, errThreadHandle;
};
extern LPTSTR ErrorDescription(DWORD p_dwError);

/*
 * Index of PID -> ProcBuffers objects
 */
static map<DWORD, ProcBuffers *> proc_map;

void ProcBuffers::putProcBuffer(DWORD pid, ProcBuffers *proc) {
	proc_map[pid] = proc;
}

ProcBuffers * ProcBuffers::getProcBuffer(DWORD pid) {
	return proc_map[pid];
}


ProcBuffers::ProcBuffers(char *cline) {
	my_mutex = CreateMutex( NULL, FALSE, NULL );
	this->cmdline = new char[strlen(cline)+1];
	strcpy(this->cmdline, cline);
	outQueue = new CHARQUEUE();
	errQueue = new CHARQUEUE();
}

ProcBuffers::~ProcBuffers() {
	BOOL ret;
	HANDLE hProcess;
	HANDLE hThread;

	// if it's running, kill it.
	if (pid) {
		hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
		if (hProcess) { 
			printf("Killing PID: %d\n", pid);
			ret = TerminateProcess(hProcess, 0);
			if (ret) {
				printf("PID: %d terminated\n", pid);
				CloseHandle(hProcess);
			} else {
				printf("PID: %d NOT terminated: %s\n", pid, ErrorDescription(GetLastError()));
			}

		}
	}
	// make sure the reader threads have exited
	if (outThread) {
		hThread = OpenThread(SYNCHRONIZE, FALSE, outThread);
		if (hThread) {
			WaitForSingleObject(hThread, INFINITE);
			CloseHandle(hThread);
			CloseHandle(outThreadHandle);
		} else {
			printf("Error opening thread: %s\n", ErrorDescription(GetLastError()));
		}
		outThread = 0;
		delete outQueue;
	}
	if (errThread) {
		hThread = OpenThread(SYNCHRONIZE, FALSE, errThread);
		if (hThread) {
			WaitForSingleObject(hThread, INFINITE);
			CloseHandle(hThread);
			CloseHandle(errThreadHandle);
		} else {
			printf("Error opening thread: %s\n", ErrorDescription(GetLastError()));
		}
		errThread = 0;
		delete errQueue;
	}

	delete cmdline;
	CloseHandle(my_mutex);
}

void ProcBuffers::ControlBreak() {
	if (!GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT, pid)) {
		printf("Error generating CTRL-Break(%d): %s\n", pid, ErrorDescription(GetLastError()));
	}
}
void ProcBuffers::ControlC() {
	if (!GenerateConsoleCtrlEvent(CTRL_C_EVENT, pid)) {
		printf("Error generating CTRL-C(%d): %s\n", pid, ErrorDescription(GetLastError()));
	}
}

int ProcBuffers::hasData() {
	return !outQueue->empty() || !errQueue->empty();
}

int ProcBuffers::isRunning() {
	return outThreadActive && errThreadActive;
}

int ProcBuffers::getOutData(char *buf, int bytes) {
	int ret = 0;
	while (ret < bytes) {
		if (outQueue->empty()) break;
		buf[ret++] = outQueue->front();
		outQueue->pop();
	}
	return ret;
}

int ProcBuffers::getErrData(char *buf, int bytes) {
	int ret = 0;
	while (ret < bytes) {
		if (errQueue->empty()) break;
		buf[ret++] = errQueue->front();
		errQueue->pop();
	}
	return ret;
}

DWORD WINAPI ProcBuffers::StdoutReader(LPVOID arg) {
	ProcBuffers *obj = (ProcBuffers *)arg;

	ProcBuffers::ReadBuffer(obj->hChildStdoutRdDup, obj->outQueue);
	obj->outThreadActive = 0;
	ExitThread(0);
	return 0;
}
DWORD WINAPI ProcBuffers::StderrReader(LPVOID arg) {
	ProcBuffers *obj = (ProcBuffers *)arg;
	ProcBuffers::ReadBuffer(obj->hChildStderrRdDup, obj->errQueue);
	obj->errThreadActive = 0;
	ExitThread(0);
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

	outThreadActive = errThreadActive = 1;
	outThreadHandle = CreateThread(NULL, 0, ProcBuffers::StdoutReader, this, 0, &this->outThread);
	errThreadHandle = CreateThread(NULL, 0, ProcBuffers::StderrReader, this, 0, &this->errThread);

	fSuccess = ResumeThread(piProcInfo.hThread);
	if (fSuccess < 0) {
		printf("ResumeThread: %s\n", ErrorDescription(GetLastError()));
	}

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
    // suspend it so we can hook up to stderr/stdout before it starts
	// create new process group so we can send CTRL-BRK and CTRL-C
	bFuncRetn = CreateProcess(NULL, 
		cmdline,       // command line 
		NULL,          // process security attributes 
		NULL,          // primary thread security attributes 
		TRUE,          // handles are inherited 
		CREATE_SUSPENDED|CREATE_NEW_PROCESS_GROUP,// creation flags 
		NULL,          // use parent's environment 
		NULL,          // use parent's current directory 
		&siStartInfo,  // STARTUPINFO pointer 
		&piProcInfo);  // receives PROCESS_INFORMATION 

	if (bFuncRetn == 0) {
		printf("CreateProcess failed: %s\n", ErrorDescription(GetLastError()));
		return 0;
	} else {
		pid = piProcInfo.dwProcessId;
		return bFuncRetn;
	}
}


#define BUFSIZE 4096 
VOID ProcBuffers::ReadBuffer(HANDLE stream, CHARQUEUE *queue) {

	DWORD dwRead; 
	char *chBuf = new char[BUFSIZE]; 

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
	CloseHandle(stream);
	delete chBuf;
} 

VOID ErrorExit (LPTSTR lpszMessage) 
{ 
	fprintf(stderr, "%s\n", lpszMessage); 
	ExitProcess(0); 
} 



/*
 * Wrapper functions callable from "C"
 */
extern "C" {
	DWORD SpawnProcess(char *cmdline) {
		ProcBuffers *pb = new ProcBuffers(cmdline);
		pb->Start();
		ProcBuffers::putProcBuffer(pb->getPid(), pb);
		return pb->getPid();
	}

	int IsActive(DWORD proc) {
		ProcBuffers *pb = ProcBuffers::getProcBuffer(proc);
		int ret = FALSE;
		if (pb) {
			pb->lock();
			ret = pb->isRunning() || pb->hasData();
			pb->unlock();
		} else {
			//printf("No such pid: %d\n", proc);
		}
		return ret;
	}

	int GetStderr(DWORD proc, char *buf, int size) {
		ProcBuffers *pb = ProcBuffers::getProcBuffer(proc);
		if (!pb) {
			printf("GetStderr: unknown pid %d\n", proc);
			return 0;
		} else {
			pb->lock();
			int ret = pb->getErrData(buf, size);
			pb->unlock();
			return ret;
		}
	}
	int GetStdout(DWORD proc, char *buf, int size) {
		ProcBuffers *pb = ProcBuffers::getProcBuffer(proc);
		if (!pb) {
			printf("GetStdout: unknown pid %d\n", proc);
			return 0;
		} else {
			pb->lock();
			int ret = pb->getOutData(buf, size);
			pb->unlock();
			return ret;
		}
	}
	void CtrlBreak(DWORD proc) {
		ProcBuffers *pb = ProcBuffers::getProcBuffer(proc);
		if (!pb) {
			printf("CtrlBreak: unknown pid %d\n", proc);
		} else {
			pb->lock();
			pb->ControlBreak();
			pb->unlock();
		}
	}
	void CtrlC(DWORD proc) {
		ProcBuffers *pb = ProcBuffers::getProcBuffer(proc);
		if (!pb) {
			printf("CtrlBreak: unknown pid %d\n", proc);
		} else {
			pb->lock();
			pb->ControlBreak();
			pb->unlock();
		}
	}
	void FreeProcess(DWORD proc) {
		ProcBuffers *pb = ProcBuffers::getProcBuffer(proc);
		if (!pb) {
			printf("FreeProcess: unknown pid %d\n", proc);
			return;
		} else {
			pb->lock();
			ProcBuffers::putProcBuffer(pb->getPid(), NULL);
			delete pb;
		}
	}
}


DWORD main(int argc, char *argv[]) 
{ 
#if 0 /* Test C++ class */
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
#else /* Test "C" wrappers */
	DWORD proc = SpawnProcess("java -version");
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
