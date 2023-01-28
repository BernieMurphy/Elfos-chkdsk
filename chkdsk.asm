; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *** 2023-01-22 B. Murphy Updated to support multiple drives     ***
; *** 2023-01-22 Also credits to D. Madole for section of code    ***
; *** 2023-01-25 Updated to support up to 32 disks                ***
; *******************************************************************

;********************************************************************
;*** This program scan an Elf-OS real or vitual disks and reports ***
;*** on what disks are present. Elf-OS build 226 or higher should ***
;*** be used. Lower versions may cause this program to hang       ***
;********************************************************************  

#include    bios.inc
#include    kernel.inc
#include    ops.inc

d_idewrite:equ    044ah
d_ideread: equ    0447h
maxdisks:  equ     32                  ; Maximum number of disks
diskmask:  equ     0e0h                ; Drive numbers 0e0h-0FFh 01 forideread
 
           org     2000h-6 
           dw      2000h               ; header, where program loads
           dw      endrom-2000h        ; length of program to load
           dw      2000h               ; exec address
           org     2000h


begin:     br      mainlp
           eever
           db      'Updated: B. Murphy Credits: Michael H. Riley, David Madole',0

;********************************************************************
;*** Loop through all the possible disks & scan if we find one   ****
;******************************************************************** 
mainlp:    equ     $
           bn4     noinef4             ; check if input/ef4 asserted
           rtn
                   
noinef4:   call    main
           mov     rf,disknum          ; get disk number address
           ldn     rf
           ani     01fh                ; get number back to 0-31
           adi     1                   ; get next disk number
           str     rf                  ; and store it 
           smi     maxdisks            ; have we done all the disks?
           lbnz    mainlp              ; if not, go again
           ldi     0
           rtn                         ; return to os


main:      mov     rf,buffer           ; for ideread
           mov     r7,disknum          ; get disk number 0-31
           ldn     r7
           adi     diskmask            ; convert for ideread               
           phi     r8
           ldi     0                   ; need to read sector 0
           plo     r8
           phi     r7
           plo     r7
           call    d_ideread           ; call bios to read sector  
           lbnf     readok1            ; read OK?
           rtn

readok1:   equ     $
           call    docrlf              ; add some space
           call    f_inmsg             ; output first part of message
           db      'Disk ',0
           mov     rf,disknum          ; save  
           ldn     rf
           ani     01fh                ; turn number back to 0-31  
           plo     rd
           ldi     0
           phi     rd
           mov     rf,cbuffer  
           call    f_uintout           ; output disk number
           ldi     0 
           str     rf                  ; store a terminator
           mov     rf,cbuffer
           call    o_msg               ; output disk number message
           call    docrlf
           mov     rf,disknum          ; get current disk number 0-31
           ldn     rf
           adi     diskmask            ; convert for rest of f_idereads
           str     rf   

           ldi    (buffer+104h).1       ; get pointer to filesystem type
           phi   rf
           ldi   (buffer+104h).0
           plo   rf
           ldn   rf                    ; compare to 1, proceed if so
           xri   1
           lbz   type1fs
           call  o_inmsg                ; else fail with error message
           db    'Not a type 1 filesystem.',13,10,0
           ret                          ; and return
         

type1fs:    equ   $                     ; a good file system type
            call   o_inmsg
            db    "Type 1 filesystem",13,10,0

; *********************************************************************
; *** Compute a 16 bit checksum of first 256 bytes of sector 0      ***
;**********************************************************************
           ldi   0
           phi   rd                     ; clear the check sum
           plo   rd
           phi   rf
           sex   r7
           mov   r7,buffer              ; get address of sector buffer
           ldi   1                      ; loop counter is 256
           phi   rf
sumloop:   glo   rd
           add                          ; perform add
           plo   rd                     ; and save lsb byte
           ghi   rd                     ; get msb byte
           adci  0                      ; do add with carry
           phi   rd                     ; and save result
           inc   r7                     ; increment buffer address
           dec   rf                     ; lower loop count 
           ghi   rf                     ; have we reached 256 count?                             
           lbnz   sumloop     
           call   o_inmsg
           db    'Sector 0 bootloader checksum: ',0    
           mov   rf,cbuffer              
           call    f_hexout4            ; checksum in rd for hexout4 
           ldi   0
           str   rf                     ; store terminator  in buffer
           dec   rf
           dec   rf
           dec   rf
           dec   rf
           call  o_msg                   ; output the 4 char hex checksum
           call  docrlf                  ; and finish the line

 
