;------------------------------------------------------------------------------
; CD x64 - Compress-Decompress Utility using MS Compression API
; fearless 2023 - github.com/mrfearless
;------------------------------------------------------------------------------
; https://learn.microsoft.com/en-us/windows/win32/cmpapi/-compression-portal
; https://learn.microsoft.com/en-us/windows/win32/cmpapi/using-the-compression-api
; https://learn.microsoft.com/en-us/windows/win32/api/compressapi/nf-compressapi-compress
; https://learn.microsoft.com/en-us/windows/win32/api/compressapi/nf-compressapi-decompress
;------------------------------------------------------------------------------
;
; CD uses the Microsoft Compression API to compress or decompress data using 
; one of the four supported compression algorithms: XPRESS, XPRESS with Huffman
; encoding, MSZIP or LZMS.
;
; The files compressed by CD using those compression algorithms also store a 
; signature DWORD value as the header at the start of the file. This is so that 
; the appropriate compression algorithm can be used for the decompression.
;
; CD also makes use of the compression API to store bitmap resources as LZMS
; compressed data. There are two ways in which CD uses that compressed bitmap
; data: 
;
; 1) In the about box, by uncompressing the bitmap data before creating the 
;    bitmap in memory. The LZMS compressed bitmap data is stored as static hex 
;    bytes in the CD128x128x4.bmp.asm file.
;
; 2) Adding LZMS compressed bitmap files (.lzms) as resources which are 
;    compiled into CD.exe. These resources are loaded into memory, and then 
;    uncompressed before creating the bitmaps in memory.
;
;------------------------------------------------------------------------------
;
; XPRESS
; ------
; Microsoft Xpress Compression Algorithm (MS-XCA), more commonly known as 
; LZXpress, implements the LZ77 algorithm.
;
; XPRESS-HUFFMAN
; --------------
; The Huffman variant of the Microsoft Xpress Compression Algorithm (MS-XCA) 
; uses LZ77-style dictionary compression combined with Huffman coding. 
; Designed for fast compression and decompression with a small dictionary size.
;
; MSZIP
; -----
; MSZIP uses a combination of LZ77 and Huffman coding. It has only minor 
; variations from Phil Katz's 'deflate' method. MSZIP uses only the three basic 
; modes of deflate: stored, fixed Huffman tree, and dynamic Huffman tree.
;
; LZMS
; ----
; LZMS is an LZ77-based algorithm achieving a high compression ratio by relying 
; on a large LZ77 dictionary size and Huffman coding in addition to more 
; concise arithmetic coding.
;
;------------------------------------------------------------------------------

AboutDlgProc                    PROTO hWin:HWND, iMsg:UINT, wParam:WPARAM, lParam:LPARAM

; Reference to other functions in other files:
;EXTERN CDBitmapCreateFromMem:   PROTO pBitmapData:QWORD
;EXTERN CDDecompressMem:         PROTO pCompressedData:QWORD, qwCompressedDataLength:QWORD

.CONST

; About Dialog
IDD_AboutDlg                    EQU 17000
IDC_ABOUT_EXIT                  EQU 17001
IDC_ABOUT_BANNER                EQU 17002
IDC_WEBSITE_URL                 EQU 17003
IDC_TxtInfo                     EQU 17004
IDC_TxtVersion                  EQU 17005
IDC_EDT_INFO                    EQU 17006

.DATA
mrfearless_github               DB "https://github.com/mrfearless",0
szStringInMemoryError           DB "This is meant to show some text. Maybe something went wrong?",0
szShellOpen                     DB "open",0
pBMPInMemory                    DQ 0
hBMPInMemory                    DQ 0
pStringInMemory                 DQ 0

.DATA?
hWebsiteURL                     DQ ?
hAboutBanner                    DQ ?
hTxtInfo                        DQ ?
hTxtVersion                     DQ ?
hEdtInfo                        DQ ?

.CODE
;------------------------------------------------------------------------------
; About Dialog Procedure
;------------------------------------------------------------------------------
AboutDlgProc PROC FRAME hWin:HWND, iMsg:UINT, wParam:WPARAM, lParam:LPARAM
    ; SS_NOTIFY equ 00000100h in resource editor - in radasm resource editor directly edit dword value to get this added to static control
    
    mov eax,iMsg
    .IF eax == WM_INITDIALOG
        Invoke SendMessage, hWin, WM_SETICON, ICON_SMALL, hIcoMain
        .IF rax != NULL
            Invoke DeleteObject, rax
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Create our about banner bitmap from the static data stored in the
        ; CD128X128X4.bmp.asm file which is compressed LZMS bitmap data.
        ;----------------------------------------------------------------------
        Invoke CDBitmapCreateFromCompressedMem, Addr CD128X128X4, CD128X128X4Length
        .IF rax != NULL
            mov hBMPInMemory, rax
            Invoke SendDlgItemMessage, hWin, IDC_ABOUT_BANNER,  STM_SETIMAGE, IMAGE_BITMAP, hBMPInMemory
        .ENDIF
        
