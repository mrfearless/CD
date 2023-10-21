;------------------------------------------------------------------------------
; CD - Compress-Decompress Utility using MS Compression Api (Cabinet.dll) 
; fearles 2023 - github.com/mrfearless
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
; 2) Adding LZMS compressed bitmap files (.lzms) as RC_DATA resources which are 
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
;
; CD.EXE 57.0 KB (58,368 bytes) without LZMA resources (normal bitmap resources)
;
; About_Button.bmp            6.05 KB (6,198 bytes)
; About_Menu.bmp              1.61 KB (1,654 bytes)
; Compress_Button.bmp         6.05 KB (6,198 bytes)
; Compress_Menu.bmp           1.05 KB (1,078 bytes)
; Decompress_Button.bmp       6.05 KB (6,198 bytes)
; Decompress_Menu.bmp         1.05 KB (1,078 bytes)
; Exit_Button.bmp             6.05 KB (6,198 bytes)
; Exit_Menu.bmp               1.05 KB (1,078 bytes)
;                             ---------------------
;                            28.90 KB (29,680 bytes)
;
;
; CD.EXE 31.0 KB (31,744 bytes) with LZMA resources (RC_DATA lzma files)
;
; About_Button.bmp.lzms       0.36 KB (366 Bytes)
; About_Menu.bmp.lzms         0.26 KB (262 Bytes)
; Compress_Button.bmp.lzms    0.42 KB (426 Bytes)
; Compress_Menu.bmp.lzms      0.30 KB (304 Bytes)
; Decompress_Button.bmp.lzms  0.35 KB (352 Bytes)
; Decompress_Menu.bmp.lzms    0.27 KB (272 Bytes)
; Exit_Button.bmp.lzms        0.33 KB (332 Bytes)
; Exit_Menu.bmp.lzms          0.36 KB (366 Bytes)
;                             ---------------------
;                             2.61 KB (2,680 bytes)
;
; Project->Project Options has a define added to the resource compiler as
; "/d LZMA_RESOURCES" to allow for switching between resource files in CD.rc
; (CDRes.rc.lzma or CDRes.rc.normal):
;
; Compile RC: 4,O,$B\RC.EXE /v /d LZMA_RESOURCES,1
;
; The define in the assembler file should also be uncommented if using LZMA:
;
; LZMA_RESOURCES EQU 1
;
; If not using LZMA resources, then remove the "/d LZMA_RESOURCES" from the 
; resource compiler options and comment out the "LZMA_RESOURCES EQU 1" line
;
;------------------------------------------------------------------------------

.686
.MMX
.XMM
.model flat,stdcall
option casemap:none
include \masm32\macros\macros.asm

LZMA_RESOURCES EQU 1 ; comment out to use normal bitmap resources

;DEBUG32 EQU 1

IFDEF DEBUG32
    PRESERVEXMMREGS equ 1
    includelib M:\Masm32\lib\Debug32.lib
    DBG32LIB equ 1
    DEBUGEXE textequ <'M:\Masm32\DbgWin.exe'>
    include M:\Masm32\include\debug32.inc
ENDIF

include CD.inc
include .\Images\CD128x128x4.bmp.asm
include AboutDlg.asm


.code

start:

    Invoke GetModuleHandle, NULL
    mov hInstance, eax
    
    invoke LoadAccelerators, hInstance, ACCTABLE
    mov hAcc, eax
    
    Invoke GetCommandLine
    mov CommandLine, eax
    Invoke InitCommonControls
    mov icc.dwSize, sizeof INITCOMMONCONTROLSEX
    mov icc.dwICC, ICC_COOL_CLASSES or ICC_STANDARD_CLASSES or ICC_WIN95_CLASSES
    Invoke InitCommonControlsEx, Offset icc
    
    Invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
    Invoke ExitProcess, eax

;------------------------------------------------------------------------------
; WinMain
;------------------------------------------------------------------------------
WinMain PROC hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, Offset WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, DLGWINDOWEXTRA
    push hInst
    pop wc.hInstance
    mov wc.hbrBackground, COLOR_BTNFACE+1 ; COLOR_WINDOW+1
    mov wc.lpszMenuName, IDM_MENU
    mov wc.lpszClassName, Offset ClassName
    ;Invoke LoadIcon, NULL, IDI_APPLICATION
    Invoke LoadIcon, hInstance, ICO_MAIN ; resource icon for main application icon
    mov hIcoMain, eax ; main application icon
    mov  wc.hIcon, eax
    mov wc.hIconSm, eax
    Invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor,eax
    Invoke RegisterClassEx, Addr wc
    Invoke CreateDialogParam, hInstance, IDD_DIALOG, NULL, Addr WndProc, NULL
    mov hWnd, eax
    Invoke ShowWindow, hWnd, SW_SHOWNORMAL
    Invoke UpdateWindow, hWnd
    .WHILE TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .BREAK .if !eax

        Invoke TranslateAccelerator, hWnd, hAcc, addr msg
        .IF eax == 0
            Invoke IsDialogMessage, hWnd, addr msg
            .IF eax == 0
                Invoke TranslateMessage, addr msg
                Invoke DispatchMessage, addr msg
            .ENDIF
        .ENDIF
    .ENDW

    mov eax, msg.wParam
    ret
WinMain ENDP

