;------------------------------------------------------------------------------
; CD - Compress-Decompress Utility using MS Compression API
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

CDTextDlgProc                   PROTO hWin:HWND, iMsg:DWORD, wParam:WPARAM, lParam:LPARAM
CDTextInitGUI                   PROTO hWin:DWORD
CDTextInitTipsForEachChild      PROTO hChild:DWORD, lParam:DWORD
CDTextBrowseForFile             PROTO hWin:DWORD, bLoad:DWORD

CDTextPasteText                 PROTO hWin:DWORD
CDTextCopyText                  PROTO hWin:DWORD
CDTextLoadText                  PROTO hWin:DWORD
CDTextSaveText                  PROTO hWin:DWORD

CDTextCompressText              PROTO hWin:DWORD
CDTextAsmOutput                 PROTO hWin:DWORD, lpData:DWORD, dwDataLength:DWORD, dwOriginalLength:DWORD, dwAlgorithm:DWORD


; Reference to other functions in other files:
EXTERN CDCompressMem:           PROTO lpUncompressedData:DWORD, dwUncompressedDataLength:DWORD, dwCompressionAlgorithm:DWORD, lpdwCompressedDataLength:DWORD
EXTERN CDDecompressMem:         PROTO pCompressedData:DWORD, dwCompressedDataLength:DWORD

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
szCDTextCourierNewFont          DB "Courier New",0
szCDTextSZ                      DB "sz",0
szCDTextMASM                    DB "MASM",0
szCDTextTEXT                    DB "Text",0

CDOpenTextFileFilter            DB "Text Files (*.txt,*.asm,*.inc)",0,"*.txt;*.asm;*.inc",0
                                DB "All Files (*.*)",0,"*.*",0
                                DB 0

CDTextAlgorithm                 DD COMPRESS_ALGORITHM_XPRESS
CDTextFileName                  DB MAX_PATH DUP (0)

hFontEdt                        DD 0
hCDTextToolTip                  DD 0
hCDTextEditInput                DD 0
hCDTextEditOutput               DD 0

pEdtInputBuffer                 DD 0 ; max 256K
pEdtOutputBuffer                DD 0 ; max 2048K

