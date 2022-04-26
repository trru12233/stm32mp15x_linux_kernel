#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char *argv[])
{
	int fd, ret;
	int key_val;
	int tmp;
	fd = open(argv[1], O_RDONLY);
	if (fd < 0) {
		printf("cannot open %s\n", argv[1]);
		return -1;
    }
    for (;;){
	    read(fd, &key_val, sizeof(key_val));
        if(key_val != tmp) {
		printf("key res=%d\n", key_val);
		tmp = key_val;
	    }   
    }
    close(fd);
    return 0;
}