;------------------------------------------------------------------------------
; WndProc - Main Window Message Loop
;------------------------------------------------------------------------------
WndProc PROC hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    
    mov eax, uMsg
    .IF eax == WM_INITDIALOG
        Invoke InitGUI, hWin
        
    .ELSEIF eax == WM_COMMAND
        mov eax, wParam
        and eax, 0FFFFh
        
        .IF eax == IDM_FILE_EXIT || eax == IDC_BTN_EXIT || eax == ACC_FILE_EXIT
            Invoke SendMessage, hWin, WM_CLOSE, 0, 0
            
        ;----------------------------------------------------------------------
        ; Compress File
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_FILE_OPEN_COMPRESS || eax == IDC_BTN_COMPRESS || eax == ACC_FILE_OPEN_COMPRESS
            Invoke CDBrowseForFile, hWin, TRUE
            .IF eax == TRUE
                Invoke CDOpenFile, Addr CDFileName
                .IF eax == TRUE
                    Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnly
                    Invoke lstrcpy, Addr szStatusBarMsg, Addr szFile
                    Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                    Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    Invoke CDCompressFile
                    .IF eax == TRUE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szCompressFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ELSE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szCompressFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szFailure
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ENDIF
                    Invoke CDCloseFile
                    
                    ;----------------------------------------------------------
                    ; Output masm hex bytes to .asm file if option is checked
                    ;----------------------------------------------------------
                    .IF bAsmOutput == TRUE
                        Invoke CDOpenFile, Addr CDCompressedFileName
                        Invoke CDOutputAsmFile
                        Invoke CDCloseFile
                    .ENDIF
                .ENDIF
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Decompress File
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_FILE_OPEN_DECOMPRESS || eax == IDC_BTN_DECOMPRESS || eax == ACC_FILE_OPEN_DECOMPRESS
            Invoke CDBrowseForFile, hWin, FALSE
            .IF eax == TRUE
                Invoke CDOpenFile, Addr CDFileName
                .IF eax == TRUE
                    Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnly
                    Invoke lstrcpy, Addr szStatusBarMsg, Addr szFile
                    Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                    Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    Invoke CDDecompressFile
                    .IF eax == TRUE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szDecompressFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ELSE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szDecompressFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szFailure
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ENDIF
                .ENDIF
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Radio Button Selections
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_RBN_XPRESS
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_XPRESS
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_XPRESS
        
        .ELSEIF eax == IDC_RBN_XPRESS_HUFF
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_HUFF
            
        .ELSEIF eax == IDC_RBN_MSZIP
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_MSZIP
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_MSZIP
            
        .ELSEIF eax == IDC_RBN_LZMS
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_CHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_LZMS
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_LZMS
        
        ;----------------------------------------------------------------------
        ; Asm Output Checkbox Selection
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_CHK_ASM
            Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_GETCHECK, 0, 0
            .IF eax == TRUE
                Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_SETCHECK, BST_UNCHECKED, 0
                mov bAsmOutput, FALSE
            .ELSE
                Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_SETCHECK, BST_CHECKED, 0
                mov bAsmOutput, TRUE
            .ENDIF

        ;----------------------------------------------------------------------
        ; About Dialog with example of using a lzms compressed bitmap stored
        ; as data bytes in CD128x128x4.bmp.asm, uncompressing it in memory
        ; and creating the bitmap from that uncompressed memory before display
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_HELP_ABOUT || eax == IDC_BTN_ABOUT || eax == ACC_HELP_ABOUT
            Invoke DialogBoxParam, hInstance, IDD_AboutDlg, hWin, Addr AboutDlgProc, NULL
        
        ;----------------------------------------------------------------------
        ; Hidden easter egg option! Output file like BIN2DBEX does but to .asm
        ; Doesnt do any compression, just raw output to masm data bytes.
        ;
        ; We set button to ownerdraw so its not visible and only those that 
        ; know can click it and browse for a file to convert to masm data bytes
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_BIN2DBEX
            Invoke CDBrowseForFile, hWin, TRUE
            .IF eax == TRUE
                Invoke lstrcpy, Addr CDCompressedFileName, Addr CDFileName
                Invoke CDOpenFile, Addr CDCompressedFileName
                Invoke CDOutputAsmFile
                Invoke CDCloseFile
                
                Invoke CDJustFnameExt, Addr CDAsmFileName, Addr CDFileNameExtOnly
                Invoke lstrcpy, Addr szStatusBarMsg, Addr szFile
                Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
            .ENDIF
        .ENDIF
        
    .ELSEIF eax == WM_CLOSE
        Invoke CDCloseFile
        Invoke DestroyWindow, hWin
        
    .ELSEIF eax == WM_DESTROY
        Invoke PostQuitMessage, NULL
        
    .ELSE
        Invoke DefWindowProc, hWin, uMsg, wParam, lParam
        ret
    .ENDIF
    xor eax, eax
    ret
WndProc ENDP

;------------------------------------------------------------------------------
; InitGUI - Initialize GUI: Bitmaps, Toolbar, Tooltips, Menu etc 
;------------------------------------------------------------------------------
InitGUI PROC hWin:DWORD
    LOCAL hMainMenu:DWORD
    LOCAL hBitmap:DWORD
    
    Invoke GetDlgItem, hWin, IDC_STATUSBAR
    mov hStatusBar, eax
    
    ;--------------------------------------------------------------------------
    ; Set main window icons 
    ;--------------------------------------------------------------------------
    Invoke SendMessage, hWin, WM_SETICON, ICON_BIG, hIcoMain
    Invoke SendMessage, hWin, WM_SETICON, ICON_SMALL, hIcoMain
    
    ;--------------------------------------------------------------------------
    ; Set default radio and checkbox selections and statusbar text
    ;--------------------------------------------------------------------------
    Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_CHECKED, 0
    Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_SETCHECK, BST_CHECKED, 0
    Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_XPRESS
    
    ;--------------------------------------------------------------------------
    ; Create tooltip control and enum child controls to set text for each
    ;--------------------------------------------------------------------------
    Invoke CreateWindowEx, NULL, CTEXT("Tooltips_class32"), NULL, TTS_ALWAYSTIP, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hWin, NULL, hInstance, NULL
    mov hToolTip, eax
    Invoke SendMessage, hToolTip, TTM_SETMAXTIPWIDTH, 0, 350
    invoke SendMessage, hToolTip, TTM_SETDELAYTIME, TTDT_AUTOPOP, 12000
    Invoke EnumChildWindows, hWin, Addr InitTipsForEachChild, hWin
    
    ;--------------------------------------------------------------------------
    ; Button Bitmaps
    ;--------------------------------------------------------------------------
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_COMPRESS_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_COMPRESS_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_COMPRESS, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_DECOMPRESS_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_DECOMPRESS_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_DECOMPRESS, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_EXIT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_EXIT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_EXIT, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_ABOUT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_ABOUT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_ABOUT, BM_SETIMAGE, IMAGE_BITMAP, eax
    
    ;--------------------------------------------------------------------------
    ; Main Menu Bitmaps
    ;--------------------------------------------------------------------------
    Invoke GetMenu, hWin
    mov hMainMenu, eax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_COMPRESS_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_COMPRESS_MENU
    ENDIF
    mov hBitmap, eax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_FILE_OPEN_COMPRESS, MF_BYCOMMAND, hBitmap, 0   
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_DECOMPRESS_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_DECOMPRESS_MENU
    ENDIF
    mov hBitmap, eax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_FILE_OPEN_DECOMPRESS, MF_BYCOMMAND, hBitmap, 0 
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_EXIT_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_EXIT_MENU
    ENDIF
    mov hBitmap, eax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_FILE_EXIT, MF_BYCOMMAND, hBitmap, 0
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_ABOUT_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_ABOUT_MENU
    ENDIF
    mov hBitmap, eax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_HELP_ABOUT, MF_BYCOMMAND, hBitmap, 0

    ret