.CODE
;------------------------------------------------------------------------------
; CD Compress Text Strings Dialog Procedure
;------------------------------------------------------------------------------
CDTextDlgProc PROC hWin:HWND, iMsg:DWORD, wParam:WPARAM, lParam:LPARAM
    LOCAL wNotifyCode:DWORD
    
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
        mov eax, wParam
        shr eax, 16
        mov wNotifyCode, eax
        mov eax, wParam
        and eax, 0FFFFh
        
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
            .IF eax == TRUE
                Invoke CDTextSaveText, Addr CDTextFileName
            .ENDIF
            Invoke SetFocus, hCDTextEditOutput
        
        ;----------------------------------------------------------------------
        ; Input Edit Control Change Event
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_EDT_TEXT_INPUT
            mov eax, wNotifyCode
            .IF eax == EN_CHANGE
                IFDEF DEBUG32
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
CDTextInitGUI PROC USES EBX hWin:DWORD
    LOCAL hMainMenu:DWORD
    LOCAL hBitmap:DWORD
    LOCAL hFont:DWORD
    LOCAL lfnt:LOGFONT

    Invoke GetDlgItem, hWin, IDC_EDT_TEXT_INPUT
    mov hCDTextEditInput, eax
    Invoke GetDlgItem, hWin, IDC_EDT_DATA_OUTPUT
    mov hCDTextEditOutput, eax
    
    ;--------------------------------------------------------------------------
    ; Alloc memory for buffers
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, CDTEXT_MAX_INPUTTEXT
    mov pEdtInputBuffer, eax
    
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, CDTEXT_MAX_OUTPUTTEXT
    mov pEdtOutputBuffer, eax
    
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
    mov eax, CDTextAlgorithm
    .IF eax == COMPRESS_ALGORITHM_MSZIP
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_HUFF, BM_SETCHECK, BST_CHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
        Invoke SendDlgItemMessage, hWin, IDC_RBN_TXT_NONE, BM_SETCHECK, BST_UNCHECKED, 0
    .ELSEIF eax == COMPRESS_ALGORITHM_LZMS
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
    Invoke CreateWindowEx, NULL, Addr szTooltipsClass, NULL, TTS_ALWAYSTIP, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hWin, NULL, hInstance, NULL
    mov hCDTextToolTip, eax
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
    Invoke SendDlgItemMessage, hWin, IDC_BTN_CLEAR_TEXT, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_LOADFILE_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_LOADFILE_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_LOAD_TEXT, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_SAVEFILE_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_SAVEFILE_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_SAVE_OUTPUT, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_COPYDATA_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_COPYDATA_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_COPY_OUTPUT, BM_SETIMAGE, IMAGE_BITMAP, eax

    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_PASTETEXT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_PASTETEXT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_PASTE_TEXT, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_CLOSE_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMS_CLOSE_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_CLOSE, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    ;--------------------------------------------------------------------------
    ; Set font for input and output edit controls
    ;--------------------------------------------------------------------------
    Invoke SendMessage, hWin, WM_GETFONT, 0, 0
    mov hFont, eax
    Invoke GetObject, hFont, SIZEOF lfnt, Addr lfnt
    mov eax, lfnt.lfHeight
    add eax, 2
    mov lfnt.lfHeight, eax
    lea ebx, lfnt.lfFaceName
    Invoke lstrcpy, ebx, Addr szCDTextCourierNewFont
    Invoke CreateFontIndirect, Addr lfnt
    mov hFontEdt, eax
    
    Invoke SendMessage, hCDTextEditInput, WM_SETFONT, hFontEdt, TRUE
    Invoke SendMessage, hCDTextEditOutput, WM_SETFONT, hFontEdt, TRUE
    Invoke SendMessage, hCDTextEditOutput, EM_SETLIMITTEXT, CDTEXT_MAX_INPUTTEXT, 0     ; Limit to 256K
    Invoke SendMessage, hCDTextEditOutput, EM_SETLIMITTEXT, CDTEXT_MAX_OUTPUTTEXT, 0    ; Limit to 2048K
    
    xor eax, eax
    ret
CDTextInitGUI ENDP

;------------------------------------------------------------------------------
; CDTextInitTipsForEachChild - initialize tooltips for each control
; 
; Returns: TRUE
;------------------------------------------------------------------------------
CDTextInitTipsForEachChild PROC USES EBX hChild:DWORD, lParam:DWORD
    LOCAL TooltipText[256]:BYTE
    LOCAL TooltipTextID:DWORD
    LOCAL tti:TTTOOLINFOA

    mov tti.cbSize, SIZEOF TTTOOLINFOA
    mov tti.uFlags, TTF_IDISHWND or TTF_SUBCLASS
    
    Invoke GetParent, hChild
    mov tti.hWnd, eax

    mov eax, hChild
    mov tti.uId, eax

    mov eax, hInstance
    mov tti.hInst, eax
    
    Invoke GetDlgCtrlID, hChild
    mov TooltipTextID, eax

    Invoke LoadString, hInstance, TooltipTextID, Addr TooltipText, 256
    .IF eax == 0
        ; ignore controls we didnt set a tooltip text for in the stringtable
    .ELSE
        lea eax, TooltipText
        mov tti.lpszText, eax
        Invoke SendMessage, hCDTextToolTip, TTM_ADDTOOL, NULL, Addr tti
        Invoke SendMessage, hCDTextToolTip, TTM_ACTIVATE, TRUE, 0
    .ENDIF

    mov eax, TRUE
    ret
CDTextInitTipsForEachChild ENDP