;        ;------------------------------------------------------------------------------
;        ; Alternative way of manually calling CDDecompressMem & CDBitmapCreateFromMem
;        ;------------------------------------------------------------------------------
;        Invoke CDDecompressMem, Addr CD128X128X4, CD128X128X4Length
;        .IF eax != NULL
;            mov pBMPInMemory, eax
;            Invoke CDBitmapCreateFromMem, pBMPInMemory
;            .IF eax != NULL
;                mov hBMPInMemory, eax
;                Invoke SendDlgItemMessage, hWin, IDC_ABOUT_BANNER,  STM_SETIMAGE, IMAGE_BITMAP, hBMPInMemory
;            .ENDIF
;        .ENDIF

        Invoke GetDlgItem, hWin, IDC_WEBSITE_URL
        mov hWebsiteURL, rax
        Invoke GetDlgItem, hWin, IDC_TxtInfo
        mov hTxtInfo, rax
        Invoke GetDlgItem, hWin, IDC_TxtVersion
        mov hTxtVersion, rax
        Invoke GetDlgItem, hWin, IDC_ABOUT_BANNER
        mov hAboutBanner, rax
        Invoke GetDlgItem, hWin, IDC_EDT_INFO
        mov hEdtInfo, rax
        
        ;----------------------------------------------------------------------
        ; Decompress a compressed string stored in Infotext.asm as szMSZPText
        ; Original string size is 2297 Bytes, compressed it is 1035 Bytes long
        ;----------------------------------------------------------------------
        Invoke CDDecompressMem, Addr szMSZPText, szMSZPTextLength
        .IF eax != NULL
            mov pStringInMemory, rax
            Invoke SetWindowText, hEdtInfo, pStringInMemory
        .ELSE
            Invoke SetWindowText, hEdtInfo, Addr szStringInMemoryError
        .ENDIF
        
        
        ;----------------------------------------------------------------------
        ; Change class for these controls to show a hand when mouse over.
        ; These controls also have SS_NOTIFY equ 00000100h set so they will
        ; respond to a mouse click and send a WM_COMMAND message which allows
        ; us to fake a hyperlink to open browser at desired website
        ;----------------------------------------------------------------------
        Invoke LoadCursor, 0, IDC_HAND
        Invoke SetClassLongPtr, hWebsiteURL, GCL_HCURSOR, eax
        Invoke LoadCursor, 0, IDC_HAND
        Invoke SetClassLongPtr, hAboutBanner, GCL_HCURSOR, eax
        
    .ELSEIF eax == WM_CTLCOLORDLG
        invoke SetBkMode, wParam, WHITE_BRUSH
        invoke GetStockObject, WHITE_BRUSH
        ret
        
    .ELSEIF eax == WM_CTLCOLORSTATIC ; set to transparent background for listed controls
        mov rax, lParam
        .IF rax == hWebsiteURL || rax == hTxtInfo || rax == hTxtVersion
            Invoke SetTextColor, wParam, 0h ;0FFFFFFh
            Invoke SetBkMode, wParam, TRANSPARENT
            Invoke GetStockObject, NULL_BRUSH
            ret
       .ENDIF
        
    .ELSEIF eax == WM_CLOSE
        .IF pStringInMemory != 0
            Invoke GlobalFree, pStringInMemory
        .ENDIF
        .IF pBMPInMemory != 0
            Invoke GlobalFree, pBMPInMemory
        .ENDIF
        .IF hBMPInMemory != 0
            Invoke DeleteObject, hBMPInMemory
        .ENDIF
        mov pStringInMemory, 0
        mov pBMPInMemory, 0
        mov hBMPInMemory, 0
        Invoke EndDialog, hWin, NULL
        
    .ELSEIF eax == WM_COMMAND
        mov rax, wParam
        and rax, 0FFFFh
        .IF eax == IDC_ABOUT_EXIT
            Invoke SendMessage, hWin, WM_CLOSE, NULL, NULL
        .ENDIF
        mov rax, lParam
        .IF rax == hWebsiteURL || rax == hAboutBanner
            Invoke ShellExecute, hWin, Addr szShellOpen, Addr mrfearless_github, NULL, NULL, SW_SHOW
        .ENDIF
    .ELSE
        mov rax, FALSE
        ret
    .ENDIF
    
    mov rax,TRUE
    ret
AboutDlgProc ENDP