InitGUI ENDP

;------------------------------------------------------------------------------
; InitTipsForEachChild - initialize tooltips for each control
;------------------------------------------------------------------------------
InitTipsForEachChild PROC USES EBX hChild:DWORD, lParam:DWORD
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
    add eax, 1000
    mov TooltipTextID, eax

    Invoke LoadString, hInstance, TooltipTextID, Addr TooltipText, 256
    .IF eax == 0
        ; ignore controls we didnt set a tooltip text for in the stringtable
    .ELSE
        lea eax, TooltipText
        mov tti.lpszText, eax
        Invoke SendMessage, hToolTip, TTM_ADDTOOL, NULL, Addr tti
        Invoke SendMessage, hToolTip, TTM_ACTIVATE, TRUE, 0
    .ENDIF

    mov eax, TRUE
    ret
InitTipsForEachChild ENDP

;------------------------------------------------------------------------------
; CDOpenFile - Opens a file for compression or decompression
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDOpenFile PROC lpszFilename:DWORD
    LOCAL hFile:DWORD
    LOCAL MemMapHandle:DWORD
    LOCAL MemMapPtr:DWORD
    LOCAL lpFileName:DWORD
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
    ; Check we dont have a file already opened, if so we close it first
    ;--------------------------------------------------------------------------
    .IF CDFileHandle != NULL ; we have a file opened already
        Invoke CDCloseFile
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
    ; Save handles and file name
    ;--------------------------------------------------------------------------
    mov eax, hFile
    mov CDFileHandle, eax
    mov eax, MemMapHandle
    mov CDMemMapHandle, eax
    mov eax, MemMapPtr
    mov CDMemMapPtr, eax
    mov eax, dwFileSize
    mov CDFileSize, eax

    mov eax, TRUE
    ret
CDOpenFile ENDP

;------------------------------------------------------------------------------
; CDCloseFile - Closes a file opened with CDOpenFile
;
; Returns: Nothing
;------------------------------------------------------------------------------
CDCloseFile PROC

    .IF CDMemMapPtr != 0
        Invoke UnmapViewOfFile, CDMemMapPtr
    .ENDIF
    .IF CDMemMapHandle != 0
        Invoke CloseHandle, CDMemMapHandle
    .ENDIF
    .IF CDFileHandle != 0
        Invoke CloseHandle, CDFileHandle
    .ENDIF
    
    mov CDFileHandle, 0
    mov CDMemMapHandle, 0
    mov CDMemMapPtr, 0
    
    xor eax, eax
    ret
CDCloseFile ENDP

;------------------------------------------------------------------------------
; CDBrowseForFile - Browse for a file to open. Stores the selected file in CFFileName

; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDBrowseForFile PROC hWin:DWORD, bCompress:DWORD
    LOCAL BrowseForFile:OPENFILENAME

    IFDEF DEBUG32
    PrintText 'CDBrowseForFile'
    ENDIF

    Invoke RtlZeroMemory, Addr BrowseForFile, SIZEOF OPENFILENAME
    
    mov BrowseForFile.lStructSize, SIZEOF OPENFILENAME
    mov eax, hWin
    mov BrowseForFile.hwndOwner, eax
    mov BrowseForFile.nMaxFile, MAX_PATH
    mov BrowseForFile.lpstrDefExt, 0
    .IF bCompress == TRUE
        lea eax, CDOpenCompressFileFilter
    .ELSE
        lea eax, CDOpenDecompressFileFilter
    .ENDIF
    mov BrowseForFile.lpstrFilter, eax
    mov BrowseForFile.Flags, OFN_EXPLORER or OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
    lea eax, CDFileName
    mov BrowseForFile.lpstrFile, eax
    Invoke GetOpenFileName, Addr BrowseForFile

    ; If user selected a file and didnt cancel browse operation...
    .IF eax !=0
        mov eax, TRUE
    .ELSE
        mov eax, FALSE
    .ENDIF
    ret

CDBrowseForFile ENDP

