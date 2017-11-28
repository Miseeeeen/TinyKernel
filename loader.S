%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR


jmp loader_start

; build gdt and its des
GDT_BASE: 
dd 0x00000000
dd 0x00000000

CODE_DESC:
dd 0x0000FFFF
dd DESC_CODE_HIGH4

DATA_STACK_DESC:
dd 0x0000FFFF
dd DESC_DATA_HIGH4

VIDEO_DESC:
dd 0x80000007
dd DESC_VIDEO_HIGH4

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1

times 120 dd 0

SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

gdt_ptr dw GDT_LIMIT
        dd GDT_BASE
loadermsg db '2 loader in real.'

loader_start:

;---------------------
; print string
;---------------------

    ;-------insert
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 184fh

    int 10h

    ;-------end

    mov sp, LOADER_BASE_ADDR
    mov bp, loadermsg
    mov cx, 17
    mov ax, 0x1301
    mov bx, 0x001f
    mov dx, 0x1800
    int 0x10

;--------- goto the protection mode
    ; open a20
    in al, 0x92
    or al, 00000010B
    out 0x92, al

    ; load gdt
    lgdt [gdt_ptr]

    ; cr0 on
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    jmp dword SELECTOR_CODE:p_mode_start

[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:0x160], 'P'

    jmp $

;----------- page table
    call setup_page

    sgdt [gdt_ptr]
    mov ebx, [gdt_ptr+2]
    or dword [ebx+0x18+4], 0xc0000000

    add dword [gdt_ptr+2], 0xc0000000
    add esp, 0xc0000000

    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax

    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    lgdt [gdt_ptr]

    mov byte [gs:0x02], 'V'
    mov eax, 0x1234
    jmp $

setup_page:
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir

; PDE
.create_pde:
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000
    mov ebx, eax

    or eax, PG_US_U | PG_RW_W | PG_P
    mov [PAGE_DIR_TABLE_POS + 0x0], eax
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax

    sub eax, 0x1000
    mov [PAGE_DIR_TABLE_POS + 4092], eax

; PTE
    mov ecx, 256
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte:
    mov [ebx+esi*4], edx
    add edx, 4096
    inc esi
    loop .create_pte

    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000
    or eax, PG_US_U | PG_RW_W | PG_P
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254
    mov esi, 769
.create_kernel_pde:
    mov [ebx+esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret
    

