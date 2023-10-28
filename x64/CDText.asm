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

CDTextDlgProc                   PROTO hWin:HWND, iMsg:UINT, wParam:WPARAM, lParam:LPARAM
CDTextInitGUI                   PROTO hWin:QWORD
CDTextInitTipsForEachChild      PROTO hChild:QWORD, lParam:QWORD
CDTextBrowseForFile             PROTO hWin:QWORD, bLoad:QWORD

CDTextPasteText                 PROTO hWin:QWORD
CDTextCopyText                  PROTO hWin:QWORD
CDTextLoadText                  PROTO hWin:QWORD
CDTextSaveText                  PROTO hWin:QWORD

CDTextCompressText              PROTO hWin:QWORD
CDTextAsmOutput                 PROTO hWin:QWORD, lpData:QWORD, qwDataLength:QWORD, qwOriginalLength:QWORD, qwAlgorithm:QWORD


; Reference to other functions in other files:
;EXTERN CDCompressMem:           PROTO lpUncompressedData:QWORD, qwUncompressedDataLength:QWORD, qwCompressionAlgorithm:QWORD, lpqwCompressedDataLength:QWORD
;EXTERN CDDecompressMem:         PROTO pCompressedData:QWORD, qwCompressedDataLength:QWORD

.CONST
CDTEXT_MAX_INPUTTEXT            EQU 262144  ; 256K
CDTEXT_MAX_OUTPUTTEXT           EQU 2097152 ; 2048K

BMP_CLEARTEXT_WIDE              EQU 141 ; Images/ClearTextWide.bmp
BMP_LOADFILE_WIDE               EQU 142 ; Images/LoadFileWide.bmp"
BMP_SAVEFILE_WIDE               EQU 143 ; Images/SaveFileWide.bmp"
BMP_COPYDATA_WIDE               EQU 144 ; Images/CopyDataWide.bmp"
BMP_PASTETEXT_WIDE              EQU 145 ; Images/PasteTextWide.bmp
BMP_CLOSE_WIDE                  EQU 146 ; Images/Close.bmp
LZMS_CLEARTEXT_WIDE             EQU 151 ; Images/ClearTextWide.bmp.lzms
LZMS_LOADFILE_WIDE              EQU 152 ; Images/LoadFileWide.bmp.lzms
LZMS_SAVEFILE_WIDE              EQU 153 ; Images/SaveFileWide.bmp.lzms
LZMS_COPYDATA_WIDE              EQU 154 ; Images/CopyDataWide.bmp.lzms
LZMS_PASTETEXT_WIDE             EQU 155 ; Images/PasteTextWide.bmp.lzms
LZMS_CLOSE_WIDE                 EQU 156 ; Images/Close.bmp.lzms

;CDText.dlg
IDD_TEXTDLG                     equ 2000

IDC_STC_COMPRESS_ALGO           equ 2005
IDC_SHP4                        equ 2006
IDC_RBN_TXT_XPRESS              equ 2007
IDC_RBN_TXT_HUFF                equ 2008
IDC_RBN_TXT_MSZIP               equ 2009
IDC_RBN_TXT_LZMS                equ 2010
IDC_RBN_TXT_NONE                equ 2011

IDC_STC_TEXT_PROMPT             equ 2012
IDC_EDT_TEXT_INPUT              equ 2013
IDC_BTN_PASTE_TEXT              equ 2014
IDC_BTN_LOAD_TEXT               equ 2015
IDC_BTN_CLEAR_TEXT              equ 2016

IDC_STC_PROMPT_OUTPUT           equ 2017
IDC_EDT_DATA_OUTPUT             equ 2018
IDC_BTN_COPY_OUTPUT             equ 2019
IDC_BTN_SAVE_OUTPUT             equ 2020
IDC_BTN_CLOSE                   equ 2021


.DATA

CDOpenTextFileFilter            DB "Text Files (*.txt,*.asm,*.inc)",0,"*.txt;*.asm;*.inc",0
                                DB "All Files (*.*)",0,"*.*",0
                                DB 0

CDTextAlgorithm                 DQ COMPRESS_ALGORITHM_XPRESS
CDTextFileName                  DB MAX_PATH DUP (0)

hFontEdt                        DQ 0
hCDTextToolTip                  DQ 0
hCDTextEditInput                DQ 0
hCDTextEditOutput               DQ 0

pEdtInputBuffer                 DQ 0 ; max 256K
pEdtOutputBuffer                DQ 0 ; max 2048K

