section .data ;erase
    msg db 'clone %d', 0x0a, 0
    nullStr db 'NULL', 0
    leftSquareBracket db '[', 0
    rightSquareBracket db ']', 0
    comma db ',', 0
    eqNode db 'eqNode ',0
section .rodata

section .text

extern malloc
extern free
extern fprintf
extern printf

global strLen
global strClone
global strCmp
global strConcat
global strDelete
global strPrint
global listNew
global listAddFirst
global listAddLast
global listAdd
global listRemove
global listRemoveFirst
global listRemoveLast
global listDelete
global listPrint
global n3treeNew
global n3treeAdd
global n3treeRemoveEq
global n3treeDelete
global nTableNew
global nTableAdd
global nTableRemoveSlot
global nTableDeleteSlot
global nTableDelete

doNothing:
    ret

strLen:
; preserves rdi, returns len in rax

    push rbp ; push old stack base
    mov rbp, rsp ; set stack base to current stack top
    push rbx
    add rsp, 8

    mov rax, 0
    mov rbx, rdi

    .iterateString:
        cmp byte [rbx], 0
        jne .count
        jmp .end 

    .count:
        add rbx, 1
        add eax, 1 
        jmp .iterateString

    .end:
        sub rsp, 8
        pop rbx;
        pop rbp ; reset stack base to prev stack
        ret

strClone:
    push rbp
    mov rbp, rsp
    mov r8, rdi ; r8 contains pointer to input string

    push r8
    push rdi

    call strLen 
    mov rdi, rax
   
    add rdi, 1 ; we want to make space for the string termination char
    call malloc ; rax contains pointer to output string

    pop rdi
    pop r8
    
    xor rcx, rcx ; rcx will be our counter

    .iterateString:
        cmp byte [r8+rcx] , 0
        je .end

    .countAndAddChar:
        mov dl, [r8+rcx]
        mov [rax+rcx], dl 
        add rcx, 1
        jmp .iterateString

    .end: 
        mov byte [rax+rcx], 0
        pop rbp
        ret

strCmp:
    ; rdi contains pointer to string a
    ; rsi contains pointer to string b
    ; compares with lexicographical order
    ; returns 1 if a > b
    ; returns 0 if a == b
    ; returns -1 if a < b

    push rbx    

    .iterateString:

        cmp byte [rdi], 0
        je .aIsOver

        cmp byte [rsi], 0
        je .aIsBigger

        mov bl, byte [rsi]
        cmp byte [rdi] , bl
        je .increasePointers
        jns .aIsBigger
        jmp .bIsBigger

    .increasePointers:
        add rdi, 1
        add rsi, 1
        jmp .iterateString

    .aIsOver:
        cmp byte [rsi], 0
        je .stringsAreEqual
        jmp .bIsBigger

    .aIsBigger:
        mov eax, -1
        jmp .end 

    .bIsBigger:
        mov eax, 1
        jmp .end

    .stringsAreEqual:
        mov eax, 0

    .end:
        pop rbx
        ret

strConcat:
    ; rdi contains pointer to string a
    ; rsi contains pointer to string b
    ; returns pointer to new string s, such that s = a + b
    ; liberates memory from a and b
    ; warning: a and b should point to dynamic memory
    ;   otherwise you will get invalid free!

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi ; now rbx contains pointer to string a
    mov r14, rsi ; now r14 contains pointer to string b

    call strLen
    mov r12, rax ; get size of string a
    mov r13, rax ; we want to save size from string a 

    mov rdi, r14
    call strLen ; get size of string b
    add r12, rax ; r12 = size(ret) = size( a + b)
    
    mov rdi, r12
    add rdi, 1 ; we want to make space for the string termination char
    call malloc ; rax now contains pointer to new string

    xor rdi, rdi ;  rdi will be our counter

    .iterateA:
        cmp byte [rbx + rdi], 0 ; check ith char from a 
        jne .addCharFromA ; if it is not 0, add it to ret
        xor rdi, rdi ; else, reset counter
        jmp .iterateB ; and start adding chars from b
   
    .addCharFromA:
        mov sil, byte [rbx + rdi] ; get ith char from a
        mov [rax + rdi], sil ; add it to ith position from ret
        add rdi, 1 ; increment counter
        jmp .iterateA

    .iterateB:
        cmp byte [r14 + rdi], 0 ; check ith char from b 
        jne .addCharFromB ; if it is not 0, add it to ret
        jmp .end ; else, we have done our job!
         
    .addCharFromB:
        mov sil, byte [r14+ rdi] ; get ith char from b
        mov r15, rdi
        add r15, r13 ; r15 = offest = i + size(a)
        mov byte [rax + r15], sil ; ret[offset] = b[i]
        add rdi, 1 ; increment counter
        jmp .iterateB

    .end:

        mov byte [rax + r12], 0; set last byte from ret to zero

        mov r12, rax ; preserve pointer to res string

        cmp rbx, r14 ; do a and b come from the same pointer?
        je .eraseB

        mov rdi, rbx
        call free ; erase string a

    .eraseB:
        mov rdi, r14
        call free ; erase string b
        
        mov rax, r12 ; return pointer from res string

        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        ret

