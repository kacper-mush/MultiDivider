.PHONY: all clean

all: mdiv_example

mdiv.o: mdiv.asm
	nasm -f elf64 -w+all -w+error -o $@ $<

mdiv_example.o: mdiv_example.c
	gcc -c -Wall -Wextra -std=c17 -O2 -o $@ $<

mdiv_example: mdiv.o mdiv_example.o
	gcc -z noexecstack -o $@ $^

clean:
	rm -rf mdiv_example *.o