.CODE
;------------------------------------------------------------------------------
; CD Compress Text Strings Dialog Procedure
;------------------------------------------------------------------------------
CDTextDlgProc PROC FRAME hWin:HWND, iMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL wNotifyCode:QWORD
    
    mov eax, iMsg
    .IF eax == WM_INITDIALOG
        Invoke CDTextInitGUI, hWin

    ;--------------------------------------------------------------------------
    ; Free Up Memory And Close Dialog
    ;--------------------------------------------------------------------------
    .ELSEIF eax == WM_CLOSE
        .IF pEdtInputBuffer != 0
            Invoke GlobalFree, pEdtInputBuffer
            mov pEdtInputBuffer, 0
        .ENDIF
        .IF pEdtOutputBuffer != 0
            Invoke GlobalFree, pEdtOutputBuffer
            mov pEdtOutputBuffer, 0
        .ENDIF
        Invoke EndDialog, hWin, NULL
        
    ;--------------------------------------------------------------------------
    ; Process Buttons, Radio Buttons and Edit Control EN_CHANGE Notification
    ;--------------------------------------------------------------------------
    .ELSEIF eax == WM_COMMAND
        mov rax, wParam
        shr rax, 16
        mov wNotifyCode, rax
        mov rax, wParam
        and rax, 0FFFFh
        
        ;----------------------------------------------------------------------
        ; Close Button
        ;----------------------------------------------------------------------
        .IF eax == IDC_BTN_CLOSE
            Invoke SendMessage, hWin, WM_CLOSE, NULL, NULL
            
        ;----------------------------------------------------------------------
        ; Paste Button
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_PASTE_TEXT || eax == ACC_BTN_PASTE
            Invoke SetFocus, hCDTextEditInput
            Invoke CDTextPasteText, hWin
            Invoke CDTextCompressText, hWin

        ;----------------------------------------------------------------------
        ; Load Button
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_LOAD_TEXT || eax == ACC_BTN_LOAD
            Invoke CDTextBrowseForFile, hWin, TRUE
            .IF eax == TRUE
                Invoke CDTextLoadText, Addr CDTextFileName
                .IF eax == TRUE
                    Invoke SetFocus, hCDTextEditInput
                    Invoke CDTextCompressText, hWin
                .ENDIF
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Clear Button
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_CLEAR_TEXT
            Invoke SetWindowText, hCDTextEditInput, 0
            Invoke SetWindowText, hCDTextEditOutput, 0
            Invoke SetFocus, hCDTextEditInput
            
        ;----------------------------------------------------------------------
        ; Copy Button
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_COPY_OUTPUT || eax == ACC_BTN_COPY
            Invoke CDTextCopyText, hWin
            Invoke SetFocus, hCDTextEditOutput
            
        ;----------------------------------------------------------------------
        ; Save Button
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_SAVE_OUTPUT || eax == ACC_BTN_SAVE
            Invoke CDTextBrowseForFile, hWin, FALSE
            .IF rax == TRUE
                Invoke CDTextSaveText, Addr CDTextFileName
            .ENDIF
            Invoke SetFocus, hCDTextEditOutput
        
        ;----------------------------------------------------------------------
        ; Input Edit Control Change Event
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_EDT_TEXT_INPUT
            mov rax, wNotifyCode
            .IF rax == EN_CHANGE
                IFDEF DEBUG64
                PrintText 'IDC_EDT_TEXT_INPUT EN_CHANGE'
                ENDIF
                Invoke CDTextCompressText, hWin
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Radio Button Selections For Compression Algorithm
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_RBN_TXT_XPRESS
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDTextAlgorithm, COMPRESS_ALGORITHM_XPRESS
            Invoke CDTextCompressText, hWin
        
        .ELSEIF eax == IDC_RBN_TXT_HUFF
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDTextAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
            Invoke CDTextCompressText, hWin
            
        .ELSEIF eax == IDC_RBN_TXT_MSZIP
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDTextAlgorithm, COMPRESS_ALGORITHM_MSZIP
            Invoke CDTextCompressText, hWin
            
        .ELSEIF eax == IDC_RBN_TXT_LZMS
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDTextAlgorithm, COMPRESS_ALGORITHM_LZMS
            Invoke CDTextCompressText, hWin
        
        .ELSEIF eax == IDC_RBN_TXT_NONE
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_CHECKED, 0
            mov CDTextAlgorithm, 0
            Invoke CDTextCompressText, hWin

        .ENDIF
        
    .ELSE
        mov eax,FALSE
        ret
    .ENDIF
    
    mov eax,TRUE
    ret
CDTextDlgProc ENDP