strDelete:
    push rbp
    mov rbp, rsp

    call free

    pop rbp
    ret
 
strPrint:
    ; rdi contains char *a
    ; rsi contains FILE *pfile
    ; Prints string pointed by a.
    ; If it is empty, prints "NULL".

    push rbp
    mov rbp, rsp
    push r12
    push rbx

    mov rbx, rdi ; rdx will contain a
    mov r12, rsi ; r12 will contain pfile

    call strLen ; eax now contains size of input string
    cmp eax, 0
    je .printNull
    jmp .end

    .printNull:
        mov rbx, nullStr ; override pointer to input string

    .end:
        mov rdi, r12 ; pfile is first argument
        mov rsi, rbx ; second argument is what we want to print
        call fprintf

        pop rbx
        pop r12
        pop rbp         
        ret


; LIST OFFSETS
    %define offset_data 0
    %define offset_next 8
    %define offset_prev 16

    %define offset_first 0
    %define offset_last 8
    
listNew:
    push rbp
    mov rbp, rsp

    mov rdi, 16
    call malloc ; 16 bytes for two pointers

    mov qword [rax + offset_first], 0
    mov qword [rax + offset_last], 0 ; set both pointers to zero
    
    pop rbp
    ret

listAddFirst:
    ; rdi contains *l, pointer to list 
    ; rsi contains *d, pointer to data

    push rbx
    push r12
    push r13

    mov rbx, rdi ; save *l into rbx
    mov r12, rsi ; save *d into r12

    ; create a new node
    mov rdi, 24
    call malloc ; 24 bytes for three pointers
    mov qword [rax + offset_data], r12 ; let the node point to d
    mov qword [rax + offset_next], 0; initialize empty
    mov qword [rax + offset_prev], 0; initialize empty
    
    ; is the list is empty?
    cmp qword [rbx + offset_first], 0
    jne .insertAtBeginning

    ; if it is empty
    mov qword [rbx + offset_first], rax ; l->first = newNode 
    mov qword [rbx + offset_last], rax ; l->end = newNode 
    jmp .end

    .insertAtBeginning:
        mov r13, qword [rbx + offset_first]
        mov qword [r13 + offset_prev], rax ; l->first->prev = newNode 
        mov qword [rax + offset_next], r13 ; newNode->next = l->first
        mov qword [rbx + offset_first], rax ; l->first = newNode
   
    .end:

        pop r13
        pop r12
        pop rbx

        ret    

