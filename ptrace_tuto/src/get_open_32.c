#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/ptrace.h>
#include <sys/reg.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/user.h>
#include <sys/wait.h>

#include <limits.h>

void
get_open_args(pid_t pid)
{
	struct user_regs_struct regs;
	unsigned char path[NAME_MAX + 1];
	int i;

	if (ptrace(PTRACE_GETREGS, pid, NULL, &regs) == -1)
		printf("ptrace getregs error\n");
	i = 0;
	while (1) {
		long tmp;
		char *cp;
		int j;

		tmp = ptrace(PTRACE_PEEKTEXT, pid, regs.ebx + i, NULL);
		cp =(char *) &tmp;
		for (j = 0; j < sizeof(tmp); j++) {
			path[i++] = cp[j];
			if (cp[j] == '\0')
				goto finalize;
			if (i > NAME_MAX) {
				printf("error, can't find \\0\n");
				exit(1);
			}
		}
	}
finalize:
	printf("open (\"%s\", %.8x)\n", path, (int)regs.ecx);
}

int
main()
{
	int pid, status;
	int insyscall;
	
        pid = fork();

        switch (pid) {
        case 0:
                ptrace(PTRACE_TRACEME, 0, NULL, NULL);
                execl("/bin/ls", "ls", NULL);
        case -1: 
                perror("fork ");
                exit(1);
        default:
                break;
        }

	insyscall = 0;
	while (1) {
		wait(&status);
		//is child exited
		if (WIFEXITED(status))
			break;

		if (insyscall == 1) {
			insyscall = 0;
		} else {
			long eax;
			eax = ptrace(PTRACE_PEEKUSER, pid, sizeof(eax) * ORIG_EAX, NULL);
			if (eax == __NR_open)
				get_open_args(pid);
			insyscall = 1;
		}
		ptrace(PTRACE_SYSCALL, pid, NULL, NULL);
	}
	return 0;
}