;------------------------------------------------------------------------------
; CDTextInitGUI - Initialize GUI: Bitmaps, Toolbar, Tooltips, Menu etc 
;
; Returns: nothing
;------------------------------------------------------------------------------
CDTextInitGUI PROC FRAME USES RBX hWin:QWORD
    LOCAL hMainMenu:QWORD
    LOCAL hBitmap:QWORD
    LOCAL hFont:QWORD
    LOCAL lfnt:LOGFONT

    Invoke GetDlgItem, hWin, IDC_EDT_TEXT_INPUT
    mov hCDTextEditInput, rax
    Invoke GetDlgItem, hWin, IDC_EDT_DATA_OUTPUT
    mov hCDTextEditOutput, rax
    
    ;--------------------------------------------------------------------------
    ; Alloc memory for buffers
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, CDTEXT_MAX_INPUTTEXT
    mov pEdtInputBuffer, rax
    
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, CDTEXT_MAX_OUTPUTTEXT
    mov pEdtOutputBuffer, rax
    
    Invoke RtlZeroMemory, Addr CDTextFileName, SIZEOF CDTextFileName
    
    ;--------------------------------------------------------------------------
    ; Set main window icons 
    ;--------------------------------------------------------------------------
    Invoke SendMessage, hWin, WM_SETICON, ICON_BIG, hIcoMain
    Invoke SendMessage, hWin, WM_SETICON, ICON_SMALL, hIcoMain
    
    ;--------------------------------------------------------------------------
    ; Set default radio selection for compression algorithm
    ; This allows reentry to dialog to keep last selection made
    ;--------------------------------------------------------------------------
    mov rax, CDTextAlgorithm
    .IF rax == COMPRESS_ALGORITHM_MSZIP
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSEIF rax == COMPRESS_ALGORITHM_LZMS
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSE
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_CHECKED, 0
    .ENDIF  
    
    ;--------------------------------------------------------------------------
    ; Create tooltip control and enum child controls to set text for each
    ;--------------------------------------------------------------------------
    Invoke CreateWindowEx, NULL, CTEXT("Tooltips_class32"), NULL, TTS_ALWAYSTIP, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hWin, NULL, hInstance, NULL
    mov hCDTextToolTip, rax
    Invoke SendMessage, hCDTextToolTip, TTM_SETMAXTIPWIDTH, 0, 350
    invoke SendMessage, hCDTextToolTip, TTM_SETDELAYTIME, TTDT_AUTOPOP, 12000
    Invoke EnumChildWindows, hWin, Addr InitTipsForEachChild, hWin
    
    ;--------------------------------------------------------------------------
    ; Button Bitmaps
    ;--------------------------------------------------------------------------
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_CLEARTEXT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_CLEARTEXT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_CLEAR_TEXT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_LOADFILE_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_LOADFILE_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_LOAD_TEXT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_SAVEFILE_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_SAVEFILE_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_SAVE_OUTPUT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_COPYDATA_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_COPYDATA_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_COPY_OUTPUT, BM_SETIMAGE, IMAGE_BITMAP, rax

    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_PASTETEXT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_PASTETEXT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_PASTE_TEXT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_CLOSE_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_CLOSE_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_CLOSE, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    ;--------------------------------------------------------------------------
    ; Set font for input and output edit controls
    ;--------------------------------------------------------------------------
    Invoke SendMessage, hWin, WM_GETFONT, 0, 0
    mov hFont, rax
    Invoke GetObject, hFont, SIZEOF lfnt, Addr lfnt
    mov eax, lfnt.lfHeight
    add eax, 2
    mov lfnt.lfHeight, eax
    lea rbx, lfnt.lfFaceName
    Invoke lstrcpy, rbx, CTEXT("Courier New")
    Invoke CreateFontIndirect, Addr lfnt
    mov hFontEdt, rax
    
    Invoke SendMessage, hCDTextEditInput, WM_SETFONT, hFontEdt, TRUE
    Invoke SendMessage, hCDTextEditOutput, WM_SETFONT, hFontEdt, TRUE
    Invoke SendMessage, hCDTextEditOutput, EM_SETLIMITTEXT, CDTEXT_MAX_INPUTTEXT, 0     ; Limit to 256K
    Invoke SendMessage, hCDTextEditOutput, EM_SETLIMITTEXT, CDTEXT_MAX_OUTPUTTEXT, 0    ; Limit to 2048K
    
    xor rax, rax
    ret
CDTextInitGUI ENDP