listAddLast:
    ; rdi contains *l, pointer to list
    ; rsi contains *d, pointer to data

    push rbx
    push r12
    push r13

    mov rbx, rdi ; save *l into rbx
    mov r12, rsi ; save *d into r12

    ; create a new node
    mov rdi, 24
    call malloc ; 24 bytes for three pointers
    mov qword [rax + offset_data], r12 ; let the node point to d
    mov qword [rax + offset_next], 0; initialize empty
    mov qword [rax + offset_prev], 0; initialize empty

    ; is the list empty?
    cmp qword [rbx + offset_first], 0
    jne .insertAtEnd

    ; if it is empty
    mov qword [rbx + offset_first], rax ; l->first = newNode
    mov qword [rbx + offset_last], rax ; l->end = newNode
    jmp .end
    
    .insertAtEnd:
        mov r13, qword [rbx + offset_last] ; newNode->prev = l->last
        mov qword [rax + offset_prev], r13

        ; l->last->next = newNode
        mov rsi, qword [rbx + offset_last] ; rsi = l->last
        mov qword [rsi + offset_next], rax ; rsi = l->last->next

        mov qword [rbx + offset_last], rax ; l->last = newNode

    .end:

        pop r13
        pop r12
        pop rbx

        ret

listAdd:
    ; rdi contains *l, pointer to list
    ; rsi contains *d, pointer to data
    ; rdx contains *fc pointer to funcComp

    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    sub rsp, 24 ; make space for two pointers and also align to 16 bytes
    %define it_prev_offset -8
    %define it_next_offset -16

    mov rbx, rdi ; save *l into rbx
    mov r12, rsi ; save *d into r12
    mov r14, rdx ; save *fc into r14

    ; create a new node
    mov rdi, 24
    call malloc ; 24 bytes for three pointers
    mov qword [rax + offset_data], r12 ; let the node point to d
    mov qword [rax + offset_prev], 0 ; initialize node pointer to NULL
    mov qword [rax + offset_next], 0
    mov r15, rax ; save *newNode into r15

    ; is the list empty?
    cmp qword [rbx + offset_first], 0
    jne .tryInsertAtBeginning

    ; if it is empty
    mov qword [rbx + offset_first], r15 ; l->first = newNode
    mov qword [rbx + offset_last], r15 ; l->end = newNode
    jmp .end  
    
    .tryInsertAtBeginning:
        mov rdi, r12
        mov rsi, qword [rbx + offset_first] ; rsi = l->first 
        mov rsi, qword [rsi + offset_data] ; rsi = (l->first).d 
        call r14 ; funcComp(d, (l->first).data)
        cmp eax, -1 ; if(d > (l->first).data)
        je .insertOrdered
        
        mov r13, qword [rbx + offset_first] ; r13 = l->first
        mov qword [r13 + offset_prev], r15 ; l->first->prev = newNode
        mov qword [r15 + offset_next], r13 ; newNode->next = l->first

        mov qword [rbx + offset_first], r15 ; l->first = newNode       
        jmp .end

    .insertAtEnd:
        mov r13, qword [rbx + offset_last] ; r13 = l->last
        mov qword [r13 + offset_next], r15 ; l->last->next = newNode
        mov qword [r15 + offset_prev], r13 ; newNode->prev = l->last
        mov qword [rbx + offset_last], r15 ; l->last = newNode
        jmp .end

    .insertOrdered:
        ; initialize pointers for iteration
        mov r13, qword [rbx + offset_first]
        mov qword [rbp + it_prev_offset], r13 ; prev = l->first
        mov r13, qword [r13 + offset_next]
        mov qword [rbp + it_next_offset], r13 ; next = (l->first).next

        .loopThroughList:
            mov rdi, r12
            mov rsi, qword [rbp + it_next_offset]
            cmp rsi, 0 ; if(it_next == NULL)  
            je .insertAtEnd 
            mov rsi, [rsi + offset_data]
            call r14 ; funcComp(d, it_next->data)
            cmp eax, -1 ; if(d <= it_next->data) insertHere
            jne .insertHere
            mov r13, qword [rbp + it_next_offset]
            mov qword [rbp + it_prev_offset], r13 ; it_prev = it_next

            mov r8, qword [r13 + offset_next]
            mov qword [rbp + it_next_offset], r8 ; it_next = it_next->next
            jmp .loopThroughList

        .insertHere:
            mov r13, qword [rbp + it_prev_offset]
            mov [r13 + offset_next], r15 ; it_prev->next = newNode

            mov qword [r15 + offset_prev], r13 ; newNode->prev = it_prev

            mov r13, qword [rbp + it_next_offset]
            mov [r13 + offset_prev], r15 ; it_next->prev = newNode

            mov qword [r15 + offset_next], r13 ; newNode->next = it_next
            
    .end:
        add rsp, 24 
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        pop rbp
        
        ret