;------------------------------------------------------------------------------
; CDCompressFile - Compress an opened file to an output file using the compression 
; algorithm name as the extension. Stores a header signature at the first dword 
; indicating the compression algorithm used to compress the file data.
;
; Returns: TRUE or FALSE  
;------------------------------------------------------------------------------
CDCompressFile PROC
    LOCAL CompressorHandle:DWORD
    LOCAL CompressedBuffer:DWORD
    LOCAL CompressedBufferSize:DWORD
    LOCAL CompressedDataSize:DWORD
    LOCAL CompressionAlgorithm:DWORD
    LOCAL hFile:DWORD
    LOCAL BytesWritten:DWORD
    
    IFDEF DEBUG32
    PrintText 'CDCompressFile'
    PrintString CDCompressedFileName
    ENDIF

    mov eax, CDAlgorithm
    .IF eax == 0
        mov eax, COMPRESS_ALGORITHM_XPRESS
    .ENDIF
    mov CompressionAlgorithm, eax
    
    ;--------------------------------------------------------------------------
    ; Construct output filename with extension based on algorithm used
    ;--------------------------------------------------------------------------
    Invoke lstrcpy, Addr CDCompressedFileName, Addr CDFileName
    mov eax, CompressionAlgorithm
    .IF eax == COMPRESS_ALGORITHM_MSZIP
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_MSZIP
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_XPRESS
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_HUFF
    .ELSEIF eax == COMPRESS_ALGORITHM_LZMS
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_LZMS
    .ELSE
        Invoke lstrcat, Addr CDCompressedFileName, Addr CDCompressedExt
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create compressor
    ;--------------------------------------------------------------------------
    Invoke CreateCompressor, CompressionAlgorithm, NULL, Addr CompressorHandle ;COMPRESS_ALGORITHM_LZMS COMPRESS_ALGORITHM_XPRESS_HUFF
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDCompressFile CreateCompressor Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF

    ;--------------------------------------------------------------------------
    ; Get size required first
    ;--------------------------------------------------------------------------
    Invoke Compress, CompressorHandle, CDMemMapPtr, CDFileSize, NULL, 0, Addr CompressedBufferSize
    .IF eax == FALSE
        Invoke GetLastError
        .IF eax == ERROR_INSUFFICIENT_BUFFER
            
        .ELSE
            IFDEF DEBUG32
            PrintText 'CDCompressFile Compress Get Size Failed'
            ENDIF
            .IF CompressorHandle != 0
                Invoke CloseCompressor, CompressorHandle
            .ENDIF
            mov eax, FALSE
            ret
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, CompressedBufferSize
    .IF eax == NULL
        IFDEF DEBUG32
        PrintText 'CDCompressFile GlobalAlloc Failed'
        ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov CompressedBuffer, eax
    
    ;--------------------------------------------------------------------------
    ; Do actual compression now
    ;--------------------------------------------------------------------------
    Invoke Compress, CompressorHandle, CDMemMapPtr, CDFileSize, CompressedBuffer, CompressedBufferSize, Addr CompressedDataSize
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDCompressFile Compress Failed'
        ENDIF
        .IF CompressedBuffer != 0
            Invoke GlobalFree, CompressedBuffer
        .ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF

    ;--------------------------------------------------------------------------
    ; Create output file
    ;--------------------------------------------------------------------------
    Invoke CreateFile, Addr CDCompressedFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        IFDEF DEBUG32
        PrintText 'CDCompressFile CreateFile CDCompressedFileName Failed'
        ENDIF
        .IF CompressedBuffer != 0
            Invoke GlobalFree, CompressedBuffer
        .ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov hFile, eax
    
    ;--------------------------------------------------------------------------
    ; Write out header signature and then the compressed data to output file
    ;--------------------------------------------------------------------------
    mov eax, CompressionAlgorithm
    .IF eax == COMPRESS_ALGORITHM_MSZIP
        Invoke WriteFile, hFile, Addr HEADER_MSZIP, 4, Addr BytesWritten, NULL
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS
        Invoke WriteFile, hFile, Addr HEADER_XPRESS, 4, Addr BytesWritten, NULL
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke WriteFile, hFile, Addr HEADER_HUFF, 4, Addr BytesWritten, NULL
    .ELSEIF eax == COMPRESS_ALGORITHM_LZMS
        Invoke WriteFile, hFile, Addr HEADER_LZMS, 4, Addr BytesWritten, NULL
    .ENDIF

    Invoke WriteFile, hFile, CompressedBuffer, CompressedDataSize, Addr BytesWritten, NULL
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    .IF CompressedBuffer != 0
        Invoke GlobalFree, CompressedBuffer
    .ENDIF
    
    .IF CompressorHandle != 0
        Invoke CloseCompressor, CompressorHandle
    .ENDIF
    
    mov eax, TRUE
    ret
CDCompressFile ENDP

;------------------------------------------------------------------------------
; CDDecompressFile - Decompress an opened file to an output file using the 
; compression algorithm found in the first dword value of the file. Output file 
; uses the extension of .raw so as to not overwrite any original files.
;
; Returns: TRUE or FALSE  
;------------------------------------------------------------------------------
CDDecompressFile PROC USES EBX 
    LOCAL DecompressorHandle:DWORD
    LOCAL DecompressedBuffer:DWORD
    LOCAL DecompressedBufferSize:DWORD
    LOCAL DecompressedDataSize:DWORD
    LOCAL DecompressionAlgorithm:DWORD
    LOCAL hFile:DWORD
    LOCAL pData:DWORD
    LOCAL FileSize:DWORD
    LOCAL BytesWritten:DWORD

    
    IFDEF DEBUG32
    PrintText 'CDDecompressFile'
    PrintString CDDecompressedFileName
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; Construct output filename
    ;--------------------------------------------------------------------------
    Invoke lstrcpy, Addr CDDecompressedFileName, Addr CDFileName
    Invoke lstrcat, Addr CDDecompressedFileName, Addr CDDecompressedExt
    
    mov eax, CDAlgorithm
    .IF eax == 0
        mov eax, COMPRESS_ALGORITHM_XPRESS
    .ENDIF
    mov DecompressionAlgorithm, eax

    ;--------------------------------------------------------------------------
    ; Check for signature, if we find one, we set decompression algorithm 
    ; ourselves otherwise we assume the one the user specified and try that.
    ; adjust filesize and pointer to data to account for signature if found.
    ;--------------------------------------------------------------------------
    mov ebx, CDMemMapPtr
    mov eax, [ebx]
    .IF eax == HEADER_MSZIP || eax == HEADER_XPRESS || eax == HEADER_HUFF || eax == HEADER_LZMS
        .IF eax == HEADER_MSZIP
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_MSZIP
        .ELSEIF eax == HEADER_XPRESS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS
        .ELSEIF eax == HEADER_HUFF
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
        .ELSEIF eax == HEADER_LZMS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_LZMS
        .ENDIF
        mov eax, CDMemMapPtr
        add eax, 4
        mov pData, eax
        mov eax, CDFileSize
        sub eax, 4
        mov FileSize, eax
    .ELSE
        mov eax, CDMemMapPtr
        mov pData, eax
        mov eax, CDFileSize
        mov FileSize, eax
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create decompressor
    ;--------------------------------------------------------------------------
    Invoke CreateDecompressor, DecompressionAlgorithm, NULL, Addr DecompressorHandle ;COMPRESS_ALGORITHM_LZMS COMPRESS_ALGORITHM_XPRESS_HUFF
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDDecompressFile CreateDecompressor Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Get size required
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, FileSize, NULL, 0, Addr DecompressedBufferSize
    .IF eax == FALSE
        Invoke GetLastError
        .IF eax == ERROR_INSUFFICIENT_BUFFER
            
        .ELSE
            IFDEF DEBUG32
            PrintText 'CDDecompressFile Decompress Get Size Failed'
            ENDIF
            .IF DecompressorHandle != 0
                Invoke CloseDecompressor, DecompressorHandle
            .ENDIF
            mov eax, FALSE
            ret
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, DecompressedBufferSize
    .IF eax == NULL
        IFDEF DEBUG32
        PrintText 'CDDecompressFile GlobalAlloc Failed'
        ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov DecompressedBuffer, eax
    
    ;--------------------------------------------------------------------------
    ; Do the actual decompression now
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, FileSize, DecompressedBuffer, DecompressedBufferSize, Addr DecompressedDataSize
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDDecompressFile Decompress Failed'
        ENDIF
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create output file and write data
    ;--------------------------------------------------------------------------
    Invoke CreateFile, Addr CDDecompressedFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        IFDEF DEBUG32
        PrintText 'CDDecompressFile CreateFile CDDecompressedFileName Failed'
        ENDIF
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov hFile, eax ; store file handle
    
    Invoke WriteFile, hFile, DecompressedBuffer, DecompressedDataSize, Addr BytesWritten, NULL
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    .IF DecompressedBuffer != 0
        Invoke GlobalFree, DecompressedBuffer
    .ENDIF
    
    .IF DecompressorHandle != 0
        Invoke CloseDecompressor, DecompressorHandle
    .ENDIF
    
    mov eax, TRUE
    ret
