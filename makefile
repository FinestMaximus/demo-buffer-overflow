all:
	gcc -o exploit exploit.c
	gcc -o stack stack.c -fno-stack-protector
	./exploit
	./stack

clean:
	rm -fr exploit stack