listRemove:
    ; rdi contains *l, pointer to list
    ; rsi contains *data, pointer to the value to be identified and eliminated in the list.
    ; rdx contains *fc, pointer to the function used to compare data from list nodes
    ; rcx contains *fd, pointer to the function used to delete data fom list nodes

    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    ; is list empty?
    cmp qword [rdi + offset_first], 0
    je .end


    cmp rcx, 0
    jne .deleteFunctionIsSetup
    mov rcx, doNothing; TODO: this overriding may be alta mentira

    .deleteFunctionIsSetup:
        ; preserve inputs
        mov rbx, rdi ; now rbx contains l
        mov r12, rsi ; now r12 contains data
        mov r13, rdx ; now r13 contains fc
        mov r14, rcx ; now r14 contains delete function

        mov r15, qword [rbx + offset_first] ; r15 = l->first
        ; r15 will be hold the reference to the current node.

    .iterateList:
        mov rsi, qword [r15 + offset_data] ; rsi = node->data
        mov rdi, r12 ; rdi = data
        call r13 ; fc(data, node->data)
        cmp eax, 0
        je .foundNodeToDelete
        
        ; If there is a next node, point to it. Otherwise, finish iteration.
        mov r15, qword [r15 + offset_next] ; node = node->next
        cmp r15, 0 ; if(node->next == NULL)
        je .end
        jmp .iterateList
    
    .foundNodeToDelete:
        mov rsi, qword [r15 + offset_next] ; rsi = node->next
        mov rdi, qword [r15 + offset_prev] ; rdi = node->prev

        ; if(node->prev == NULL) 
        cmp rdi, 0
        je .itIsFirstNode
        ; handle pointers from previous node
        mov qword [rdi + offset_next], rsi ; node->prev->next = node->next
        jmp .analizeNext       
 
    .itIsFirstNode:
        mov qword [rbx + offset_first], rsi ; l->first = node->next

    .analizeNext:
        ; if(!node->next == NULL) node->next->prev = node->prev
        cmp rsi, 0
        je .itIsLastNode
        ; then handle pointers from next node
        mov qword [rsi + offset_prev], rdi ; node->next->prev = node->prev        
        jmp .deleteNode

    .itIsLastNode:
        mov qword [rbx + offset_last], rdi ; l->last = node->prev
    
    .deleteNode:
        ; delete(node->data)
        mov rdi, qword [r15 + offset_data]
        call r14
          
        ; delete(node)
        mov rdi, r15 
        mov r15, qword [r15 + offset_next] ; node = node->next
        call free
            
        ; if(node == NULL) we are done!
        cmp r15, 0
        jne .iterateList
            
    .end:   
        add rsp, 8 
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        pop rbp

    ret

listRemoveFirst:
    ; rdi contains *l pointer to list
    ; rsi contains *fd pointer to delete function

    push rbx
    push r12
    push rbp
    mov rbp, rsp

    mov rbx, rdi ; rbx now contains l
    mov r12, rsi ; r12 now contains fd

    ; is list empty?
    cmp qword [rdi + offset_first], 0
    je .end

    cmp r12, 0
    jne .deleteFunctionIsSetup
    mov r12, doNothing ; TODO: this overriding may be alta mentira

    .deleteFunctionIsSetup:
        ; delete(first->data)
        mov rdi, qword [rbx + offset_first] ; rdi = l->first
        mov rdi, qword [rdi + offset_data] ; rdi = l->first->data
        call r12

        ; if(l->first == l->last) l->last = NULL
        mov r12, qword [rbx + offset_first] ; r12 = l->first
        cmp r12, qword [rbx + offset_last] ; l->first == l->last
        jne .dontTouchLast
        mov qword [rbx + offset_last], 0

    .dontTouchLast:
        ; keep = first->next
        mov r12, qword [r12 + offset_next] 

        mov qword [r12 + offset_prev], 0 ; first->next->prev = NULL        

        ; delete(first)
        mov rdi, qword [rbx + offset_first] ; rdi = l->first
        call free

        ; first = keep
        mov qword [rbx + offset_first], r12

    .end:
        pop rbp
        pop r12
        pop rbx

        ret