CDDecompressFile ENDP

;------------------------------------------------------------------------------
; CDDecompressMem - Decompress memory that was previously compressed with one
; of the Cabinet compression algorithms. Checks for header signature first to 
; verify that there is a compressed data and what algorithm to use.
;
; Returns: pointer to decompressed data if succesful or NULL otherwise.
; User should free memory when no longer required with call to GlobalFree 
;------------------------------------------------------------------------------
CDDecompressMem PROC USES EBX lpCompressedData:DWORD, dwCompressedDataLength:DWORD
    LOCAL DecompressorHandle:DWORD
    LOCAL DecompressedBuffer:DWORD
    LOCAL DecompressedBufferSize:DWORD
    LOCAL DecompressedDataSize:DWORD
    LOCAL DecompressionAlgorithm:DWORD
    LOCAL pData:DWORD
    LOCAL nDataLength:DWORD
    
    IFDEF DEBUG32
    PrintText 'CDDecompressMem'
    ENDIF
    
    .IF lpCompressedData == NULL || dwCompressedDataLength == 0
        mov eax, NULL
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Check for header signature and adjust pointer and length
    ;--------------------------------------------------------------------------
    mov ebx, lpCompressedData
    mov eax, [ebx]
    .IF eax == HEADER_MSZIP || eax == HEADER_XPRESS || eax == HEADER_HUFF || eax == HEADER_LZMS
        .IF eax == HEADER_MSZIP
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_MSZIP
        .ELSEIF eax == HEADER_XPRESS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS
        .ELSEIF eax == HEADER_HUFF
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
        .ELSEIF eax == HEADER_LZMS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_LZMS
        .ENDIF
    .ELSE
        mov eax, NULL
        ret
    .ENDIF
    mov eax, lpCompressedData
    add eax, 4 ; skip past header signature
    mov pData, eax
    
    mov eax, dwCompressedDataLength
    sub eax, 4 ; we need 4 less coz of signature
    .IF sdword ptr eax < 0 ; check size again
        mov eax, NULL
        ret
    .ENDIF
    mov nDataLength, eax
    
    ;--------------------------------------------------------------------------
    ; Create decompressor
    ;--------------------------------------------------------------------------
    Invoke CreateDecompressor, DecompressionAlgorithm, NULL, Addr DecompressorHandle
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDDecompressMem CreateDecompressor Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Get size required
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, nDataLength, NULL, 0, Addr DecompressedBufferSize
    .IF eax == FALSE
        Invoke GetLastError
        .IF eax == ERROR_INSUFFICIENT_BUFFER
            ; 
        .ELSE
            IFDEF DEBUG32
            PrintText 'CDDecompressMem Decompress Get Size Failed'
            ENDIF
            .IF DecompressorHandle != 0
                Invoke CloseDecompressor, DecompressorHandle
            .ENDIF
            mov eax, NULL
            ret
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, DecompressedBufferSize
    .IF eax == NULL
        IFDEF DEBUG32
        PrintText 'CDDecompressMem GlobalAlloc Failed'
        ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov eax, NULL
        ret
    .ENDIF
    mov DecompressedBuffer, eax
    
    ;--------------------------------------------------------------------------
    ; Do the actual decompression now
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, nDataLength, DecompressedBuffer, DecompressedBufferSize, Addr DecompressedDataSize
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDDecompressMem Decompress Failed'
        ENDIF
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov eax, NULL
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Cleanup and return pointer to decompressed data
    ;--------------------------------------------------------------------------
    .IF DecompressorHandle != 0
        Invoke CloseDecompressor, DecompressorHandle
    .ENDIF
    
    mov eax, DecompressedBuffer
    ret
CDDecompressMem ENDP