;------------------------------------------------------------------------------
; CDTextBrowseForFile - Browse for a file to open. Stores the selected file in 
; CDTextFileName
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextBrowseForFile PROC hWin:DWORD, bLoad:DWORD
    LOCAL BrowseForFile:OPENFILENAME

    IFDEF DEBUG32
    PrintText 'CDBrowseForFile'
    ENDIF
    
    Invoke RtlZeroMemory, Addr CDTextFileName, SIZEOF CDTextFileName
    Invoke RtlZeroMemory, Addr BrowseForFile, SIZEOF OPENFILENAME
    
    mov BrowseForFile.lStructSize, SIZEOF OPENFILENAME
    mov eax, hWin
    mov BrowseForFile.hwndOwner, eax
    mov BrowseForFile.nMaxFile, MAX_PATH
    mov BrowseForFile.lpstrDefExt, 0
    lea eax, CDOpenTextFileFilter
    mov BrowseForFile.lpstrFilter, eax
    mov BrowseForFile.Flags, OFN_EXPLORER or OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
    lea eax, CDTextFileName
    mov BrowseForFile.lpstrFile, eax
    .IF bLoad == TRUE
        Invoke GetOpenFileName, Addr BrowseForFile
    .ELSE
        Invoke GetSaveFileName, Addr BrowseForFile
    .ENDIF
    ; If user selected a file and didnt cancel browse operation...
    .IF eax !=0
        mov eax, TRUE
    .ELSE
        mov eax, FALSE
    .ENDIF
    ret

CDTextBrowseForFile ENDP

;------------------------------------------------------------------------------
; CDTextPasteText - paste text from clipboard
;
; Returns: nothing
;------------------------------------------------------------------------------
CDTextPasteText PROC hWin:DWORD
    LOCAL hClipData:DWORD
    LOCAL lpszClipText:DWORD
    
    IFDEF DEBUG32
    PrintText 'CDTextPasteText'
    ENDIF
    
    Invoke OpenClipboard, hWin
    .IF eax == TRUE
        Invoke IsClipboardFormatAvailable, CF_TEXT
        .IF eax == TRUE
            Invoke GetClipboardData, CF_TEXT
            .IF eax != NULL
                mov hClipData, eax
                Invoke GlobalLock, hClipData
                .IF eax != NULL
                    mov lpszClipText, eax
                    Invoke SetWindowText, hCDTextEditInput, lpszClipText
                    Invoke GlobalUnlock, hClipData
                    Invoke SendMessage, hCDTextEditInput, EM_SETSEL, -1, 0
                .ENDIF
            .ENDIF    
        .ENDIF
        Invoke CloseClipboard
    .ENDIF
    
    xor eax, eax
    ret
CDTextPasteText ENDP

;------------------------------------------------------------------------------
; CDTextCopyText - Copy output data byte text to clipboard
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextCopyText PROC hWin:DWORD
    LOCAL hClipData:DWORD
    LOCAL pClipData:DWORD
    LOCAL lenClipText:DWORD
    
    IFDEF DEBUG32
    PrintText 'CDTextCopyText'
    ENDIF
    
    Invoke GetWindowText, hCDTextEditOutput, pEdtOutputBuffer, CDTEXT_MAX_OUTPUTTEXT
    .IF eax == 0
        mov eax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, pEdtOutputBuffer
    mov lenClipText, eax
    add eax, 4
    
    Invoke GlobalAlloc, GMEM_MOVEABLE, eax
    .IF eax == NULL
        mov eax, FALSE
        ret
    .ENDIF
    mov hClipData, eax
    
    Invoke GlobalLock, hClipData
    .IF eax == NULL
        mov eax, FALSE
        ret
    .ENDIF
    mov pClipData, eax
    
    Invoke lstrcpyn, pClipData, pEdtOutputBuffer, lenClipText
    Invoke GlobalUnlock, hClipData
    
    Invoke OpenClipboard, hWin
    .IF eax == TRUE
        Invoke EmptyClipboard
        Invoke SetClipboardData, CF_TEXT, hClipData
        Invoke CloseClipboard
    .ENDIF
    Invoke MessageBeep, MB_OK ; beep hopefully tells user that copy to clipboard was done
    
    mov eax, TRUE
    ret
CDTextCopyText ENDP