listRemoveLast:
    ; rdi contains *l pointer to list
    ; rsi contains *fd pointer to delete function

    push rbx
    push r12
    push rbp
    mov rbp, rsp

    mov rbx, rdi ; rbx now contains l
    mov r12, rsi ; r12 now contains fd

    ; is list empty?
    cmp qword [rdi + offset_first], 0
    je .end

    cmp r12, 0
    jne .deleteFunctionIsSetup
    mov r12, doNothing ; TODO: this overriding may be alta mentira
    
    .deleteFunctionIsSetup:

        ; delete(last->data)
        mov rdi, qword [rbx + offset_last] ; rdi = l->last
        mov rdi, qword [rdi + offset_data] ; rdi = l->last->data
        call r12

        ; if(l->first == l->last) l->first = NULL
        mov r12, qword [rbx + offset_last] ; r12 = l->last
        cmp r12, qword [rbx + offset_first] ; l->first == l->last

        jne .dontTouchFirst
        mov qword [rbx + offset_first], 0

    .dontTouchFirst:

        ; keep = last->prev
        mov r12, qword [r12 + offset_prev]

        mov qword [r12 + offset_next], 0 ; last->prev->next = NULL

        ; delete(last)
        mov rdi, qword [rbx + offset_last] ; rdi = l->last
        call free

        ; last = keep
        mov qword [rbx + offset_last], r12

    .end:
        pop rbp
        pop r12
        pop rbx

        ret

listDelete:
    ; rdi contains *l, pointer to list
    ; rsi contains *fd, pointer to the function used to delete data fom list nodes

    push rbx
    push r12
    push r13

    mov rbx, rdi ; now rbx contains l
    mov r12, rsi ; now r12 contains fd


    cmp r12, 0
    jne .deleteFunctionIsSetup
    mov r12, doNothing ; TODO: this overriding may be alta mentira

    .deleteFunctionIsSetup:
        mov r13, qword [rbx + offset_first] ; now r13 contains l->first

    ; we are going to use r13 as node iterator
    .iterateDeleting:
        cmp r13, 0
        je .end 

        mov rdi, qword [r13 + offset_data] ; rdi = node->data
        call r12 ; fd(node->data)

        mov rdi, r13 ; rdi = node
        mov r13, qword [r13 + offset_next]
        call free ; free(node)
        jmp .iterateDeleting

    .end:
        mov rdi, rbx ; delete(l)
        call free

        pop r13    
        pop r12
        pop rbx
        ret

listPrint:
    ; rdi contains *l, pointer to list
    ; rsi contains FILE *pfile
    ; rdx contains *fp, pointer to the printer function

    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8

    mov rbx, rdi ; now rbx contains l
    mov r12, rsi ; now r12 contains pfile
    mov r13, rdx ; now r13 contains fp

    ; fprintf("[")
        mov rdi, r12
        mov rsi, leftSquareBracket
        call fprintf

    ; currNode = l->head
    mov r14, qword [rbx + offset_first] ; r14 will be our currNode

    ; while(currNode != NULL)
    .printNodes:
        cmp r14, 0
        je .noNodesToPrint

        ; fp(currNode->data, pfile)
        mov rdi, qword [r14 + offset_data]
        mov rsi, r12 
        call r13
  
        ; currNode = currNode->next 
        mov r14, qword [r14 + offset_next]
 
        ; if(currNode->next != NULL)
        cmp r14, 0
        jne .printComma
        jmp .printNodes

    ; fprintf(",")
    .printComma:
        mov rdi, r12
        mov rsi, comma
        call fprintf
        jmp .printNodes


    .noNodesToPrint:
        ; fprintf("]")
        mov rdi, r12
        mov rsi, rightSquareBracket 
        call fprintf
      
        add rsp, 8
        pop r14 
        pop r13
        pop r12
        pop rbx
        ret


; NTREE OFFSETS 
    %define offset_first 0

    %define offset_data 0
    %define offset_left 8
    %define offset_center 16
    %define offset_right 24