;------------------------------------------------------------------------------
; CDTextInitTipsForEachChild - initialize tooltips for each control
; 
; Returns: TRUE
;------------------------------------------------------------------------------
CDTextInitTipsForEachChild PROC FRAME USES RBX hChild:QWORD, lParam:QWORD
    LOCAL TooltipText[256]:BYTE
    LOCAL TooltipTextID:QWORD
    LOCAL tti:TTTOOLINFOA

    mov tti.cbSize, SIZEOF TTTOOLINFOA
    mov tti.uFlags, TTF_IDISHWND or TTF_SUBCLASS
    
    Invoke GetParent, hChild
    mov tti.hwnd, rax

    mov rax, hChild
    mov tti.uId, rax

    mov rax, hInstance
    mov tti.hinst, rax
    
    Invoke GetDlgCtrlID, hChild
    mov TooltipTextID, rax

    Invoke LoadString, hInstance, dword ptr TooltipTextID, Addr TooltipText, 256
    .IF rax == 0
        ; ignore controls we didnt set a tooltip text for in the stringtable
    .ELSE
        lea rax, TooltipText
        mov tti.lpszText, rax
        Invoke SendMessage, hCDTextToolTip, TTM_ADDTOOL, NULL, Addr tti
        Invoke SendMessage, hCDTextToolTip, TTM_ACTIVATE, TRUE, 0
    .ENDIF

    mov rax, TRUE
    ret
CDTextInitTipsForEachChild ENDP

;------------------------------------------------------------------------------
; CDTextBrowseForFile - Browse for a file to open. Stores the selected file in 
; CDTextFileName
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextBrowseForFile PROC FRAME hWin:QWORD, bLoad:QWORD
    LOCAL BrowseForFile:OPENFILENAME

    IFDEF DEBUG64
    PrintText 'CDBrowseForFile'
    ENDIF
    
    Invoke RtlZeroMemory, Addr CDTextFileName, SIZEOF CDTextFileName
    Invoke RtlZeroMemory, Addr BrowseForFile, SIZEOF OPENFILENAME
    
    mov BrowseForFile.lStructSize, SIZEOF OPENFILENAME
    mov rax, hWin
    mov BrowseForFile.hwndOwner, rax
    mov BrowseForFile.nMaxFile, MAX_PATH
    mov BrowseForFile.lpstrDefExt, 0
    lea rax, CDOpenTextFileFilter
    mov BrowseForFile.lpstrFilter, rax
    mov BrowseForFile.Flags, OFN_EXPLORER or OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
    lea rax, CDTextFileName
    mov BrowseForFile.lpstrFile, rax
    .IF bLoad == TRUE
        Invoke GetOpenFileName, Addr BrowseForFile
    .ELSE
        Invoke GetSaveFileName, Addr BrowseForFile
    .ENDIF
    ; If user selected a file and didnt cancel browse operation...
    .IF rax != 0
        mov rax, TRUE
    .ELSE
        mov rax, FALSE
    .ENDIF
    ret

CDTextBrowseForFile ENDP

;------------------------------------------------------------------------------
; CDTextPasteText - paste text from clipboard
;
; Returns: nothing
;------------------------------------------------------------------------------
CDTextPasteText PROC FRAME hWin:QWORD
    LOCAL hClipData:QWORD
    LOCAL lpszClipText:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDTextPasteText'
    ENDIF
    
    Invoke OpenClipboard, hWin
    .IF rax == TRUE
        Invoke IsClipboardFormatAvailable, CF_TEXT
        .IF rax == TRUE
            Invoke GetClipboardData, CF_TEXT
            .IF rax != NULL
                mov hClipData, rax
                Invoke GlobalLock, hClipData
                .IF rax != NULL
                    mov lpszClipText, rax
                    Invoke SetWindowText, hCDTextEditInput, lpszClipText
                    Invoke GlobalUnlock, hClipData
                    Invoke SendMessage, hCDTextEditInput, EM_SETSEL, -1, 0
                .ENDIF
            .ENDIF    
        .ENDIF
        Invoke CloseClipboard
    .ENDIF
    
    xor rax, rax
    ret
CDTextPasteText ENDP