;------------------------------------------------------------------------------
; CDOutputAsmFile - Outputs the compressed file with an .asm extension using 
; masm style data bytes: 'DB 00Fh, 0A3h, 09Ch' for example - same as bin2dbex
;
; Returns: TRUE or FALSE  
;------------------------------------------------------------------------------
CDOutputAsmFile PROC USES EBX
    LOCAL pAsmData:DWORD
    LOCAL nAsmData:DWORD
    LOCAL LenDataAsm:DWORD
    LOCAL pRawData:DWORD
    LOCAL nRawData:DWORD
    LOCAL LenDataRaw:DWORD
    LOCAL MaxDataPos:DWORD
    LOCAL hFile:DWORD
    LOCAL BytesWritten:DWORD
    LOCAL nRows:DWORD
    LOCAL nCurrentRow:DWORD
    LOCAL nCurrentCol:DWORD
    LOCAL LenFileNameOnly:DWORD
    LOCAL LenFileNameExtOnly:DWORD
    LOCAL percentage:DWORD
    LOCAL ratio:DWORD
    LOCAL CDFileSizeUncompressed:DWORD
    LOCAL fad:WIN32_FILE_ATTRIBUTE_DATA
    LOCAL strAsciiAsmText[32]:BYTE

    ;--------------------------------------------------------------------------
    ; Construct asm output filename and create the output file
    ;--------------------------------------------------------------------------
    Invoke lstrcpy, Addr CDAsmFileName, Addr CDFileName
    Invoke lstrcat, Addr CDAsmFileName, Addr Ext_ASM
    
    ;--------------------------------------------------------------------------
    ; Get uncompressed file size without opening file
    ;--------------------------------------------------------------------------
    Invoke GetFileAttributesEx, Addr CDFileName, 0, Addr fad ; GetFileExInfoStandard is 0
    .IF eax == FALSE
        IFDEF DEBUG32
        PrintText 'CDOutputAsmFile GetFileAttributesEx Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov eax, fad.nFileSizeLow
    mov CDFileSizeUncompressed, eax

    IFDEF DEBUG32
    PrintText 'CDOutputAsmFile'
    PrintString CDAsmFileName
    ENDIF
    
    Invoke CDJustFname, Addr CDFileName, Addr CDFileNameOnly
    Invoke lstrlen, Addr CDFileNameOnly
    mov LenFileNameOnly, eax
    
    Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnly
    Invoke lstrlen, Addr CDFileNameExtOnly
    mov LenFileNameExtOnly, eax
    
    ;--------------------------------------------------------------------------
    ; Create our output asm file
    ;--------------------------------------------------------------------------
    Invoke CreateFile, Addr CDAsmFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        IFDEF DEBUG32
        PrintText 'CDOutputAsmFile CreateFile CDOutputAsmFile Failed'
        ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov hFile, eax
    
    mov eax, CDFileSize
    mov LenDataRaw, eax
    ;--------------------------------------------------------------------------
    ; Calc asm output length - could be neater, but its just guesstimates tbh
    ;--------------------------------------------------------------------------
    mov LenDataAsm, 0
    
    mov eax, 11 ; 13,10,'.DATA',13,10,13,10,0   = szASMData 
    add LenDataAsm, eax
    
    mov eax, LenFileNameOnly
    add eax, 4 ; ' \',13,10,0                   = szASMSlash
    add LenDataAsm, eax
    
    mov eax, CDFileSize
    shr eax, 4 ; / 16
    mov nRows, eax
    
    mov eax, 6 ; '0FFh, '                       = 6 bytes per raw byte output 
    mov ebx, CDFileSize ;nRows
    mul ebx
    add LenDataAsm, eax
    
    mov eax, nRows
    add eax, 1
    mov ebx, 6
    mul ebx
    add LenDataAsm, eax

    mov eax, LenFileNameOnly
    add LenDataAsm, eax
    add LenDataAsm, 16  ; szASMLength
    add LenDataAsm, eax
    add LenDataAsm, 4   ; 2 x CRLF
    add LenDataAsm, 164 ; 2 header lines + CRLFs
    add LenDataAsm, 54  ; Comment note
    add LenDataAsm, 115 ; Comment info text + CRLFs
    add LenDataAsm, 25  ; Max size for algo name
    mov eax, LenFileNameExtOnly
    add LenDataAsm, eax
    add LenDataAsm, 12  ; max of ascii size uncompressed
    add LenDataAsm, 12  ; max of ascii size compressed
    add LenDataAsm, 4   ; max of '100%' text
    add LenDataAsm, 16  ; ' Bytes' +CRLFs x 2
    add LenDataAsm, 4   ; % and CRLF
    add LenDataAsm, 8   ; (x:1) and CRLF
    
    ;--------------------------------------------------------------------------
    ; Alloc memory for asm hex output
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, LenDataAsm
    .IF eax == NULL
        IFDEF DEBUG32
        PrintText 'CDOutputAsmFile GlobalAlloc Failed'
        ENDIF
        Invoke CloseHandle, hFile
        mov eax, FALSE
        ret
    .ENDIF
    mov pAsmData, eax
    
    mov eax, CDMemMapPtr
    mov pRawData, eax
    add eax, LenDataRaw
    mov MaxDataPos, eax
    
    ;--------------------------------------------------------------------------
    ; Output start
    ;--------------------------------------------------------------------------
    Invoke szUpper, Addr CDFileNameOnly
    
    Invoke lstrcpy, pAsmData, Addr szASMCmtLine
    Invoke lstrcat, pAsmData, Addr szASMCmtNote
    
    Invoke lstrcat, pAsmData, Addr szASMCmtOrigFile
    Invoke lstrcat, pAsmData, Addr CDFileNameExtOnly
    Invoke lstrcat, pAsmData, Addr szASMCFLF
    
    Invoke lstrcat, pAsmData, Addr szASMCmtSizeUncompressed
    Invoke dwtoa, CDFileSizeUncompressed, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMBytes
    
    Invoke lstrcat, pAsmData, Addr szASMCmtSizeCompressed
    Invoke dwtoa, CDFileSize, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMBytes
    
    ;--------------------------------------------------------------------------
    ; Calc percentage and ratio using fpu
    ;--------------------------------------------------------------------------
    Invoke lstrcat, pAsmData, Addr szASMCmtRatio
    finit
    fwait
    fld FP4(100.0)
    fidiv CDFileSizeUncompressed
    fimul CDFileSize
    fistp DWORD PTR percentage
    fstp st(0)
    
    fild CDFileSizeUncompressed
    fidiv CDFileSize
    fistp DWORD PTR ratio
    fstp st(0)
    
    mov eax, 100
    sub eax, percentage
    mov percentage, eax
    
    Invoke dwtoa, percentage, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMPcnt
    Invoke dwtoa, ratio, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMRatio
    ;--------------------------------------------------------------------------
    
    Invoke lstrcat, pAsmData, Addr szASMCmtAlgo
    mov eax, CDAlgorithm
    .IF eax == COMPRESS_ALGORITHM_MSZIP
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_MSZIP
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_XPRESS
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_HUFF
    .ELSEIF eax == COMPRESS_ALGORITHM_LZMS
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_LZMS
    .ENDIF
    Invoke lstrcat, pAsmData, Addr szASMCFLF

    Invoke lstrcat, pAsmData, Addr szASMCmtLine
    
    Invoke lstrcat, pAsmData, Addr szASMData
    Invoke lstrcat, pAsmData, Addr CDFileNameOnly
    Invoke lstrcat, pAsmData, Addr szASMSlash
    
    ;--------------------------------------------------------------------------
    ; Loop start
    ;--------------------------------------------------------------------------
    mov nCurrentRow, 0
    mov nCurrentCol, 0
    mov nRawData, 0
    mov eax, 0
    .WHILE eax < LenDataRaw
        
        .IF nCurrentCol == 0
            Invoke lstrcat, pAsmData, Addr szASMRowStart
            Invoke lstrcat, pAsmData, Addr szASMhcs01st
        .ENDIF
        
        mov ebx, pRawData
        add ebx, nRawData

        Invoke CDRawToHexString, ebx, MaxDataPos, 1, Addr strAsciiAsmText, TRUE, FALSE
        add nRawData, 1

        Invoke lstrcat, pAsmData, Addr strAsciiAsmText
        
        inc nCurrentCol
        mov eax, nCurrentCol
        .IF eax == 16
            Invoke lstrcat, pAsmData, Addr szASMRowEnd
            mov nCurrentCol, 0
        .ELSE
            mov eax, nRawData
            .IF eax < LenDataRaw
                Invoke lstrcat, pAsmData, Addr szASMhcs0
            .ELSE
                Invoke lstrcat, pAsmData, Addr szASMRowEnd
            .ENDIF
        .ENDIF

        mov eax, nRawData
    .ENDW
    
    ;--------------------------------------------------------------------------
    ; Do end where we define length of data using namelength dd $ - name
    ;--------------------------------------------------------------------------
    Invoke lstrcat, pAsmData, Addr szASMCFLF 
    Invoke lstrcat, pAsmData, Addr CDFileNameOnly
    Invoke lstrcat, pAsmData, Addr szASMLength
    Invoke lstrcat, pAsmData, Addr CDFileNameOnly
    Invoke lstrcat, pAsmData, Addr szASMCFLF 
    
    ;--------------------------------------------------------------------------
    ; Write out asm hex text buffer to file
    ;--------------------------------------------------------------------------
    Invoke lstrlen, pAsmData
    mov LenDataAsm, eax
    Invoke WriteFile, hFile, pAsmData, LenDataAsm, Addr BytesWritten, NULL
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    Invoke GlobalFree, pAsmData
    
    mov eax, TRUE
    ret