createN3Node:
    ; takes 1 parameter, pointer to data
    ; returns n3treeElem_t n such that n->data = data

    push rbx
    mov rbx, rdi ; rbx = data
    
    mov rdi, 32
    call malloc ; 32 bytes for the four pointers of a node.
    
    mov qword [rax + offset_data], rbx
    mov qword [rax + offset_left], 0
    mov qword [rax + offset_center], 0
    mov qword [rax + offset_right], 0

    pop rbx
    ret

n3treeNew:
    push rbp
    mov rbp, rsp

    mov rdi, 8
    call malloc ; 8 bytes for our pointer

    mov qword [rax + offset_first], 0 ; t->first = NULL

    pop rbp
    ret

n3treeAddRecur:
    ; rdi contains *t, pointer to node
    ; rsi contains *data
    ; rdx contains *fc, pointer to the compare function
    
    push rbx
    push r12
    push r13

    mov rbx, rdi ; rbx will hold t
    mov r12, rsi ; r12 will hold data
    mov r13, rdx ; r13 will hold fc

    ; compare(t->data, data)
    mov rdi, qword [rdi + offset_data]
    call r13
    cmp eax, 0
    je .goMiddle
    jg .goRight
    jl .goLeft

    .goMiddle:
    ; if(t->data == data)
        ; if(t->center == NULL) ; t->center = listNew()
        cmp qword [rbx + offset_center], 0
        je .createList
        jmp .insertDataInList

    .createList:
        call listNew
        mov qword [rbx + offset_center], rax

    .insertDataInList:
        ; listAddLast(t->center, data)
        mov rdi, qword [rbx + offset_center]
        mov rsi, r12
        call listAddLast
        jmp .end
    
    ; if(t->data < data)
    .goRight:
        cmp qword [rbx + offset_right], 0  ; if(t->right == NULL)
        je .addRightNode

        ; else 
        mov rdi, qword [rbx + offset_right]
        mov rsi, r12
        mov rdx, r13
        call n3treeAddRecur ; n3treeAddRecur(t->right, data, fc)
        jmp .end

    .addRightNode:
        mov rdi, r12
        call createN3Node ; n3treeElem_t(data)
        mov qword [rbx + offset_right], rax ; t->right = newNode
        jmp .end

    .goLeft:
        cmp qword [rbx + offset_left], 0  ; if(t->left== NULL)
        je .addLeftNode

        ; else
        mov rdi, qword [rbx + offset_left]
        mov rsi, r12
        mov rdx, r13
        call n3treeAddRecur ; n3treeAddRecur(t->left, data, fc)
        jmp .end

    .addLeftNode:
        mov rdi, r12
        call createN3Node ; n3treeElem_t(data)
        mov qword [rbx + offset_left], rax ; t->left= newNode
        jmp .end

    .end:
        pop r13
        pop r12
        pop rbx
        ret


n3treeAdd:
    ; rdi contains *t, pointer to ntree 
    ; rsi contains *data
    ; rdx contains *fc, pointer to the compare function

    push rbx
    push r12
    push r13

    mov rbx, rdi ; rbx will hold t
    mov r12, rsi ; r12 will hold data
    mov r13, rdx ; r13 will hold fc

    ; if(t->first == NULL) t->first = newNode
    cmp qword [rdi + offset_first], 0
    je .addFirstNode
    ; else
    mov rdi, qword [rdi + offset_first]
    mov rsi, r12
    mov rdx, r13
    call n3treeAddRecur ; n3treeAddRecur(t->first, data, fc)
    jmp .end    

    .addFirstNode:
        mov rdi, r12
        call createN3Node ; n3treeElem_t(data)
        mov qword [rbx + offset_first], rax
        
    .end:
        pop r13
        pop r12
        pop rbx
        ret