; get the size of the source disk so we know how many allocation
; units there are
            ldi   (buffer+10bh).1       ; pointer to number of aus
            phi   rf
            ldi   (buffer+10bh).0
            plo   rf

            lda   rf                    ; get numger of aus
            phi   rb
            lda   rf
            plo   rb

            ldi   0                     ; divide by 256 to get megabytes
            phi   rd
            ghi   rb
            plo   rd

            ldi   cbuffer.1              ; buffer for result
            phi   rf
            ldi   cbuffer.0
            plo   rf

            sep   scall                 ; convert to decimal
            dw    f_intout

            ldi   0                     ; zero terminate string
            str   rf

            sep   scall                 ; start output info
            dw    o_inmsg
            db    "Source disk is ",0

            ldi   cbuffer.1              ; pointer to previous conversion
            phi   rf
            ldi   cbuffer.0
            plo   rf

            sep   scall                 ; output disk size
            dw    o_msg

            sep   scall
            dw    o_inmsg               ; tell about size and now scan
            db    ' MB. Now scanning AUs ...',13,10,0

;************************************************************************
; *** Scan the AU allocation table in the source disk, counting how   ***
; *** many are actually in use, and building a bitmap in RAM of those ***
; *** we need to copy. A bitmap of all AUs would have 256 MB divided  ***
; *** by 4 KB is 64K entries... at 8 bits per byte, this is 8KB of    ***
; *** memory, which is resonable on any Elf/OS system.                ***
;*************************************************************************
            ldi   0                     ; clear current au and used count
            plo   r9
            phi   r9
            plo   ra
            phi   ra
            mov  rc,bitmap

scnloop:    glo   ra                    ; load a sector every 256 aus
            lbnz  gotsect

            ghi   ra                    ; au table starts at sector 17
            adi   17                    ;  and each sector is 256 entries,
            plo   r7                    ;  so add 17 to the msb of au to
            ldi   0                     ;  get sector number
            plo   r8
            adci  0
            phi   r7
   
            mov  rf,disknum            ; get disk we are checking number
            ldn   rf  
            phi   r8

            ldi   buffer.1              ; buffer to sector buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; get one sector of au map
            dw    d_ideread
            lbdf  failed

            ldi   buffer.1              ; reset buffer to start
            phi   rf
            ldi   buffer.0
            plo   rf

          ; Loop through each 16-bit au entry in the sector and count and
          ; mark in bitmap those that are in use.

gotsect:    lda   rf                    ; if msb is not zero, it's in use
            lbnz  inuse

            adi   0                     ; clear df flag in case not used

            ldn   rf                    ; if msb and lsb zero, not in use
            lbz   notuse

inuse:      smi   0                     ; set df flag since in use

            inc   r9                    ; increment used au count

notuse:     ldn   rc                    ; shift bit into bitmap byte
            shrc
            str   rc

            inc   ra                    ; advance to next au

            glo   ra                    ; every 8 aus we have filled a byte
            ani   7
            lbnz  notbyte

            inc   rc                    ; advance to next bitmap byte

notbyte:    inc   rf                    ; move to next au entry

            dec   rb                    ; loop if not all aus checked
            glo   rb
            lbnz  scnloop
            ghi   rb
            lbnz  scnloop


          ; Output a message with amount of data in use that we will copy.

            ghi   r9                    ; divide used aus by 256
            plo   rd
            ldi   0
            phi   rd
            inc   rd

            ldi   cbuffer.1              ; buffer to convert into
            phi   rf
            ldi   cbuffer.0
            plo   rf

            sep   scall                 ; convert size in megabytes
            dw    f_intout

            ldi   0                     ; zero terminate
            str   rf

            ldi   cbuffer.1              ; back to start of buffer
            phi   rf
            ldi   cbuffer.0
            plo   rf

            sep   scall                 ; output data size
            dw    o_msg

            sep   scall                 ;amount in use
            dw    o_inmsg
            db    " MB is in use.",13,10,0
         

           mov     rf,buffer           ; for ideread
           mov     r7,disknum          ; get disk number
           ldn     r7               
           phi     r8
           ldi     0                   ; need to read sector 0
           plo     r8
           phi     r7
           plo     r7
           call    d_ideread           ; call bios to read sector  
           lbnf     readok2             ; read OK?
           call    f_inmsg             ; disk not responding
           db      'Read error. Exiting',13,10,0
           rtn