;------------------------------------------------------------------------------
; CDTextLoadText - Load text from a file into the input edit control
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextLoadText PROC lpszFilename:DWORD
    LOCAL hFile:DWORD
    LOCAL MemMapHandle:DWORD
    LOCAL MemMapPtr:DWORD
    LOCAL dwFileSize:DWORD
    
    IFDEF DEBUG32
    PrintText 'CDOpenFile'
    ENDIF

    ;--------------------------------------------------------------------------
    ; Some basic checks
    ;--------------------------------------------------------------------------
    .IF lpszFilename == NULL
        mov eax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, lpszFilename
    .IF eax == 0 || eax > MAX_PATH
        mov eax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Open file for read only or read/write access
    ;--------------------------------------------------------------------------
    Invoke CreateFile, lpszFilename, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL
    .IF eax == INVALID_HANDLE_VALUE
        mov eax, FALSE
        ret
    .ENDIF
    mov hFile, eax ; store file handle

    ;--------------------------------------------------------------------------
    ; Get file size and verify its not too low or too high in size
    ;--------------------------------------------------------------------------
    Invoke GetFileSize, hFile, NULL
    .IF eax > 0FFFFFFFh ; 0FFFFFFFh = 256MB (268,435,455bytes) - 1FFFFFFFh = 536MB (536,870,911bytes)
        Invoke CloseHandle, hFile
        mov eax, FALSE
        ret
     .ENDIF
    mov dwFileSize, eax ; file size

    ;--------------------------------------------------------------------------
    ; Create file mapping of entire file
    ;--------------------------------------------------------------------------
    .IF dwFileSize > 0FFFFFFFh ; 0FFFFFFFh = 256MB (268,435,455bytes) - 1FFFFFFFh = 536MB (536,870,911bytes)
        Invoke CreateFileMapping, hFile, NULL, PAGE_READONLY, 0, 0FFFFFFFh, NULL
    .ELSE
        Invoke CreateFileMapping, hFile, NULL, PAGE_READONLY, 0, 0, NULL ; Create memory mapped file
    .ENDIF
    .IF eax == NULL
        Invoke CloseHandle, hFile
        mov eax, FALSE
        ret
    .ENDIF
    mov MemMapHandle, eax ; store mapping handle

    ;--------------------------------------------------------------------------
    ; Create view of file
    ;--------------------------------------------------------------------------
    Invoke MapViewOfFileEx, MemMapHandle, FILE_MAP_READ, 0, 0, 0, NULL
    .IF eax == NULL
        Invoke CloseHandle, MemMapHandle
        Invoke CloseHandle, hFile
        mov eax, FALSE
        ret
    .ENDIF
    mov MemMapPtr, eax ; store map view pointer
    
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
    
    mov eax, TRUE
    ret
CDTextLoadText ENDP

;------------------------------------------------------------------------------
; CDTextSaveText - Save masm style data from output edit control to a file
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextSaveText PROC lpszFilename:DWORD
    LOCAL hFile:DWORD
    LOCAL BytesWritten:DWORD
    LOCAL LenOutputText:DWORD
    
    ;--------------------------------------------------------------------------
    ; Create output file
    ;--------------------------------------------------------------------------
    Invoke CreateFile, lpszFilename, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        IFDEF DEBUG32
        PrintText 'CDTextSaveText CreateFile Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov hFile, eax
    
    ;--------------------------------------------------------------------------
    ; Get the text from the output edit control
    ;--------------------------------------------------------------------------
    Invoke GetWindowText, hCDTextEditOutput, pEdtOutputBuffer, CDTEXT_MAX_OUTPUTTEXT
    .IF eax == 0
        mov eax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, pEdtOutputBuffer
    mov LenOutputText, eax
    
    ;--------------------------------------------------------------------------
    ; Write out masm data bytes to file
    ;--------------------------------------------------------------------------
    Invoke WriteFile, hFile, pEdtOutputBuffer, LenOutputText, Addr BytesWritten, NULL
    .IF eax == 0
        .IF hFile != 0
            Invoke CloseHandle, hFile
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    mov eax, TRUE
    ret