n3treeRemoveEqRecur:
    ; recursively erases all elements from nodes lists
    ; rdi = n3treeElem_t *currNode
    ; rsi = funcDelete_t* fd

    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi ; rbx = currNode
    mov r12, rsi ; rsi = fd

    ; if(currNode == NULL) return
    cmp rbx, 0
    je .end 

    ; deletes nodes from current list
    mov rdi, qword [rdi + offset_center]
    cmp rdi, 0
    je .tryToGoLeft
    call listDelete    
    call listNew
    mov qword [rbx + offset_center], rax

    .tryToGoLeft:
        cmp qword [rbx + offset_left], 0  ; if(t->left== NULL)
        jne .recurCallLeft

    .tryToGoRight:
        cmp qword [rbx + offset_right], 0  ; if(t->right == NULL)    
        jne .recurCallRight
        jmp .end

    .recurCallLeft:
        mov rdi, qword [rbx + offset_left] 
        mov rsi, r12
        call n3treeRemoveEqRecur
        jmp .tryToGoRight

    .recurCallRight:
        mov rdi, qword [rbx + offset_right] 
        mov rsi, r12
        call n3treeRemoveEqRecur

    .end:
        pop r12
        pop rbx
        pop rbp
        ret

n3treeRemoveEq:
    ; recursively erases all elements from nodes lists
    ; rdi = n3tree_t *t
    ; rsi = funcDelete_t* fd
   
    push rbp
    mov rbp, rsp
 
    cmp rsi,0
    jne .deleteFunctionIsSetup
    mov rsi, doNothing ; TODO: this overriding may be alta mentira


    .deleteFunctionIsSetup:
        ; pass root node pointer to recursive function 
        mov rdi, qword [rdi + offset_first]
        call n3treeRemoveEqRecur

        pop rbp
        ret

n3treeDeleteRecur:
    ; recursively erases all nodes 
    ; rdi = n3treeElem_t *currNode
    ; rsi = funcDelete_t* fd

    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi ; rbx = currNode
    mov r12, rsi ; r12 = fd

    ; if(currNode == NULL) return
    cmp rbx, 0
    je .end

    cmp qword [rbx + offset_center], 0
    je .tryToGoLeft
    ; deletes nodes from current list
    mov rdi, qword [rbx + offset_center]
    call listDelete

    .tryToGoLeft:
        cmp qword [rbx + offset_left], 0  ; if(t->left== NULL)
        jne .recurCallLeft

    .tryToGoRight:
        cmp qword [rbx + offset_right], 0  ; if(t->right == NULL)
        jne .recurCallRight
        jmp .deleteCurrNode

    .recurCallLeft:
        mov rdi, qword [rbx + offset_left]
        mov rsi, r12
        call n3treeDeleteRecur
        jmp .tryToGoRight

    .recurCallRight:
        mov rdi, qword [rbx + offset_right]
        mov rsi, r12
        call n3treeDeleteRecur

    .deleteCurrNode:
        ; fd(currNode->data)
        mov rdi, qword [rbx + offset_data]
        call r12

        ; free(currNode)
        mov rdi, rbx
        call free

    .end:
        pop r12
        pop rbx
        pop rbp
        ret 

n3treeDelete:
    ; recursively erases all nodes
    ; rdi = n3tree_t *t
    ; rsi = funcDelete_t* fd

    push rbp
    mov rbp, rsp
    push rbx
    push r14

    mov rbx, rdi ; rbx = t
    mov r14, rsi ; t14 = fd

    cmp r14, 0
    jne .deleteFunctionIsSetup
    mov r14, doNothing ; TODO: this overriding may be alta mentira

    .deleteFunctionIsSetup:
        ; pass root node pointer to recursive function
        mov rdi, qword [rbx + offset_first]
        mov rsi, r14
        call n3treeDeleteRecur 

        mov rdi, rbx
        call free

        pop r14
        pop rbx
        pop rbp
        ret


; NTABLE OFFSETS
    %define offset_listArray 0
    %define offset_size 8