;------------------------------------------------------------------------------
; CDTextCopyText - Copy output data byte text to clipboard
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextCopyText PROC FRAME hWin:QWORD
    LOCAL hClipData:QWORD
    LOCAL pClipData:QWORD
    LOCAL lenClipText:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDTextCopyText'
    ENDIF
    
    Invoke GetWindowText, hCDTextEditOutput, pEdtOutputBuffer, CDTEXT_MAX_OUTPUTTEXT
    .IF rax == 0
        mov rax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, pEdtOutputBuffer
    mov lenClipText, rax
    add rax, 4
    
    Invoke GlobalAlloc, GMEM_MOVEABLE, rax
    .IF rax == NULL
        mov rax, FALSE
        ret
    .ENDIF
    mov hClipData, rax
    
    Invoke GlobalLock, hClipData
    .IF rax == NULL
        mov rax, FALSE
        ret
    .ENDIF
    mov pClipData, rax
    
    Invoke lstrcpyn, pClipData, pEdtOutputBuffer, dword ptr lenClipText
    Invoke GlobalUnlock, hClipData
    
    Invoke OpenClipboard, hWin
    .IF rax == TRUE
        Invoke EmptyClipboard
        Invoke SetClipboardData, CF_TEXT, hClipData
        Invoke CloseClipboard
    .ENDIF
    Invoke MessageBeep, MB_OK ; beep hopefully tells user that copy to clipboard was done
    
    mov rax, TRUE
    ret
CDTextCopyText ENDP

;------------------------------------------------------------------------------
; CDTextLoadText - Load text from a file into the input edit control
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextLoadText PROC FRAME lpszFilename:QWORD
    LOCAL hFile:QWORD
    LOCAL MemMapHandle:QWORD
    LOCAL MemMapPtr:QWORD
    LOCAL qwFileSize:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDOpenFile'
    ENDIF

    ;--------------------------------------------------------------------------
    ; Some basic checks
    ;--------------------------------------------------------------------------
    .IF lpszFilename == NULL
        mov rax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, lpszFilename
    .IF rax == 0 || rax > MAX_PATH
        mov rax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Open file for read only or read/write access
    ;--------------------------------------------------------------------------
    Invoke CreateFile, lpszFilename, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL
    .IF rax == INVALID_HANDLE_VALUE
        mov rax, FALSE
        ret
    .ENDIF
    mov hFile, rax ; store file handle

    ;--------------------------------------------------------------------------
    ; Get file size and verify its not too low or too high in size
    ;--------------------------------------------------------------------------
    Invoke GetFileSize, hFile, NULL
    .IF rax > 0FFFFFFFh ; 0FFFFFFFh = 256MB (268,435,455bytes) - 1FFFFFFFh = 536MB (536,870,911bytes)
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
     .ENDIF
    mov qwFileSize, rax ; file size

    ;--------------------------------------------------------------------------
    ; Create file mapping of entire file
    ;--------------------------------------------------------------------------
    .IF qwFileSize > 0FFFFFFFh ; 0FFFFFFFh = 256MB (268,435,455bytes) - 1FFFFFFFh = 536MB (536,870,911bytes)
        Invoke CreateFileMapping, hFile, NULL, PAGE_READONLY, 0, 0FFFFFFFh, NULL
    .ELSE
        Invoke CreateFileMapping, hFile, NULL, PAGE_READONLY, 0, 0, NULL ; Create memory mapped file
    .ENDIF
    .IF rax == NULL
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
    .ENDIF
    mov MemMapHandle, rax ; store mapping handle

    ;--------------------------------------------------------------------------
    ; Create view of file
    ;--------------------------------------------------------------------------
    Invoke MapViewOfFileEx, MemMapHandle, FILE_MAP_READ, 0, 0, 0, NULL
    .IF rax == NULL
        Invoke CloseHandle, MemMapHandle
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
    .ENDIF
    mov MemMapPtr, rax ; store map view pointer
    
    ;--------------------------------------------------------------------------
    ; Set text of input box to contents of text based file
    ;--------------------------------------------------------------------------
    Invoke SetWindowText, hCDTextEditInput, MemMapPtr
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    .IF MemMapPtr != 0
        Invoke UnmapViewOfFile, MemMapPtr
    .ENDIF
    .IF MemMapHandle != 0
        Invoke CloseHandle, MemMapHandle
    .ENDIF
    .IF hFile != 0
        Invoke CloseHandle, hFile
    .ENDIF
    
    mov rax, TRUE
    ret
CDTextLoadText ENDP