CDOutputAsmFile ENDP

;------------------------------------------------------------------------------
; CDBitmapCreateFromCompressedRes - Creates a bitmap from a compressed bitmap 
; resource (compressed with a Microsoft compression algorithm: XPRESS, XPRESS
; with Huffman encoding, MSZIP or LZMS) by uncompressing the data & creating a 
; bitmap from that data
;
; Calls: CDDecompressMem, CDBitmapCreateFromMem
;
; Returns: HBITMAP or NULL
;------------------------------------------------------------------------------
CDBitmapCreateFromCompressedRes PROC hInst:DWORD, dwResourceID:DWORD
    LOCAL hRes:DWORD
    LOCAL lpCompressedBitmapData:DWORD
    LOCAL dwCompressedBitmapDataLength:DWORD
    LOCAL lpDecompressedBitmapData:DWORD
    LOCAL hBitmap:DWORD
    
    Invoke FindResource, hInst, dwResourceID, RT_RCDATA ; get LZMS bitmap as raw data
    .IF eax != NULL
        mov hRes, eax
        Invoke SizeofResource, hInst, hRes
        .IF eax != 0
            mov dwCompressedBitmapDataLength, eax
            Invoke LoadResource, hInst, hRes
            .IF eax != NULL
                Invoke LockResource, eax
                .IF eax != NULL
                    mov lpCompressedBitmapData, eax
                    Invoke CDDecompressMem, lpCompressedBitmapData, dwCompressedBitmapDataLength
                    .IF eax != NULL
                        mov lpDecompressedBitmapData, eax
                        Invoke CDBitmapCreateFromMem, lpDecompressedBitmapData
                        .IF eax != NULL
                            mov hBitmap, eax
                            .IF lpDecompressedBitmapData != 0
                                Invoke GlobalFree, lpDecompressedBitmapData
                            .ENDIF
                            mov eax, hBitmap
                            ret
                        .ELSE
                            ;PrintText 'Failed to create bitmap from data'
                            .IF lpDecompressedBitmapData != 0
                                Invoke GlobalFree, lpDecompressedBitmapData
                            .ENDIF
                            mov eax, NULL
                        .ENDIF
                    .ELSE
                        ;PrintText 'Failed to decompress data'
                        mov eax, NULL
                    .ENDIF
                .ELSE
                    ;PrintText 'Failed to lock resource'
                    mov eax, NULL
                .ENDIF
            .ELSE
                ;PrintText 'Failed to load resource'
                mov eax, NULL
            .ENDIF
        .ELSE
            ;PrintText 'Failed to get resource size'
            mov eax, NULL
        .ENDIF
    .ELSE
        ;PrintText 'Failed to find resource'
        mov eax, NULL
    .ENDIF    
    
    ret
CDBitmapCreateFromCompressedRes ENDP

;------------------------------------------------------------------------------
; CDBitmapCreateFromCompressedMem - Creates a bitmap from a compressed bitmap 
; data stored in memory (compressed with a Microsoft compression algorithm: 
; XPRESS, XPRESS with Huffman encoding, MSZIP or LZMS) by uncompressing the 
; data & creating a bitmap from that data
;
; Calls: CDDecompressMem, CDBitmapCreateFromMem
;
; Returns: HBITMAP or NULL
;------------------------------------------------------------------------------
CDBitmapCreateFromCompressedMem PROC lpCompressedBitmapData:DWORD, dwCompressedBitmapDataLength:DWORD
    LOCAL lpDecompressedBitmapData:DWORD
    LOCAL hBitmap:DWORD

    .IF lpCompressedBitmapData == NULL || dwCompressedBitmapDataLength == 0
        mov eax, NULL
        ret
    .ENDIF
    
    Invoke CDDecompressMem, lpCompressedBitmapData, dwCompressedBitmapDataLength
    .IF eax != NULL
        mov lpDecompressedBitmapData, eax
        Invoke CDBitmapCreateFromMem, lpDecompressedBitmapData
        .IF eax != NULL
            mov hBitmap, eax
            .IF lpDecompressedBitmapData != 0
                Invoke GlobalFree, lpDecompressedBitmapData
            .ENDIF
            mov eax, hBitmap
            ret
        .ELSE
            ;PrintText 'Failed to create bitmap from data'
            .IF lpDecompressedBitmapData != 0
                Invoke GlobalFree, lpDecompressedBitmapData
            .ENDIF
        .ENDIF
    .ENDIF
    mov eax, NULL
    ret
CDBitmapCreateFromCompressedMem ENDP

;------------------------------------------------------------------------------
; CDBitmapCreateFromMem - Create a bitmap from bitmap data stored in memory 
;
; http://www.masmforum.com/board/index.php?topic=16267.msg134453#msg134453
;
; Returns: HBITMAP or NULL
;------------------------------------------------------------------------------
CDBitmapCreateFromMem PROC USES ECX EDX pBitmapData:DWORD
    LOCAL hDC:DWORD
    LOCAL hBmp:DWORD

    Invoke CreateDC, Addr szCDMemoryDisplayDC, NULL, NULL, NULL
    test eax, eax
    jz @f
    mov hDC, eax
    mov edx, pBitmapData
    lea ecx, [edx + SIZEOF BITMAPFILEHEADER]  ; start of the BITMAPINFOHEADER header
    mov eax, BITMAPFILEHEADER.bfOffBits[edx]
    add edx, eax
    Invoke CreateDIBitmap, hDC, ecx, CBM_INIT, edx, ecx, DIB_RGB_COLORS
    mov hBmp, eax
    Invoke DeleteDC, hDC
    mov eax, hBmp