nTableNew:
    ; edi contains uint32_t size
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8

    xor rbx, rbx
    mov ebx, edi ; preserve size

    xor rdi, rdi
    mov edi, ebx
    sal rdi, 3 ; rdi = size * 8
    call malloc ; 8 bytes for each pointer to list
    mov r12, rax ; r12 = listArray

    mov rdi, 16
    call malloc ; 
    mov r13, rax
    mov qword [r13 + offset_listArray], r12 ; r13 is now holding pointer to array 
    mov dword [r13 + offset_size], ebx

    ; ebx is going to be our counter
    .initializeEmptyLists:
        cmp ebx, 0
        je .end
        
        sub ebx, 1
        call listNew
        ; listArray[ebx] = listNew()
        mov qword [r12 + rbx * 8], rax 
        jmp .initializeEmptyLists
        
    .end:
        mov rax, r13
        add rsp, 8
        pop r13
        pop r12
        pop rbx
        pop rbp

        ret

nTableAdd:
    ; rdi = nTable_t* t
    ; esi = uint32_t slot 
    ; rdx = void* data
    ; rcx = funcCmp_t* fc

    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi ; now rbx contains t
    mov r13, rdx ; now r13 contains data
    mov r14, rcx ; now r14 contains fc

    ; r12d = slot % t->size
    xor rdx, rdx
    mov eax, esi
    div dword [rbx + offset_size]
    xor r12, r12
    mov r12d, edx

    ; *l = t->listArray[slot]
    mov r15, qword [rbx + offset_listArray]
    mov r15, qword [r15 + r12 * 8]

    ; listAdd
    mov rdi, r15
    mov rsi, r13
    mov rdx, r14
    call listAdd ; (l, data, fc)

    .end:
        pop r14
        pop r13
        pop r12
        pop rbx
        pop rbp

        ret
    
nTableRemoveSlot:
    ; rdi = nTable_t* t
    ; esi = uint32_t slot
    ; rdx = void* data
    ; rcx = funcCmp_t* fc
    ; r8 = funcDelete_t* fd

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi ; now rbx contains t
    mov r13, rdx ; now r13 contains data
    mov r14, rcx ; now r14 contains fc
    mov r15, r8 ; now r15 contains fd

    ; r12d = slot % t->size
    xor rdx, rdx
    mov eax, esi
    div dword [rbx + offset_size]
    xor r12, r12
    mov r12d, edx

    ; rdi = *l = t->listArray[slot]
    mov rdi, qword [rbx + offset_listArray]
    mov rdi, qword [rdi + r12 * 8]

    ; listRemove(list_t* l, void* data, funcCmp_t* fc, funcDelete_t* fd)    
    mov rsi, r13
    mov rdx, r14
    mov rcx, r15
    call listRemove

    .end:
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx

        ret
    
nTableDeleteSlot:
    ; rdi = nTable_t* t
    ; esi = uint32_t slot
    ; rdx = funcDelete_t* fd

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi ; now rbx contains t
    mov r13, rdx ; now r13 contains fd

    ; r12d = slot % t->size
    xor rdx, rdx
    mov eax, esi
    div dword [rbx + offset_size]
    xor r12, r12
    mov r12d, edx

    ; r14 = t->listArray
    mov r14, qword [rbx + offset_listArray]

    ; rdi = *l = t->listArray[slot]
    mov rdi, qword [r14 + r12 * 8] 

    mov rsi, r13
    call listDelete ; (t->listArray[slot], fd)

    ; t->listArray[slot] = listNew()
    call listNew
    mov qword [r14 + r12 * 8], rax

    .end:
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx

        ret


nTableDelete:
    ; rdi = nTable_t* t
    ; rsi = funcDelete_t* fd

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi ; rbx = t
    mov r13, rsi ; r13 = fd

    xor r14, r14
    mov r14d, dword [rbx + offset_size] ; r14d  = t->size
    sub r14d, 1

    ; make sure size of t is not zero
    cmp r14d, 0
    je .end

    mov r15, qword [rbx + offset_listArray]

    ; r14d is going to be our counter i
    .deleteLists:
        mov rdi, qword [r15 + r14 * 8] ; rdi = t->listArray[i]
        mov rsi, r13
        call listDelete ; (l, fd)

        cmp r14d, 0
        je .end

        sub r14d, 1
        jmp .deleteLists

    .end:
        mov rdi, r15
        call free ; (t->listArray)

        mov rdi, rbx
        call free ; (t)
        
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx

        ret