;------------------------------------------------------------------------------
; CDTextSaveText - Save masm style data from output edit control to a file
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextSaveText PROC FRAME lpszFilename:QWORD
    LOCAL hFile:QWORD
    LOCAL BytesWritten:QWORD
    LOCAL LenOutputText:QWORD
    
    ;--------------------------------------------------------------------------
    ; Create output file
    ;--------------------------------------------------------------------------
    Invoke CreateFile, lpszFilename, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF rax == INVALID_HANDLE_VALUE
        IFDEF DEBUG64
        PrintText 'CDTextSaveText CreateFile Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov hFile, rax
    
    ;--------------------------------------------------------------------------
    ; Get the text from the output edit control
    ;--------------------------------------------------------------------------
    Invoke GetWindowText, hCDTextEditOutput, pEdtOutputBuffer, CDTEXT_MAX_OUTPUTTEXT
    .IF rax == 0
        mov rax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, pEdtOutputBuffer
    mov LenOutputText, rax
    
    ;--------------------------------------------------------------------------
    ; Write out masm data bytes to file
    ;--------------------------------------------------------------------------
    Invoke WriteFile, hFile, pEdtOutputBuffer, dword ptr LenOutputText, Addr BytesWritten, NULL
    .IF rax == 0
        .IF hFile != 0
            Invoke CloseHandle, hFile
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    mov rax, TRUE
    ret
CDTextSaveText ENDP

;------------------------------------------------------------------------------
; CDTextCompressText - Compresses the text from the input edit control and pass
; the compressed data to CDTextAsmOutput to format for the masm data bytes and
; output to the output edit control.
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextCompressText PROC FRAME hWin:QWORD
    LOCAL lenEditInputText:QWORD
    LOCAL pData:QWORD
    LOCAL lenData:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDTextCompressTextBlock'
    ENDIF
    
    Invoke GetWindowText, hCDTextEditInput, pEdtInputBuffer, CDTEXT_MAX_INPUTTEXT
    .IF rax == 0
        Invoke SetWindowText, hCDTextEditOutput, 0
        mov rax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, pEdtInputBuffer
    mov lenEditInputText, rax
    
    .IF CDTextAlgorithm != 0
        ;----------------------------------------------------------------------
        ; Compress text
        ;----------------------------------------------------------------------
        Invoke CDCompressMem, pEdtInputBuffer, lenEditInputText, CDTextAlgorithm, Addr lenData
        .IF rax == NULL
            mov rax, FALSE
            ret
        .ENDIF
        mov pData, rax
        
        ;----------------------------------------------------------------------
        ; Now output to masm data bytes
        ;----------------------------------------------------------------------
        Invoke CDTextAsmOutput, hWin, pData, lenData, lenEditInputText, CDTextAlgorithm
        
        ;----------------------------------------------------------------------
        ; Free compressed memory
        ;----------------------------------------------------------------------
        .IF pData != 0
            Invoke GlobalFree, pData
        .ENDIF
        
    .ELSE
        ;---------------------------------------------------------------------- 
        ; No compression, just output to masm data bytes
        ;----------------------------------------------------------------------
        Invoke CDTextAsmOutput, hWin, pEdtInputBuffer, lenEditInputText, lenEditInputText, 0
    .ENDIF
    
    mov rax, TRUE
    ret
CDTextCompressText ENDP