@@:
    ret
CDBitmapCreateFromMem ENDP

;------------------------------------------------------------------------------
; CDRawToHexString - Convert raw bytes to a human readable hex based string
; lpszAsciiHexString should be >= 2x the size of dwRawSize+1 byte for null
;
; Returns: TRUE if success, FALSE otherwise
;------------------------------------------------------------------------------
CDRawToHexString PROC USES EBX EDI ESI lpRaw:DWORD, lpRawMax:DWORD, dwRawSize:DWORD, lpszAsciiHexString:DWORD, bUpperCase:DWORD, bByteSwap:DWORD
    LOCAL pos:DWORD
    LOCAL posmax:DWORD
    LOCAL BytesRead:DWORD
    
    .IF lpRaw == NULL || dwRawSize == 0 || lpszAsciiHexString == NULL
        mov eax, 0
        ret
    .ENDIF
    
    mov eax, lpRaw
    .IF eax >= lpRawMax
        mov ebx, lpszAsciiHexString
        mov byte ptr [ebx], 0
        mov eax, 0
        ret
    .ENDIF
    mov eax, lpRawMax
    mov posmax, eax
    mov BytesRead, 0
    
    .IF bByteSwap == FALSE
        mov pos, 0
        mov edi, lpszAsciiHexString
        mov esi, lpRaw
        mov eax, pos
        .WHILE eax < dwRawSize
            movzx eax, byte ptr [esi]
            mov ah,al
            ror al, 4                   ; shift in next hex digit
            and al, 0FH                 ; get digit
            .IF al < 10
                add al, "0"             ; convert digits 0-9 to ascii
            .ELSE
                .IF bUpperCase == TRUE
                    add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
                .ELSE
                    add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
                .ENDIF
            .ENDIF
            mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
            inc edi
            mov al,ah
            
            and al, 0FH                 ; get digit
            .IF al < 10
                add al, "0"             ; convert digits 0-9 to ascii
            .ELSE
                .IF bUpperCase == TRUE
                    add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
                .ELSE
                    add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
                .ENDIF
            .ENDIF
            mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
            
            inc edi
            inc esi
            .IF esi > posmax
                .BREAK
            .ENDIF
            inc BytesRead
            inc pos
            mov eax, pos
        .ENDW
        mov byte ptr [edi], 0
    
    .ELSE ; bByteSwap == TRUE
    
        mov eax, dwRawSize
        mov pos, eax
        
        mov edi, lpszAsciiHexString
        mov esi, lpRaw
        add esi, dwRawSize
        dec esi
        .IF esi >= posmax
            dec esi
            mov eax, posmax
            sub eax, esi
            sub pos, eax
            mov esi, posmax
            dec esi
        .ENDIF
        mov eax, pos
        .WHILE eax > 0
            movzx eax, byte ptr [esi]
            mov ah,al
            ror al, 4                   ; shift in next hex digit
            and al, 0FH                 ; get digit
            .IF al < 10
                add al, "0"             ; convert digits 0-9 to ascii
            .ELSE
                .IF bUpperCase == TRUE
                    add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
                .ELSE
                    add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
                .ENDIF
            .ENDIF
            mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
            inc edi
            mov al,ah
            
            and al, 0FH                 ; get digit
            .IF al < 10
                add al, "0"             ; convert digits 0-9 to ascii
            .ELSE
                .IF bUpperCase == TRUE
                    add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
                .ELSE
                    add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
                .ENDIF
            .ENDIF
            mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
            
            inc BytesRead
            inc edi
            dec esi
            dec pos
            mov eax, pos
        .ENDW
        mov byte ptr [edi], 0
    .ENDIF
    
    mov eax, BytesRead
    ret
CDRawToHexString ENDP

;------------------------------------------------------------------------------
; CDJustFname - Strip path name to just filename Without extention
;------------------------------------------------------------------------------
CDJustFname PROC USES ESI EDI szFilePathName:DWORD, szFileName:DWORD
    LOCAL LenFilePathName:DWORD
    LOCAL nPosition:DWORD
    
    Invoke szLen, szFilePathName
    mov LenFilePathName, eax
    mov nPosition, eax
    
    .IF LenFilePathName == 0
        mov edi, szFileName
        mov byte ptr [edi], 0
        mov eax, FALSE
        ret
    .ENDIF
    
    mov esi, szFilePathName
    add esi, eax
    
    mov eax, nPosition
    .WHILE eax != 0
        movzx eax, byte ptr [esi]
        .IF al == '\' || al == ':' || al == '/'
            inc esi
            .BREAK
        .ENDIF
        dec esi
        dec nPosition
        mov eax, nPosition
    .ENDW
    mov edi, szFileName
    mov eax, nPosition
    .WHILE eax != LenFilePathName
        movzx eax, byte ptr [esi]
        .IF al == '.' ; stop here
            .BREAK
        .ENDIF
        mov byte ptr [edi], al
        inc edi
        inc esi
        inc nPosition
        mov eax, nPosition
    .ENDW
    mov byte ptr [edi], 0h
    mov eax, TRUE
    ret
CDJustFname ENDP

;------------------------------------------------------------------------------
; CDJustFnameExt - Strip path name to just filename with extention
;------------------------------------------------------------------------------
CDJustFnameExt PROC USES ESI EDI szFilePathName:DWORD, szFileName:DWORD
    LOCAL LenFilePathName:DWORD
    LOCAL nPosition:DWORD
    
    Invoke szLen, szFilePathName
    mov LenFilePathName, eax
    mov nPosition, eax
    
    .IF LenFilePathName == 0
        mov edi, szFileName
        mov byte ptr [edi], 0
        mov eax, FALSE
        ret
    .ENDIF
    
    mov esi, szFilePathName
    add esi, eax
    
    mov eax, nPosition
    .WHILE eax != 0
        movzx eax, byte ptr [esi]
        .IF al == '\' || al == ':' || al == '/'
            inc esi
            .BREAK
        .ENDIF
        dec esi
        dec nPosition
        mov eax, nPosition
    .ENDW
    mov edi, szFileName
    mov eax, nPosition
    .WHILE eax != LenFilePathName
        movzx eax, byte ptr [esi]
        mov byte ptr [edi], al
        inc edi
        inc esi
        inc nPosition
        mov eax, nPosition
    .ENDW
    mov byte ptr [edi], 0h ; null out filename
    mov eax, TRUE
    ret

CDJustFnameExt  ENDP

end start