CDTextSaveText ENDP

;------------------------------------------------------------------------------
; CDTextCompressText - Compresses the text from the input edit control and pass
; the compressed data to CDTextAsmOutput to format for the masm data bytes and
; output to the output edit control.
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextCompressText PROC hWin:DWORD
    LOCAL lenEditInputText:DWORD
    LOCAL pData:DWORD
    LOCAL lenData:DWORD
    
    IFDEF DEBUG32
    PrintText 'CDTextCompressTextBlock'
    ENDIF
    
    Invoke GetWindowText, hCDTextEditInput, pEdtInputBuffer, CDTEXT_MAX_INPUTTEXT
    .IF eax == 0
        Invoke SetWindowText, hCDTextEditOutput, 0
        mov eax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, pEdtInputBuffer
    mov lenEditInputText, eax
    
    .IF CDTextAlgorithm != 0
        ;----------------------------------------------------------------------
        ; Compress text
        ;----------------------------------------------------------------------
        Invoke CDCompressMem, pEdtInputBuffer, lenEditInputText, CDTextAlgorithm, Addr lenData
        .IF eax == NULL
            mov eax, FALSE
            ret
        .ENDIF
        mov pData, eax
        
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
    
    mov eax, TRUE
    ret
CDTextCompressText ENDP

