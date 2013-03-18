.nr PP 2i
.
.de Fn
.  ds res_str \fB\\$1\fP
.  if (\\n[.$]>=2)\{\
.    as res_str \\$2\}
.  as res_str " \c
.res_str
.rm res_str
..
.de Ft
\fI\\$1\fP
..
.de Fd
\fI\$@\fP
..
.de Xr
.  ds res_str \fB\\$1\fP
.  if (\\n[.$]>=2)\{\
.    as res_str (\fB\\$2\fP)
.    if (\\n[.$]>2)\{\
.      as res_str \\$3\}\}
.  as res_str " \c
.res_str
.rm res_str
..
.de Dv
.  ds res_str \f[I]\\$1\fP
.  if (\\n[.$]>=2)\{\
.    as res_str \\$2\}
.  as res_str " \c
.res_str
.rm res_str
..
.de Va
.  ds res_str \fI\\$1\fP
.  if (!"\\$2"")\{\
.    as res_str \\$2\}
.  as res_str " \c
.res_str
.rm res_str
..
.de Fa
.  ds res_str \fB\\$1\fP
.  if !"\\$2""\{\
.    as res_str \\$2\}
.  as res_str " \c
.res_str
.rm res_str
..
.
.TL 
Отладка с помощью ptrace
.AU
Борис Липин <lonely.ruyk@mail.ru>
.AI
Сыктывкарский Государственный Университет
Лаборатория Программирования и Прикладной Математики
http://amplab.syktsu.ru
.AB no
.AE
.NH 1
Введение
.PP
Часто для того,
чтобы разобраться почему код работает не так,
программист прибегает к помощи отладчиков,
однако,
то как они устроены и каким образом действуют, известно далеко не всем.
В этой статье будет дано краткое описание механизма отладки,
который используется операционной системой Linux и приведён 
простой пример его использования.
.
.NH 1
Основные сведения
.PP
В OC Linux для отладки используется системный вызов
.Xr ptrace 2 .
Ниже приведён синтаксис этого вызова.
.RS
.sp
#include <sys/ptrace.h>
.br
long
.br
.ns
\f[BI]ptrace\fP(
enum __ptrace_request 
.Fa request , 
pid_t 
.Fa pid , 
void *
.Fa addr , 
void *
.Fa data
)
.rs
.sp
.RE
Аргумент
.Fa request
определяет тип операции:
будет ли это попытка начать отладку процесса,
или это будет запрос данных по какому-либо адресу.
Все прочие аргументы являются опциональными и зависят от значения
.Fa request .
.br
Начать отладку процесса можно двумя способами:
.RS
.IP 1. 3
C помощью запроса 
.Dv PTRACE_TRACEME
текущий процесс будет отлаживаться его родителем.
Любой сигнал,
полученный текущим процессом,
вызовет его остановку,
а родительский процесс может быть оповещён об этом сигналом
.Dv SIGCHLD .
Затем родитель при помощи системного вызова
.Xr wait 2
.Pq или подобного
узнаёт идентификатор остановленного процесса.
Cледует заметить,
что для этого типа запроса все остальные аргументы игнорируются.
.
.IP 2.
С помощью запроса
.Dv PTRACE_ATTACH
можно подключиться к уже существующему процессу,
передав в
.Fa pid
его идентификатор.
.RE
.
.PP
При успешном завершении всех типов запросов,
за исключением
.Dv PTRACE_PEEK* ,
.Fn ptrace
возвращает 0.
Если запрос завершился с ошибкой,
.Fn ptrace
возвращает -1,
а код ошибки заносится в
.Va errno .
.PP
Кратко опишем некоторые типы запросов:
.RS
.IP \(bu 3
.Dv PTRACE_GETREGS ,
.br
.Dv PTRACE_SETREGS ,
.br
.Dv PTRACE_GETFPREGS ,
.br
.Dv PTRACE_SETFPREGS
.PP
Получаем или изменяем основные регистры или регистры FPU.
Указатель на структуру с регистрами передаётся в
.Fa data.
Для основных регистров используется структура
.Vt struct user_regs_struct ,
для регистров FPU
.Vt struct user_fpregs_struct .
Определения структур находятся в
\fI<sys/user.h>\fP.
.IP \(bu 3
.Dv PTRACE_PEEK_DATA ,
.br
.Dv PTRACE_PEEK_TEXT ,
.br
.Dv PTRACE_POKE_DATA ,
.br
.Dv PTRACE_POKE_TEXT
.PP
Получаем или изменяем данные в памяти исследуемого процесса
по переданному в
.Fa addr
адресу.
При запросе
.Dv PTRACE_PEEK*
.PP
В случае успеха возвращаются запрошенные данные.
Так как -1
.Pq Li 0xffffffff
также может быть адресом,
для проверки на ошибку необходимо дополнительно
проверять значение
.Va errno .
.IP \(bu 3
.Dv PTRACE_CONT
.PP
Продолжает выполнение остановленного процесса.
Если
.Fa data
не
.Dv NULL
и не
.Dv SIGSTOP ,
.PP
Значение интерпретируется как сигнал,
который посылается процессу.
.IP \(bu 3
.Dv PTRACE_SINGLESTEP ,
.br
.Dv PTRACE_SYSCALL
.PP
Продолжает выполнение остановленного процесса,
как и в случае с 
.Dv PTRACE_CONT ,
но указывает,
что процесс должен остановиться при переходе к следующей инструкции
.Dv PTRACE_SINGLESTEP
или при входе/выходе из системного вызова
.Dv PTRACE_SYSCALL .
Аргумент
.Fa data
будет интерпретирован как и в случае с
.Dv PTRACE_CONT .
.IP \(bu 3
.Dv PTRACE_SINGLESTEP ,
.br
.Dv PTRACE_DETACH
.PP
Отменяет эффекты 
.Dv PTRACE_TRACEME ,
.Dv PTRACE_ATTACH
для процесса с указанным
.Fa pid ,
и продолжает выполнение как в случае с
.Dv PTRACE_CONT .
.LP
.RE
Важно помнить,
что все запросы,
перечисленные выше,
работают только если отлаживаемый процесс остановлен,
в чём нужно убедиться с помощью системного вызова
.Xr wait 2 ,
иначе
.Fn ptrace
вернёт -1 и установит
.Va errno
в
.Er ESRCH .
.PP
Описание остальных запросов,
не перечисленных выше,
можно посмотреть в
.Xr ptrace 2 .
.NH 1
Примеры
.PP
Теперь напишем простой пример использования
.Fn ptrace .
Программа будет отслеживать все попытки вызова
.Xr open 2 ,
сделанные дочерним процессом.
В нашем примере роль отлаживаемой программы будет играть
.Ic /bin/ls .
Для краткости,
опущены проверки на ошибки и не учитывается порядок байтов.
В реальной программе,
пожалуй,
так делать не стоит.
Две версии файла с примером 
(одна для x86, другая для x86_64) запакованы в архив вместе с
данной статьёй.