;------------------------------------------------------------------------------
; CDTextAsmOutput - Formats the compressed data as masm style bytes and outputs
; it to the output edit control. Frees the memory used itself.
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextAsmOutput PROC FRAME USES RBX RDI RSI hWin:QWORD, lpData:QWORD, qwDataLength:QWORD, qwOriginalLength:QWORD, qwAlgorithm:QWORD
    LOCAL pAsmData:QWORD
    LOCAL nAsmData:QWORD
    LOCAL pRawData:QWORD
    LOCAL nRawData:QWORD
    LOCAL LenDataAsm:QWORD
    LOCAL LenDataRaw:QWORD
    LOCAL MaxDataPos:QWORD
    LOCAL nRows:QWORD
    LOCAL nCurrentRow:QWORD
    LOCAL nCurrentCol:QWORD
    LOCAL LenMasmLabel:QWORD
    LOCAL LenAsciiAsmText:QWORD
    LOCAL szMasmLabel[32]:BYTE
    LOCAL strAsciiAsmText[32]:BYTE
    
    IFDEF DEBUG64
    PrintText 'CDTextAsmOutput'
    ENDIF
    
    mov rax, lpData
    mov pRawData, rax
    add rax, qwDataLength
    mov MaxDataPos, rax
    mov rax, qwDataLength
    mov LenDataRaw, rax

    ; set a default name for our asm text output 'sz' +AlgoName+ 'Text'
    Invoke lstrcpy, Addr szMasmLabel, CTEXT("sz")
    
    mov rax, qwAlgorithm
    .IF rax == COMPRESS_ALGORITHM_MSZIP
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_MSZIP
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_XPRESS
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_HUFF
    .ELSEIF rax == COMPRESS_ALGORITHM_LZMS
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_LZMS
    .ELSE
        Invoke lstrcat, Addr szMasmLabel, CTEXT("MASM")
    .ENDIF    
    Invoke lstrcat, Addr szMasmLabel, CTEXT("Text")
    Invoke lstrlen, Addr szMasmLabel
    mov LenMasmLabel, rax
    
    ;--------------------------------------------------------------------------
    ; Calc asm output length - could be neater, but its just guesstimates tbh
    ;--------------------------------------------------------------------------
    mov LenDataAsm, 0
    
    mov rax, 11 ; 13,10,'.DATA',13,10,13,10,0   = szASMData 
    add LenDataAsm, rax
    
    mov rax, LenMasmLabel
    add rax, 4 ; ' \',13,10,0                   = szASMSlash
    add LenDataAsm, rax
    
    mov rax, qwDataLength
    shr rax, 4 ; / 16
    mov nRows, rax
    
    mov rax, 6 ; '0FFh, '                       = 6 bytes per raw byte output 
    mov rbx, qwDataLength ;nRows
    mul rbx
    add LenDataAsm, rax
    
    mov rax, nRows
    add rax, 1
    mov rbx, 6
    mul rbx
    add LenDataAsm, rax
    
    mov rax, LenMasmLabel
    add LenDataAsm, rax
    add LenDataAsm, 16                          ; szASMLength
    add LenDataAsm, 4                           ; 2 x CRLF
    add LenDataAsm, 4                           ; 2 x CRLF
    add LenDataAsm, 42                          ; space semicolon space (original bytes >> compressed bytes) = 4 + 12 + 9 + 12 + 7 'bytes >> ' 
    add LenDataAsm, 64
    and LenDataAsm, 0FFFFFFF0h
    
    ;--------------------------------------------------------------------------
    ; Alloc memory for asm hex output
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, LenDataAsm
    .IF rax == NULL
        IFDEF DEBUG64
        PrintText 'CDTextAsmOutputBlock GlobalAlloc Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov pAsmData, rax
    
    Invoke lstrcpy, pAsmData, Addr szASMData
    Invoke lstrcat, pAsmData, Addr szMasmLabel
    Invoke lstrcat, pAsmData, Addr szASMSlash

    Invoke lstrlen, pAsmData
    mov nAsmData, rax

   ;--------------------------------------------------------------------------
    ; Loop start
    ;--------------------------------------------------------------------------
    mov nCurrentRow, 0
    mov nCurrentCol, 0
    mov nRawData, 0
    mov rax, 0
    .WHILE rax < LenDataRaw
    
        mov rdi, pAsmData
        add rdi, nAsmData
        
        mov rsi, pRawData
        add rsi, nRawData
        
        ;----------------------------------------------------------------------
        ; Start of row
        ;----------------------------------------------------------------------
        .IF nCurrentCol == 0
            mov rax, nAsmData
            add rax, qwASMRowStartLength
            .IF rax < LenDataAsm
                Invoke RtlMoveMemory, rdi, Addr szASMRowStart, qwASMRowStartLength
                mov rax, qwASMRowStartLength
                add nAsmData, rax
            .ENDIF
            
            mov rdi, pAsmData
            add rdi, nAsmData
            
            mov rax, nAsmData
            add rax, qwASMhcs01stLength
            .IF rax < LenDataAsm
                Invoke RtlMoveMemory, rdi, Addr szASMhcs01st, qwASMhcs01stLength
                mov rax, qwASMhcs01stLength
                add nAsmData, rax
            .ENDIF
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Convert data byte to hex ascii
        ;----------------------------------------------------------------------
        mov rdi, pAsmData
        add rdi, nAsmData

        movzx rax, byte ptr [rsi]
        mov ah, al
        ror al, 4                   ; shift in next hex digit
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            add al, ("A"-10)        ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ENDIF
        mov byte ptr [rdi], al      ; store the asciihex(AL) in the string   
        inc rdi
        inc nAsmData
        mov al,ah
        
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            add al, ("A"-10)        ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ENDIF
        mov byte ptr [rdi], al      ; store the asciihex(AL) in the string   
        inc nAsmData
        
        ;----------------------------------------------------------------------
        ; Row Processing, split row every 16th column
        ;----------------------------------------------------------------------
        mov rdi, pAsmData
        add rdi, nAsmData
        
        inc nCurrentCol
        mov rax, nCurrentCol
        .IF rax == 16
            
            ;------------------------------------------------------------------
            ; End of Row
            ;------------------------------------------------------------------
            mov rax, nAsmData
            add rax, qwASMRowEndLength
            .IF rax < LenDataAsm
                Invoke RtlMoveMemory, rdi, Addr szASMRowEnd, qwASMRowEndLength
                mov rax, qwASMRowEndLength
                add nAsmData, rax
            .ENDIF
            
            mov nCurrentCol, 0
        .ELSE
        
            mov rax, nRawData
            inc rax
            .IF rax < LenDataRaw
                
                ;--------------------------------------------------------------
                ; Row Continues
                ;--------------------------------------------------------------
                mov rax, nAsmData
                add rax, qwASMhcs0Length
                .IF rax < LenDataAsm
                    Invoke RtlMoveMemory, rdi, Addr szASMhcs0, qwASMhcs0Length
                    mov rax, qwASMhcs0Length
                    add nAsmData, rax
                .ENDIF
            
            .ELSE
                ;--------------------------------------------------------------
                ; End of Data - Last Row End
                ;--------------------------------------------------------------
                mov rax, nAsmData
                add rax, qwASMRowEndLength
                .IF rax < LenDataAsm
                    Invoke RtlMoveMemory, rdi, Addr szASMRowEnd, qwASMRowEndLength
                    mov rax, qwASMRowEndLength
                    add nAsmData, rax
                .ENDIF
                
            .ENDIF
        
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Fetch next data byte to convert and loop again if < LenRawData
        ;----------------------------------------------------------------------
        inc nRawData
        mov rax, nRawData
    .ENDW

    ;--------------------------------------------------------------------------
    ; Do end where we define length of data using namelength dd $ - name
    ;--------------------------------------------------------------------------
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szASMCFLF, qwASMCFLFLength
    mov rax, qwASMCFLFLength
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szMasmLabel, LenMasmLabel
    mov rax, LenMasmLabel
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szASMLength, qwASMLengthLength
    mov rax, qwASMLengthLength
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szMasmLabel, LenMasmLabel
    mov rax, LenMasmLabel
    add nAsmData, rax
    
    .IF qwAlgorithm != 0
    
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr szASMTextStart, qwASMTextStartLength
        mov rax, qwASMTextStartLength
        add nAsmData, rax
        
        Invoke qwtoa, qwOriginalLength, Addr strAsciiAsmText
        Invoke lstrlen, Addr strAsciiAsmText
        mov LenAsciiAsmText, rax
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr strAsciiAsmText, LenAsciiAsmText
        mov rax, LenAsciiAsmText
        add nAsmData, rax
    
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr szASMTextMiddle, qwASMTextMiddleLength
        mov rax, qwASMTextMiddleLength
        add nAsmData, rax
        
        Invoke qwtoa, qwDataLength, Addr strAsciiAsmText
        Invoke lstrlen, Addr strAsciiAsmText
        mov LenAsciiAsmText, rax
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr strAsciiAsmText, LenAsciiAsmText
        mov rax, LenAsciiAsmText
        add nAsmData, rax
        
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr szASMTextEnd, qwASMTextEndLength
        mov rax, qwASMTextEndLength
        add nAsmData, rax
        
    .ELSE
    
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr szASMTextStart, qwASMTextStartLength
        mov rax, qwASMTextStartLength
        add nAsmData, rax
        
        Invoke qwtoa, qwOriginalLength, Addr strAsciiAsmText
        Invoke lstrlen, Addr strAsciiAsmText
        mov LenAsciiAsmText, rax
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr strAsciiAsmText, LenAsciiAsmText
        mov rax, LenAsciiAsmText
        add nAsmData, rax
    
        mov rdi, pAsmData
        add rdi, nAsmData
        Invoke RtlMoveMemory, rdi, Addr szASMTextEnd, qwASMTextEndLength
        mov rax, qwASMTextEndLength
        add nAsmData, rax
    
    .ENDIF

    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szASMCFLF, qwASMCFLFLength
    mov rax, qwASMCFLFLength
    add nAsmData, rax

    ;--------------------------------------------------------------------------
    ; Output asm text to edit control and free up memory
    ;--------------------------------------------------------------------------    
    Invoke SetWindowText, hCDTextEditOutput, pAsmData
    mov rax, nAsmData
    sub rax, 2 ; move back past CRLF
    Invoke SendMessage, hCDTextEditOutput, EM_SETSEL, rax, rax
    Invoke SendMessage, hCDTextEditOutput, EM_SCROLLCARET, 0, 0

    Invoke GlobalFree, pAsmData
    
    mov eax, TRUE
    ret
CDTextAsmOutput ENDP