;------------------------------------------------------------------------------
; CDTextAsmOutput - Formats the compressed data as masm style bytes and outputs
; it to the output edit control. Frees the memory used itself.
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDTextAsmOutput PROC USES EBX EDI ESI hWin:DWORD, lpData:DWORD, dwDataLength:DWORD, dwOriginalLength:DWORD, dwAlgorithm:DWORD
    LOCAL pAsmData:DWORD
    LOCAL nAsmData:DWORD
    LOCAL pRawData:DWORD
    LOCAL nRawData:DWORD
    LOCAL LenDataAsm:DWORD
    LOCAL LenDataRaw:DWORD
    LOCAL MaxDataPos:DWORD
    LOCAL nRows:DWORD
    LOCAL nCurrentRow:DWORD
    LOCAL nCurrentCol:DWORD
    LOCAL LenMasmLabel:DWORD
    LOCAL LenAsciiAsmText:DWORD
    LOCAL szMasmLabel[32]:BYTE
    LOCAL strAsciiAsmText[32]:BYTE
    
    IFDEF DEBUG32
    PrintText 'CDTextAsmOutput'
    ENDIF
    
    mov eax, lpData
    mov pRawData, eax
    add eax, dwDataLength
    mov MaxDataPos, eax
    mov eax, dwDataLength
    mov LenDataRaw, eax

    ; set a default name for our asm text output 'sz' +AlgoName+ 'Text'
    Invoke lstrcpy, Addr szMasmLabel, Addr szCDTextSZ
    
    mov eax, dwAlgorithm
    .IF eax == COMPRESS_ALGORITHM_MSZIP
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_MSZIP
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_XPRESS
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_HUFF
    .ELSEIF eax == COMPRESS_ALGORITHM_LZMS
        Invoke lstrcat, Addr szMasmLabel, Addr szHEADER_LZMS
    .ELSE
        Invoke lstrcat, Addr szMasmLabel, Addr szCDTextMASM
    .ENDIF    
    Invoke lstrcat, Addr szMasmLabel, Addr szCDTextTEXT
    Invoke lstrlen, Addr szMasmLabel
    mov LenMasmLabel, eax
    
    ;--------------------------------------------------------------------------
    ; Calc asm output length - could be neater, but its just guesstimates tbh
    ;--------------------------------------------------------------------------
    mov LenDataAsm, 0
    
    mov eax, 11 ; 13,10,'.DATA',13,10,13,10,0   = szASMData 
    add LenDataAsm, eax
    
    mov eax, LenMasmLabel
    add eax, 4 ; ' \',13,10,0                   = szASMSlash
    add LenDataAsm, eax
    
    mov eax, dwDataLength
    shr eax, 4 ; / 16
    mov nRows, eax
    
    mov eax, 6 ; '0FFh, '                       = 6 bytes per raw byte output 
    mov ebx, dwDataLength ;nRows
    mul ebx
    add LenDataAsm, eax
    
    mov eax, nRows
    add eax, 1
    mov ebx, 6
    mul ebx
    add LenDataAsm, eax
    
    mov eax, LenMasmLabel
    add LenDataAsm, eax
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
    .IF eax == NULL
        IFDEF DEBUG32
        PrintText 'CDTextAsmOutputBlock GlobalAlloc Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov pAsmData, eax
    
    Invoke lstrcpy, pAsmData, Addr szASMData
    Invoke lstrcat, pAsmData, Addr szMasmLabel
    Invoke lstrcat, pAsmData, Addr szASMSlash

    Invoke lstrlen, pAsmData
    mov nAsmData, eax

    ;--------------------------------------------------------------------------
    ; Loop start
    ;--------------------------------------------------------------------------
    mov nCurrentRow, 0
    mov nCurrentCol, 0
    mov nRawData, 0
    mov eax, 0
    .WHILE eax < LenDataRaw
    
        mov edi, pAsmData
        add edi, nAsmData
        
        mov esi, pRawData
        add esi, nRawData
        
        ;----------------------------------------------------------------------
        ; Start of row
        ;----------------------------------------------------------------------
        .IF nCurrentCol == 0
            mov eax, nAsmData
            add eax, dwASMRowStartLength
            .IF eax < LenDataAsm
                Invoke RtlMoveMemory, edi, Addr szASMRowStart, dwASMRowStartLength
                mov eax, dwASMRowStartLength
                add nAsmData, eax
            .ENDIF
            
            mov edi, pAsmData
            add edi, nAsmData
            
            mov eax, nAsmData
            add eax, dwASMhcs01stLength
            .IF eax < LenDataAsm
                Invoke RtlMoveMemory, edi, Addr szASMhcs01st, dwASMhcs01stLength
                mov eax, dwASMhcs01stLength
                add nAsmData, eax
            .ENDIF
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Convert data byte to hex ascii
        ;----------------------------------------------------------------------
        mov edi, pAsmData
        add edi, nAsmData

        movzx eax, byte ptr [esi]
        mov ah, al
        ror al, 4                   ; shift in next hex digit
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            add al, ("A"-10)        ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ENDIF
        mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
        inc edi
        inc nAsmData
        mov al,ah
        
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            add al, ("A"-10)        ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ENDIF
        mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
        inc nAsmData
        
        ;----------------------------------------------------------------------
        ; Row Processing, split row every 16th column
        ;----------------------------------------------------------------------
        mov edi, pAsmData
        add edi, nAsmData
        
        inc nCurrentCol
        mov eax, nCurrentCol
        .IF eax == 16
            
            ;------------------------------------------------------------------
            ; End of Row
            ;------------------------------------------------------------------
            mov eax, nAsmData
            add eax, dwASMRowEndLength
            .IF eax < LenDataAsm
                Invoke RtlMoveMemory, edi, Addr szASMRowEnd, dwASMRowEndLength
                mov eax, dwASMRowEndLength
                add nAsmData, eax
            .ENDIF
            
            mov nCurrentCol, 0
        .ELSE
        
            mov eax, nRawData
            inc eax
            .IF eax < LenDataRaw
                
                ;--------------------------------------------------------------
                ; Row Continues
                ;--------------------------------------------------------------
                mov eax, nAsmData
                add eax, dwASMhcs0Length
                .IF eax < LenDataAsm
                    Invoke RtlMoveMemory, edi, Addr szASMhcs0, dwASMhcs0Length
                    mov eax, dwASMhcs0Length
                    add nAsmData, eax
                .ENDIF
            
            .ELSE
                ;--------------------------------------------------------------
                ; End of Data - Last Row End
                ;--------------------------------------------------------------
                mov eax, nAsmData
                add eax, dwASMRowEndLength
                .IF eax < LenDataAsm
                    Invoke RtlMoveMemory, edi, Addr szASMRowEnd, dwASMRowEndLength
                    mov eax, dwASMRowEndLength
                    add nAsmData, eax
                .ENDIF
                
            .ENDIF
        
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Fetch next data byte to convert and loop again if < LenRawData
        ;----------------------------------------------------------------------
        inc nRawData
        mov eax, nRawData
    .ENDW

    ;--------------------------------------------------------------------------
    ; Do end where we define length of data using namelength dd $ - name
    ;--------------------------------------------------------------------------
    mov edi, pAsmData
    add edi, nAsmData
    Invoke RtlMoveMemory, edi, Addr szASMCFLF, dwASMCFLFLength
    mov eax, dwASMCFLFLength
    add nAsmData, eax
    
    mov edi, pAsmData
    add edi, nAsmData
    Invoke RtlMoveMemory, edi, Addr szMasmLabel, LenMasmLabel
    mov eax, LenMasmLabel
    add nAsmData, eax
    
    mov edi, pAsmData
    add edi, nAsmData
    Invoke RtlMoveMemory, edi, Addr szASMLength, dwASMLengthLength
    mov eax, dwASMLengthLength
    add nAsmData, eax
    
    mov edi, pAsmData
    add edi, nAsmData
    Invoke RtlMoveMemory, edi, Addr szMasmLabel, LenMasmLabel
    mov eax, LenMasmLabel
    add nAsmData, eax
    
    .IF dwAlgorithm != 0
    
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr szASMTextStart, dwASMTextStartLength
        mov eax, dwASMTextStartLength
        add nAsmData, eax
        
        Invoke dwtoa, dwOriginalLength, Addr strAsciiAsmText
        Invoke lstrlen, Addr strAsciiAsmText
        mov LenAsciiAsmText, eax
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr strAsciiAsmText, LenAsciiAsmText
        mov eax, LenAsciiAsmText
        add nAsmData, eax
    
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr szASMTextMiddle, dwASMTextMiddleLength
        mov eax, dwASMTextMiddleLength
        add nAsmData, eax
        
        Invoke dwtoa, dwDataLength, Addr strAsciiAsmText
        Invoke lstrlen, Addr strAsciiAsmText
        mov LenAsciiAsmText, eax
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr strAsciiAsmText, LenAsciiAsmText
        mov eax, LenAsciiAsmText
        add nAsmData, eax
        
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr szASMTextEnd, dwASMTextEndLength
        mov eax, dwASMTextEndLength
        add nAsmData, eax
        
    .ELSE
    
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr szASMTextStart, dwASMTextStartLength
        mov eax, dwASMTextStartLength
        add nAsmData, eax
        
        Invoke dwtoa, dwOriginalLength, Addr strAsciiAsmText
        Invoke lstrlen, Addr strAsciiAsmText
        mov LenAsciiAsmText, eax
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr strAsciiAsmText, LenAsciiAsmText
        mov eax, LenAsciiAsmText
        add nAsmData, eax
    
        mov edi, pAsmData
        add edi, nAsmData
        Invoke RtlMoveMemory, edi, Addr szASMTextEnd, dwASMTextEndLength
        mov eax, dwASMTextEndLength
        add nAsmData, eax
    
    .ENDIF

    mov edi, pAsmData
    add edi, nAsmData
    Invoke RtlMoveMemory, edi, Addr szASMCFLF, dwASMCFLFLength
    mov eax, dwASMCFLFLength
    add nAsmData, eax

    ;--------------------------------------------------------------------------
    ; Output asm text to edit control and free up memory
    ;--------------------------------------------------------------------------    
    Invoke SetWindowText, hCDTextEditOutput, pAsmData
    mov eax, nAsmData
    sub eax, 2 ; move back past CRLF
    Invoke SendMessage, hCDTextEditOutput, EM_SETSEL, eax, eax
    Invoke SendMessage, hCDTextEditOutput, EM_SCROLLCARET, 0, 0

    Invoke GlobalFree, pAsmData
    
    mov eax, TRUE
    ret
CDTextAsmOutput ENDP