readok2:   mov     rf,numaus           ; get number of aus message
           call    o_msg               ; and display it
           ldi     low buffer          ; point to read total aus
           adi     11
           plo     r9
           ldi     high buffer
           adci    1
           phi     r9
           lda     r9                  ; get total aus
           phi     rd
           lda     r9
           plo     rd
           mov     rf,cbuffer                               
           call    f_uintout           ; convert number to ascii
           ldi     0                   ; place a terminator
           str     rf
           mov     rf,cbuffer
           call    o_msg               ; display number
           call    docrlf
           mov     rf,freeaus          ; get message
           call    o_msg
           ldi     low buffer          ; point to directory sector
           adi     5
           plo     r9
           ldi     high buffer
           adci    1
           phi     r9
           lda     r9                  ; get directory sector
           phi     ra
           lda     r9
           plo     ra
           ldi     0                   ; setup count
           phi     rd
           plo     rd

           mov     r7,disknum          ; get disk number
           ldn     r7                  ; and set up directory
           
           phi     r8
           ldi     0
           plo     r7
           phi     r7
           ldi     17
           plo     r7
secloop:   mov     rf,buffer
           call    d_ideread           ; read the sector
           mov     rf,buffer
           ldi     1                   ; 256 entries to check
           phi     rb
           ldi     0
           plo     rb
entloop:   lda     rf                  ; get byte from table
           lbnz     used                ; jump if it is used
           ldn     rf                  ; next byte
           lbnz     used
           inc     rd
used:      dec     rb                  ; decrement entry count
           inc     rf                  ; move to next entry
           glo     rb                  ; check if done with sector
           lbnz     entloop             ; jump if more to go
           ghi     rb                  ; check high byte as well
           lbnz     entloop
           inc     r7                  ; increment sector
           glo     ra                  ; compare to dir sector
           str     r2
           glo     r7
           sm
           lbnz     secloop            ; jump if more sectors to count
           ghi     ra
           str     r2
           ghi     r7
           sm
           lbnz    secloop
           mov     rf,cbuffer         
           call    f_uintout           ; convert number to ascii
           ldi     0                   ; place a terminator
           str     rf
           mov     rf,cbuffer
           call    o_msg
           call    docrlf
           rtn                         ; return to caller

;  If a disk error occurs along the way, output an error message
;  indicating where and abort the mission.

failed:     sep   scall                 ; output error message
            dw    o_inmsg
            db    "error on drive ",0

            ghi   r8                    ; drive number as digit
            ani   15
            adi   '0'

            sep   scall                 ; output drive number
            dw    o_type

            sep   scall                 ; preface for sector
            dw    o_inmsg
            db    " at sector ",0

            ldi   cbuffer.1              ; pointer to buffer for sector
            phi   rf
            ldi   cbuffer.0
            plo   rf

            glo   r8                    ; get bits 16-23 of sector
            plo   rd

            sep   scall                 ; convert two hex digits
            dw    f_hexout2

            glo   r7                    ; get bits 0-15 of sector
            plo   rd
            ghi   r7
            phi   rd

            sep   scall                 ; convert four hex digits
            dw    f_hexout4

            ldi   0                     ; zero terminate
            str   rf

            ldi   cbuffer.1              ; back to beginning of buffer
            phi   rf
            ldi   cbuffer.0
            plo   rf

skpzero:    lda   rf                    ; skip over leading zeroes
            smi   '0'
            lbz   skpzero

            adi   '0'                   ; but leave the last zero
            lbnz  notlast
            dec   rf

notlast:    dec   rf                    ; undo last auto-increment

            sep   scall                 ; output sector number
            dw    o_msg

            sep   scall                 ; rest of failure message
            dw    o_inmsg

            db    " Scan of AUs failed",13,10,0
            sep   sret                  ; return




docrlf:    call    f_inmsg
           db      10,13,0             ; cr, lf, null
           rtn                         ; return to caller

numaus:    db      'Total AUs: ',0
freeaus:   db      'Free  AUs: ',0
disknum:   db      0                   ; disk number 

endrom:    equ     $

.suppress
buffer:    ds      512
bitmap:    ds      8192
    
cbuffer:   ds      40

           end     begin
