
OBJS=linux_nic.o nic_control.o \
	linux_cpu.o cpu_sucker.o \
	linux_pow.o power_off.o \
	linux_drv.o drive.o

LIBS=

JNI_INCLUDE=-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux

all:	main cpu_sucker nic_control power_off unmount libutb.so

main: $(OBJS) Makefile main.c
	gcc -o main main.c $(OBJS) $(LIBS)

nic_control:	main
	ln -s main nic_control

cpu_sucker:	main
	ln -s main cpu_sucker

power_off:	main
	ln -s main power_off

unmount:	main
	ln -s main unmount

linux_drv.o: linux_drv.c drive.h Makefile
	gcc -fPIC -c linux_drv.c $(JNI_INCLUDE)

drive.o: drive.c drive.h Makefile
	gcc -fPIC -c drive.c

linux_pow.o: linux_pow.c power_off.h Makefile
	gcc -fPIC -c linux_pow.c $(JNI_INCLUDE)

power_off.o: power_off.c power_off.h Makefile
	gcc -fPIC -c power_off.c

linux_nic.o: linux_nic.c nic_control.h Makefile
	gcc -fPIC -c linux_nic.c $(JNI_INCLUDE)

nic_control.o: nic_control.c nic_control.h Makefile
	gcc -fPIC -c nic_control.c

linux_cpu.o: linux_cpu.c cpu_sucker.h Makefile
	gcc -fPIC -c linux_cpu.c $(JNI_INCLUDE)

clean:
	rm $(OBJS)
	rm libutb.so
	rm main
	rm nic_control
	rm cpu_sucker
	rm power_off
	rm unmount

libutb.so: $(OBJS)
	gcc -o libutb.so -shared \
		$(JNI_INCLUDE) $(OBJS) -static -lc

deploy: libutb.so
	cp libutb.so ../../lib/linux

